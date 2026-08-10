import SwiftUI

struct SearchView: View {
    @ObservedObject var catalog: ProductCatalogStore
    @ObservedObject var savedStore: SavedProductsStore
    @ObservedObject var authStore: AuthStore
    let preferences: UserPreferences
    var onOpenPreferences: (() -> Void)? = nil
    var onScanAnotherProduct: (() -> Void)? = nil

    @State private var query = ""
    @State private var selectedGoal: GroceryGoal = .all
    @State private var selectedProduct: Product?
    @State private var showAllGoalMatches = false
    @State private var showFullHistory = false
    @State private var showPaywall = false
    @State private var showProductRequest = false

    private let homeGoalPreviewLimit = 4
    private let homeGoalCarouselLimit = 30
    private let homeRecentPreviewLimit = 3

    private var products: [Product] {
        catalog.searchProducts(matching: query)
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var preferredGoals: [GroceryGoal] {
        GroceryGoal.preferred(in: preferences)
    }

    private var availableGoals: [GroceryGoal] {
        GroceryGoal.available(in: preferences)
    }

    private var hasPersonalGoals: Bool {
        !preferredGoals.isEmpty
    }

    private var recentProducts: [Product] {
        savedStore.recentProducts.compactMap { recentProduct in
            savedStore.product(id: recentProduct.productId) ?? catalog.product(id: recentProduct.productId)
        }
    }

    private var homeRecentProducts: [Product] {
        Array(recentProducts.prefix(homeRecentPreviewLimit))
    }

    private var goalMatchedProducts: [Product] {
        GroceryGoal.healthiestMatchingProducts(
            in: catalog.products,
            filter: selectedGoal,
            preferredGoals: preferredGoals
        )
    }

    private var homeGoalProducts: [Product] {
        Array(goalMatchedProducts.prefix(homeGoalPreviewLimit))
    }

    private var homeGoalCarouselProducts: [Product] {
        let productsAfterMainFeed = Array(goalMatchedProducts.dropFirst(homeGoalPreviewLimit))
        let mainFeedProducts = Array(goalMatchedProducts.prefix(homeGoalPreviewLimit))
        return Array((productsAfterMainFeed + mainFeedProducts).prefix(homeGoalCarouselLimit))
    }

    private var goalsForRecommendationLoad: [GroceryGoal] {
        preferredGoals
    }

    private var goalRecommendationTaskID: String {
        let goalIDs = goalsForRecommendationLoad.map(\.id).joined(separator: "-")
        return "\(catalog.hasLoaded)-\(goalIDs)"
    }

    var body: some View {
        List {
            PicklyContentHeader(
                title: "Check your groceries",
                subtitle: "Find better picks faster.",
                usesImageBackdrop: true
            )
            .picklyContentHeaderRow(top: 44, bottom: 12)

            PicklyInlineSearchField(
                text: $query,
                prompt: "Search products or brands",
                onScan: onScanAnotherProduct
            )
            .picklyContentHeaderRow(top: 0, bottom: 20)

            if isSearching {
                searchResultsSection
            } else {
                goalsSection
                goalRecommendationsSection
                premiumBanner
                recentSection

                MissingProductCard {
                    showProductRequest = true
                }
                .picklyListCardRow(top: 14, bottom: 28)
            }
        }
        // InsetGrouped creates a clipped section container around the whole
        // feed. That container cuts off card shadows at its vertical edges.
        .listStyle(.plain)
        .contentMargins(.horizontal, PicklyLayout.screenHorizontalPadding, for: .scrollContent)
        .contentMargins(.top, PicklyLayout.rootTopPadding + 16, for: .scrollContent)
        // The native TabView already contributes the bottom safe-area inset for
        // its tab bar. Adding another 96pt here leaves an empty band below the
        // final home card.
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background {
            SearchViewBackdrop()
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedProduct) { product in
            ProductResultView(
                product: product,
                productService: catalog,
                savedStore: savedStore,
                preferences: preferences,
                onScanAnotherProduct: onScanAnotherProduct
            )
        }
        .navigationDestination(for: Product.self) { product in
            ProductResultView(
                product: product,
                productService: catalog,
                savedStore: savedStore,
                preferences: preferences,
                onScanAnotherProduct: onScanAnotherProduct
            )
        }
        .navigationDestination(isPresented: $showAllGoalMatches) {
            GoalMatchesListView(
                selectedGoal: selectedGoal,
                preferredGoals: preferredGoals,
                catalog: catalog,
                savedStore: savedStore,
                preferences: preferences,
                onScanAnotherProduct: onScanAnotherProduct
            )
        }
        .navigationDestination(isPresented: $showFullHistory) {
            RecentHistoryListView(
                products: recentProducts,
                catalog: catalog,
                savedStore: savedStore,
                preferences: preferences,
                onScanAnotherProduct: onScanAnotherProduct
            )
        }
        .sheet(isPresented: $showPaywall) {
            PicklyPaywallView()
        }
        .sheet(isPresented: $showProductRequest) {
            ProductRequestView(
                authStore: authStore,
                onOpenAccount: onOpenPreferences
            )
        }
        .onAppear {
            syncSelectedGoal(with: preferences)
        }
        .onChange(of: preferences) { _, newPreferences in
            syncSelectedGoal(with: newPreferences)
        }
        .task {
            await catalog.loadInitial()
        }
        .task(id: goalRecommendationTaskID) {
            guard hasPersonalGoals, !goalsForRecommendationLoad.isEmpty else { return }

            // Let the first local frame render, then enrich the shelf. The
            // network request suspends instead of occupying the scroll/tap path.
            await Task.yield()
            guard !Task.isCancelled else { return }
            await catalog.loadGoalRecommendations(
                for: goalsForRecommendationLoad,
                limit: 12
            )
        }
        .task(id: query) {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedQuery.count >= 2 else { return }

            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }

            await catalog.search(query: trimmedQuery)
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        PicklyListSectionHeader(
            title: "Search results",
            count: products.count
        )
        .picklyListSectionHeaderRow(top: 24, bottom: 10)

        if catalog.isLoading && products.isEmpty {
            ProgressView("Loading products…")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .picklyCardSurface(cornerRadius: 22)
                .picklyListCardRow(top: 10, bottom: 16)
        } else if products.isEmpty {
            Text(catalog.errorMessage ?? "No products yet. Try searching or scanning.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .picklyCardSurface(cornerRadius: 22)
                .picklyListCardRow(top: 10, bottom: 16)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            ProductSummaryList(
                products: products,
                reasonProvider: { product in
                    searchReason(for: product)
                },
                isSaved: { product in
                    savedStore.isSaved(product)
                },
                onToggleSave: { product in
                    savedStore.toggle(product)
                },
                accessibilityLabel: accessibilityLabel(for:),
                onSelect: { product in
                    selectedProduct = product
                }
            )
            .id("search-\(query)")
            .picklyListCardRow(top: 10, bottom: 16)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder
    private var goalsSection: some View {
        if hasPersonalGoals {
            PicklyListSectionHeader(
                title: "Your goals",
                subtitle: "Picked for your preferences",
                actionTitle: "Edit",
                actionIcon: "square.and.pencil",
                onAction: onOpenPreferences
            )
            .picklyListSectionHeaderRow(top: 24, bottom: 8)

            GoalScroller(
                goals: availableGoals,
                selectedGoal: $selectedGoal
            )

            if (catalog.isLoading || catalog.isLoadingGoalRecommendations) && goalMatchedProducts.isEmpty {
                ProgressView("Loading products…")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .picklyCardSurface(cornerRadius: 22)
                    .picklyListCardRow(top: 4, bottom: 16)
            } else if goalMatchedProducts.isEmpty {
                HomeEmptyStateCard(
                    title: catalog.goalRecommendationsErrorMessage == nil
                        ? "No verified matches yet"
                        : "Couldn't refresh matches",
                    message: catalog.goalRecommendationsErrorMessage
                        ?? "No catalog products are verified for this goal yet. Try another goal or scan a product.",
                    actionTitle: catalog.goalRecommendationsErrorMessage == nil
                        ? "Scan product"
                        : "Try again",
                    action: catalog.goalRecommendationsErrorMessage == nil
                        ? onScanAnotherProduct
                        : {
                            Task {
                                await catalog.retryGoalRecommendations(
                                    for: goalsForRecommendationLoad,
                                    limit: 12
                                )
                            }
                        }
                )
                .picklyListCardRow(top: 4, bottom: 16)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                ProductSummaryList(
                    products: homeGoalProducts,
                    reasonProvider: { product in
                        goalReason(for: product)
                    },
                    isSaved: { product in
                        savedStore.isSaved(product)
                    },
                    onToggleSave: { product in
                        savedStore.toggle(product)
                    },
                    accessibilityLabel: accessibilityLabel(for:),
                    onSelect: { product in
                        selectedProduct = product
                    }
                )
                .id("goals-\(selectedGoal.id)")
                .picklyListCardRow(top: 4, bottom: goalMatchedProducts.count > homeGoalPreviewLimit ? 8 : 16)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                HomeSeeAllButton(title: "See all") {
                    showAllGoalMatches = true
                }
                .picklyListCardRow(top: 0, bottom: 16)
            }
        } else {
            PicklyListSectionHeader(
                title: "Your goals",
                subtitle: "Picked for your preferences"
            )
            .picklyListSectionHeaderRow(top: 24, bottom: 10)

            HomeEmptyStateCard(
                title: "Set your goals",
                message: "Get picks matched to what matters to you.",
                actionTitle: "Choose goals",
                action: onOpenPreferences
            )
            .picklyListCardRow(top: 4, bottom: 16)
        }
    }

    @ViewBuilder
    private var goalRecommendationsSection: some View {
        if hasPersonalGoals, !homeGoalCarouselProducts.isEmpty {
            LockedGoalSectionHeader()
            .picklyListSectionHeaderRow(top: 22, bottom: 8)

            LockedProductCarousel(
                products: homeGoalCarouselProducts,
                reasonProvider: { product in
                    goalReason(for: product)
                },
                accessibilityItemName: "goal match",
                onUpgrade: {
                    showPaywall = true
                }
            )
            .id("goal-recommendations-\(selectedGoal.id)")
            .picklyListCardRow(top: 2, bottom: 16)
        }
    }

    private var premiumBanner: some View {
        PremiumBanner {
            showPaywall = true
        }
        .picklyListCardRow(top: 12, bottom: 12)
    }

    @ViewBuilder
    private var recentSection: some View {
        PicklyListSectionHeader(
            title: "Recent scans",
            subtitle: "Products you checked recently",
            actionTitle: recentProducts.isEmpty ? nil : "See all",
            onAction: recentProducts.isEmpty ? nil : { showFullHistory = true }
        )
        .picklyListSectionHeaderRow(top: 28, bottom: 10)

        if homeRecentProducts.isEmpty {
            HomeEmptyStateCard(
                title: "Nothing here yet",
                message: "Scan or search for your first product.",
                actionTitle: "Scan product",
                action: onScanAnotherProduct
            )
            .picklyListCardRow(top: 4, bottom: 16)
        } else {
            ProductSummaryList(
                products: homeRecentProducts,
                reasonProvider: { product in
                    recentReason(for: product)
                },
                isSaved: { product in
                    savedStore.isSaved(product)
                },
                onToggleSave: { product in
                    savedStore.toggle(product)
                },
                accessibilityLabel: accessibilityLabel(for:),
                onSelect: { product in
                    selectedProduct = product
                }
            )
            .picklyListCardRow(top: 4, bottom: 16)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    private func accessibilityLabel(for product: Product) -> String {
        if !product.isLimitedData, let score = product.score {
            return "\(product.name), \(product.brand), \(product.verdict), score \(score)"
        }

        return "\(product.name), \(product.brand), Limited data"
    }

    private func goalReason(for product: Product) -> String {
        if let match = GroceryGoal.primaryMatch(
            for: product,
            filter: selectedGoal,
            preferredGoals: preferredGoals
        ) {
            return match.productReason
        }

        return searchReason(for: product)
    }

    private func recentReason(for product: Product) -> String {
        if let match = preferredGoals.first(where: { $0.matches(product) }) {
            return match.productReason
        }

        return searchReason(for: product)
    }

    private func searchReason(for product: Product) -> String {
        if product.isLimitedData {
            return "Limited data"
        }

        if (product.sugarForScoring ?? .greatestFiniteMagnitude) <= 5 {
            return product.sugarLabel == "added sugar" ? "Low added sugar" : "Low sugar"
        }

        if (product.nutrition.salt100g ?? .greatestFiniteMagnitude) <= 0.8 {
            return "Lower salt"
        }

        if (product.nutrition.proteins100g ?? 0) >= 8 {
            return "Good protein"
        }

        if !product.ingredients.isEmpty && product.ingredients.count <= 4 {
            return "Short ingredients"
        }

        return product.positives.first ?? product.verdict
    }

    private func syncSelectedGoal(with preferences: UserPreferences) {
        guard GroceryGoal.available(in: preferences).contains(selectedGoal) else {
            selectedGoal = .all
            return
        }
    }
}

private struct GoalScroller: View {
    let goals: [GroceryGoal]
    @Binding var selectedGoal: GroceryGoal

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(goals) { goal in
                        Button {
                            toggle(goal)
                        } label: {
                            GoalChip(
                                goal: goal,
                                isSelected: selectedGoal == goal
                            )
                        }
                        .buttonStyle(PicklyPressableButtonStyle())
                        .accessibilityLabel(goal.title)
                        .accessibilityAddTraits(selectedGoal == goal ? .isSelected : [])
                    }
                }
                .scrollTargetLayout()
            }
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, PicklyLayout.screenHorizontalPadding, for: .scrollContent)
        .contentMargins(.horizontal, 0, for: .scrollIndicators)
        // Expand the shelf beyond the inset List cell, then keep its content
        // aligned with the screen grid. This prevents the final chip and its
        // glass shadow from being clipped by the row container.
        .padding(.horizontal, -PicklyLayout.screenHorizontalPadding)
        .scrollClipDisabled(true)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 14, trailing: 0))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func toggle(_ goal: GroceryGoal) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            selectedGoal = goal
        }
    }
}

private struct SearchViewBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private var blurRadius: CGFloat {
        reduceTransparency ? 0 : 2
    }

    private var imageOpacity: CGFloat {
        colorScheme == .dark ? 0.70 : 0.94
    }

    var body: some View {
        ZStack(alignment: .top) {
            PicklyColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Image("SearchBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 410)
                        .scaleEffect(1.04)
                        .blur(radius: blurRadius)
                        .opacity(imageOpacity)
                        .clipped()

                    LinearGradient(
                        colors: colorScheme == .light
                            ? [
                                PicklyColor.background.opacity(0.04),
                                PicklyColor.background.opacity(0.28),
                                PicklyColor.background.opacity(0.78),
                                PicklyColor.background
                            ]
                            : [
                                Color.black.opacity(0.34),
                                Color.black.opacity(0.25),
                                PicklyColor.background.opacity(0.72),
                                PicklyColor.background
                            ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: colorScheme == .light ? 300 : 410)
                }

                Spacer(minLength: 0)
            }
            .ignoresSafeArea(edges: .top)
        }
        .accessibilityHidden(true)
    }
}

private struct GoalChip: View {
    let goal: GroceryGoal
    let isSelected: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if reduceTransparency {
                chipContent
                    .background(
                        isSelected ? PicklyColor.mint : PicklyColor.card,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay {
                        chipBorder
                    }
            } else {
                chipContent
                    .glassEffect(
                        isSelected
                            ? .regular.tint(PicklyColor.primary.opacity(0.16)).interactive()
                            : .regular.interactive(),
                        in: .rect(cornerRadius: 18)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                    }
            }
        }
        .picklyCardShadow()
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isSelected)
    }

    private var chipContent: some View {
        HStack(spacing: 8) {
            PicklyIconImage(systemName: goal.systemImage, size: 16)

            Text(goal.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(isSelected ? PicklyColor.primary : .primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var chipBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(
                isSelected ? PicklyColor.primary.opacity(0.44) : PicklyColor.stroke.opacity(0.44),
                lineWidth: 1
            )
    }
}

private struct LockedGoalSectionHeader: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("More for your goals")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                Text("Healthier matches based on your preferences")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            PicklyPlusBadge()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MissingProductCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                PicklyIconImage(systemName: "barcode.viewfinder", size: 18)
                    .foregroundStyle(PicklyColor.primary)
                    .frame(width: 34, height: 34)
                    .background(PicklyColor.mint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Missing a product?")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Send its barcode or product details.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                Text("Request product")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PicklyColor.deepMarket)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(PicklyColor.primary.opacity(0.14), in: Capsule())
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .picklyCardSurface(
                cornerRadius: 18,
                fill: PicklyColor.card,
                stroke: PicklyColor.stroke.opacity(0.58)
            )
        }
        .buttonStyle(PicklyPressableButtonStyle())
    }
}

private struct PremiumBanner: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                PicklyIconImage(systemName: "sparkles", size: 22)
                    // The badge keeps the same pastel fill in both appearances,
                    // so its glyph must remain dark instead of following the
                    // adaptive dark-mode foreground used by deepMarket.
                    .foregroundStyle(PicklyColor.statusWarningForeground)
                    .frame(width: 42, height: 42)
                    .background(PicklyColor.brandLemon, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Get more from every scan")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Compare products, find better alternatives and unlock deeper insights.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PicklyColor.primary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .picklyGlassCardSurface(cornerRadius: 20)
        }
        .buttonStyle(PicklyPressableButtonStyle())
        .accessibilityLabel("Explore Premium. Get more from every scan.")
    }
}

private struct ProductRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authStore: AuthStore
    let onOpenAccount: (() -> Void)?

    @State private var barcode = ""
    @State private var productName = ""
    @State private var brand = ""
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false
    @State private var errorMessage: String?

    private let service = ProductRequestService()

    var body: some View {
        NavigationStack {
            content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(primaryActionTitle, action: primaryAction)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(PicklyColor.primary)
                .picklyProminentButtonForeground()
                .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(.regularMaterial)
                .disabled(isSubmitting || (isSignedIn && !didSubmit && !canSubmit))
            }
            .navigationTitle("Request product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await authStore.restoreSessionIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if authStore.isRestoringSession {
            ProgressView("Checking your account…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if didSubmit {
            ContentUnavailableView(
                "Request sent",
                systemImage: "checkmark.circle.fill",
                description: Text("Thanks. The product can now be reviewed for a future catalog update.")
            )
        } else if isSignedIn {
            Form {
                Section {
                    TextField("Barcode", text: $barcode)
                        .keyboardType(.numberPad)
                        .textContentType(.none)

                    TextField("Product name", text: $productName)
                    TextField("Brand", text: $brand)
                } header: {
                    Text("Product details")
                } footer: {
                    Text("Add a product name or a valid barcode. Brand is optional.")
                }

                Section("Anything else?") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        } else {
            ContentUnavailableView(
                "Sign in to send a request",
                systemImage: "person.crop.circle.badge.exclamationmark",
                description: Text("An account keeps product requests attributable and protected by Pickly's privacy rules.")
            )
        }
    }

    private var isSignedIn: Bool {
        authStore.currentSession != nil
    }

    private var canSubmit: Bool {
        let hasName = !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasValidBarcode = !trimmedBarcode.isEmpty && BarcodeValidator.normalize(trimmedBarcode) != nil
        return hasName || hasValidBarcode
    }

    private var primaryActionTitle: String {
        if didSubmit { return "Done" }
        if !isSignedIn { return "Open Profile" }
        return isSubmitting ? "Sending…" : "Send request"
    }

    private func primaryAction() {
        if didSubmit {
            dismiss()
        } else if !isSignedIn {
            dismiss()
            onOpenAccount?()
        } else {
            submit()
        }
    }

    private func submit() {
        guard let session = authStore.currentSession else { return }

        do {
            let draft = try ProductRequestDraft(
                barcode: barcode,
                name: productName,
                brand: brand,
                note: note
            )
            isSubmitting = true
            errorMessage = nil

            Task {
                do {
                    try await service.submit(draft, session: session)
                    didSubmit = true
                } catch {
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
                isSubmitting = false
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct HomeEmptyStateCard: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PicklyColor.deepMarket)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PicklyColor.primary.opacity(0.14), in: Capsule())
                }
                .buttonStyle(PicklyPressableButtonStyle())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(cornerRadius: 22, stroke: PicklyColor.stroke.opacity(0.45))
        .accessibilityElement(children: .combine)
    }
}

private struct HomeSeeAllButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(PicklyColor.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .picklyCardSurface(cornerRadius: 18, stroke: PicklyColor.stroke.opacity(0.45))
        }
        .buttonStyle(PicklyPressableButtonStyle())
        .accessibilityLabel(title)
    }
}

private enum ProductSortOption: String, CaseIterable, Identifiable {
    case bestMatch = "Best match"
    case highestScore = "Highest score"
    case recentlyAdded = "Recently added"

    var id: String { rawValue }
}

private enum DietaryFilter: String, CaseIterable, Identifiable {
    case any
    case vegetarian
    case vegan
    case glutenFree
    case lactoseFree

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: "Any"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .glutenFree: "Gluten-free"
        case .lactoseFree: "Lactose-free"
        }
    }

    func matches(_ product: Product) -> Bool {
        switch self {
        case .any:
            return true
        case .vegetarian:
            return product.dietary.vegetarian == .confirmed
        case .vegan:
            return product.dietary.vegan == .confirmed
        case .glutenFree:
            return product.dietary.glutenFree == .confirmed
        case .lactoseFree:
            return product.dietary.lactoseFree == .confirmed
        }
    }
}

private struct GoalMatchesListView: View {
    let preferredGoals: [GroceryGoal]
    @ObservedObject var catalog: ProductCatalogStore
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences
    var onScanAnotherProduct: (() -> Void)? = nil

    @State private var selectedGoal: GroceryGoal
    @State private var query = ""
    @State private var sortOption: ProductSortOption = .bestMatch
    @State private var showFilters = false
    @State private var selectedCategory: String?
    @State private var selectedBrand: String?
    @State private var minimumScore = 0
    @State private var dietaryFilter: DietaryFilter = .any
    @State private var selectedProduct: Product?

    init(
        selectedGoal: GroceryGoal,
        preferredGoals: [GroceryGoal],
        catalog: ProductCatalogStore,
        savedStore: SavedProductsStore,
        preferences: UserPreferences,
        onScanAnotherProduct: (() -> Void)? = nil
    ) {
        self.preferredGoals = preferredGoals
        self.catalog = catalog
        self.savedStore = savedStore
        self.preferences = preferences
        self.onScanAnotherProduct = onScanAnotherProduct
        _selectedGoal = State(initialValue: selectedGoal)
    }

    private var availableGoals: [GroceryGoal] {
        [.all] + preferredGoals
    }

    private var listTitle: String {
        selectedGoal == .all ? "Your goals" : selectedGoal.title
    }

    private var goalProducts: [Product] {
        GroceryGoal.healthiestMatchingProducts(
            in: catalog.products,
            filter: selectedGoal,
            preferredGoals: preferredGoals
        )
    }

    private var categoryOptions: [String] {
        Set(goalProducts.map(\.category)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private var brandOptions: [String] {
        Set(goalProducts.map(\.brand)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private var filteredProducts: [Product] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = goalProducts.filter { product in
            let matchesQuery = normalizedQuery.isEmpty
                || product.name.localizedCaseInsensitiveContains(normalizedQuery)
                || product.brand.localizedCaseInsensitiveContains(normalizedQuery)
            let matchesCategory = selectedCategory == nil || product.category == selectedCategory
            let matchesBrand = selectedBrand == nil || product.brand == selectedBrand
            let matchesScore = minimumScore == 0 || (product.score ?? -1) >= minimumScore

            return matchesQuery
                && matchesCategory
                && matchesBrand
                && matchesScore
                && dietaryFilter.matches(product)
        }

        switch sortOption {
        case .bestMatch:
            return matching
        case .highestScore:
            return matching.sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return (lhs.score ?? -1) > (rhs.score ?? -1)
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .recentlyAdded:
            let positions = catalog.products.enumerated().reduce(into: [String: Int]()) { result, entry in
                result[entry.element.id] = entry.offset
            }
            return matching.sorted { lhs, rhs in
                (positions[lhs.id] ?? -1) > (positions[rhs.id] ?? -1)
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("Picked for your preferences")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                PicklyInlineSearchField(
                    text: $query,
                    prompt: "Search products or brands",
                    onScan: onScanAnotherProduct
                )
                .padding(.bottom, 4)

                GoalScroller(
                    goals: availableGoals,
                    selectedGoal: $selectedGoal
                )

                sortAndFilterBar

                if filteredProducts.isEmpty {
                    HomeEmptyStateCard(
                        title: goalProducts.isEmpty ? "No matches yet" : "No products found",
                        message: goalProducts.isEmpty
                            ? "Scan more products to find picks for your goals."
                            : "Try another search or clear a filter.",
                        actionTitle: goalProducts.isEmpty ? "Scan product" : nil,
                        action: goalProducts.isEmpty ? onScanAnotherProduct : nil
                    )
                    .padding(.top, 8)
                } else {
                    ProductSummaryList(
                        products: filteredProducts,
                        reasonProvider: { product in
                            GroceryGoal.primaryMatch(
                                for: product,
                                filter: selectedGoal,
                                preferredGoals: preferredGoals
                            )?.productReason ?? product.verdict
                        },
                        isSaved: { savedStore.isSaved($0) },
                        onToggleSave: { savedStore.toggle($0) },
                        accessibilityLabel: accessibilityLabel(for:),
                        onSelect: { selectedProduct = $0 }
                    )
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
            .safeAreaPadding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(PicklyColor.background)
        .navigationTitle(listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedProduct) { product in
            ProductResultView(
                product: product,
                productService: catalog,
                savedStore: savedStore,
                preferences: preferences,
                onScanAnotherProduct: onScanAnotherProduct
            )
        }
        .onChange(of: selectedGoal) { _, _ in
            selectedCategory = nil
            selectedBrand = nil
        }
        .sheet(isPresented: $showFilters) {
            AdvancedProductFiltersView(
                category: $selectedCategory,
                brand: $selectedBrand,
                minimumScore: $minimumScore,
                dietaryFilter: $dietaryFilter,
                categories: categoryOptions,
                brands: brandOptions
            )
            .presentationDetents([.medium, .large])
        }
        .task(id: query) {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedQuery.count >= 2 else { return }

            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            await catalog.search(query: trimmedQuery)
        }
    }

    private var sortAndFilterBar: some View {
        HStack(spacing: 10) {
            Menu {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(ProductSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }

            Button {
                showFilters = true
            } label: {
                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
            }

            Spacer(minLength: 0)

            Text(filteredProducts.count, format: .number)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(filteredProducts.count) results")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(PicklyColor.primary)
        .padding(.vertical, 12)
    }

    private func accessibilityLabel(for product: Product) -> String {
        if !product.isLimitedData, let score = product.score {
            return "\(product.name), \(product.brand), \(product.verdict), score \(score)"
        }
        return "\(product.name), \(product.brand), Limited data"
    }
}

private struct AdvancedProductFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var category: String?
    @Binding var brand: String?
    @Binding var minimumScore: Int
    @Binding var dietaryFilter: DietaryFilter
    let categories: [String]
    let brands: [String]

    var body: some View {
        NavigationStack {
            Form {
                Section("Goals") {
                    Text("Use the goal chips above to change the active preference.")
                        .foregroundStyle(.secondary)
                }

                Section("Category and brand") {
                    Picker("Category", selection: categorySelection) {
                        Text("Any category").tag("")
                        ForEach(categories, id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }

                    Picker("Brand", selection: brandSelection) {
                        Text("Any brand").tag("")
                        ForEach(brands, id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }
                }

                Section("Score") {
                    Picker("Minimum score", selection: $minimumScore) {
                        Text("Any score").tag(0)
                        Text("70 and above").tag(70)
                        Text("85 and above").tag(85)
                    }
                }

                Section("Dietary attributes") {
                    Picker("Preference", selection: $dietaryFilter) {
                        ForEach(DietaryFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section {
                    Button("Clear filters", role: .destructive) {
                        category = nil
                        brand = nil
                        minimumScore = 0
                        dietaryFilter = .any
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var categorySelection: Binding<String> {
        Binding(
            get: { category ?? "" },
            set: { category = $0.isEmpty ? nil : $0 }
        )
    }

    private var brandSelection: Binding<String> {
        Binding(
            get: { brand ?? "" },
            set: { brand = $0.isEmpty ? nil : $0 }
        )
    }
}

private struct RecentHistoryListView: View {
    let products: [Product]
    @ObservedObject var catalog: ProductCatalogStore
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences
    var onScanAnotherProduct: (() -> Void)? = nil

    @State private var query = ""
    @State private var selectedProduct: Product?

    private var filteredProducts: [Product] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return products }

        return products.filter { product in
            product.name.localizedCaseInsensitiveContains(normalizedQuery)
                || product.brand.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("Products you checked recently")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .padding(.bottom, 12)

                PicklyInlineSearchField(
                    text: $query,
                    prompt: "Search recent scans",
                    onScan: onScanAnotherProduct
                )
                .padding(.bottom, 8)

                if filteredProducts.isEmpty {
                    HomeEmptyStateCard(
                        title: products.isEmpty ? "Nothing here yet" : "No scans found",
                        message: products.isEmpty
                            ? "Scan or search for your first product."
                            : "Try another product name or brand.",
                        actionTitle: products.isEmpty ? "Scan product" : nil,
                        action: products.isEmpty ? onScanAnotherProduct : nil
                    )
                } else {
                    ProductSummaryList(
                        products: filteredProducts,
                        reasonProvider: { product in
                            if product.isLimitedData {
                                return "Limited data"
                            }
                            return product.positives.first ?? product.verdict
                        },
                        isSaved: { savedStore.isSaved($0) },
                        onToggleSave: { savedStore.toggle($0) },
                        accessibilityLabel: { product in
                            if !product.isLimitedData, let score = product.score {
                                return "\(product.name), \(product.brand), \(product.verdict), score \(score)"
                            }
                            return "\(product.name), \(product.brand), Limited data"
                        },
                        onSelect: { selectedProduct = $0 }
                    )
                }
            }
            .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
            .safeAreaPadding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .background(PicklyColor.background)
        .navigationTitle("Recent scans")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedProduct) { product in
            ProductResultView(
                product: product,
                productService: catalog,
                savedStore: savedStore,
                preferences: preferences,
                onScanAnotherProduct: onScanAnotherProduct
            )
        }
    }
}

#Preview {
    NavigationStack {
        SearchView(
            catalog: ProductCatalogStore.preview,
            savedStore: SavedProductsStore(),
            authStore: AuthStore(),
            preferences: .prototype
        )
    }
    .environmentObject(SubscriptionStore(loadProducts: false))
}
