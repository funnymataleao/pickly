import SwiftUI

struct SearchView: View {
    @ObservedObject var catalog: ProductCatalogStore
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences
    var onOpenPreferences: (() -> Void)? = nil

    @State private var query = ""
    @State private var selectedGoal: GroceryGoal = .all
    @State private var showProductRequest = false
    @State private var selectedProduct: Product?

    private var products: [Product] {
        catalog.searchProducts(matching: query)
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var recentProducts: [Product] {
        savedStore.recentProducts
            .prefix(3)
            .compactMap { recentProduct in
                savedStore.product(id: recentProduct.productId) ?? catalog.product(id: recentProduct.productId)
            }
    }

    private var availableGoals: [GroceryGoal] {
        GroceryGoal.available(in: preferences)
    }

    private var hasPersonalGoals: Bool {
        availableGoals.count > 1
    }

    private var selectedFilteringGoals: [GroceryGoal] {
        selectedGoal == .all ? [] : [selectedGoal]
    }

    private var productSectionTitle: String {
        if isSearching {
            return "Search results"
        }

        if selectedGoal == .all {
            return "Products to check"
        }

        return selectedGoal.productSectionTitle
    }

    private var visibleProducts: [Product] {
        if isSearching {
            return products
        }

        let filteringGoals = selectedFilteringGoals

        let source = filteringGoals.isEmpty
            ? catalog.products
            : catalog.products.filter { product in
                filteringGoals.allSatisfy { goal in
                    goal.matches(product)
                }
            }

        return source.sorted { lhs, rhs in
            (lhs.score ?? -1) > (rhs.score ?? -1)
        }
    }

    var body: some View {
        List {
            PicklyContentHeader(
                title: "Check your groceries",
                subtitle: "Find better picks faster."
            )
                .picklyContentHeaderRow()

            PicklyInlineSearchField(text: $query, prompt: "Search products or brands")
                .picklyContentHeaderRow(top: 0, bottom: 14)

            goalsSection

            productListSection

            if !isSearching, !recentProducts.isEmpty {
                recentlyCheckedSection
            }

            MissingProductCard {
                showProductRequest = true
            }
            .picklyListCardRow(top: 8, bottom: 16)
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, PicklyLayout.rootTopPadding, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(PicklyColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showProductRequest) {
            ProductRequestPlaceholderView()
        }
        .navigationDestination(item: $selectedProduct) { product in
            ProductResultView(
                product: product,
                productService: catalog,
                savedStore: savedStore,
                preferences: preferences
            )
        }
        .navigationDestination(for: Product.self) { product in
            ProductResultView(
                product: product,
                productService: catalog,
                savedStore: savedStore,
                preferences: preferences
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
        .task(id: query) {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedQuery.count >= 2 else { return }

            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }

            await catalog.search(query: trimmedQuery)
        }
    }

    @ViewBuilder
    private var goalsSection: some View {
        if hasPersonalGoals {
            sectionHeader("Your goals", top: 18)

            GoalScroller(
                goals: availableGoals,
                selectedGoal: $selectedGoal
            )
        } else {
            GoalsSetupCard(onChooseGoals: onOpenPreferences)
                .picklyListCardRow(top: 18, bottom: 10)
        }
    }

    @ViewBuilder
    private var productListSection: some View {
        sectionHeader(productSectionTitle, top: 24)

        if catalog.isLoading && visibleProducts.isEmpty {
            ProgressView("Loading products…")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .picklyCardSurface(cornerRadius: 18)
                .picklyListCardRow(top: 8, bottom: 14)
        } else if visibleProducts.isEmpty {
            Text(catalog.errorMessage ?? "No products yet. Try searching or scanning.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .picklyCardSurface(cornerRadius: 18)
                .picklyListCardRow(top: 8, bottom: 14)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            SearchProductList(
                products: visibleProducts,
                selectedGoals: selectedFilteringGoals,
                isSaved: { product in
                    savedStore.isSaved(product)
                },
                accessibilityLabel: accessibilityLabel(for:),
                onSelect: { product in
                    selectedProduct = product
                }
            )
            .id(productListAnimationID)
            .picklyListCardRow(top: 8, bottom: 14)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder
    private var recentlyCheckedSection: some View {
        sectionHeader("Recently checked", top: 26)

        SearchProductList(
            products: recentProducts,
            selectedGoals: [],
            isSaved: { product in
                savedStore.isSaved(product)
            },
            accessibilityLabel: accessibilityLabel(for:),
            onSelect: { product in
                selectedProduct = product
            }
        )
        .picklyListCardRow(top: 8, bottom: 14)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var productListAnimationID: String {
        if isSearching {
            return "search-\(query)"
        }

        return selectedGoal.id
    }

    private func sectionHeader(_ title: String, top: CGFloat = 22) -> some View {
        PicklyListSectionHeader(title: title)
            .picklyListSectionHeaderRow(top: top, bottom: 6)
    }

    private func accessibilityLabel(for product: Product) -> String {
        if !product.isLimitedData, let score = product.score {
            return "\(product.name), \(product.brand), \(product.verdict), score \(score)"
        }

        return "\(product.name), \(product.brand), Limited data"
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
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
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

private struct GoalChip: View {
    let goal: GroceryGoal
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: goal.systemImage)
                .font(.subheadline.weight(.semibold))

            Text(goal.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(isSelected ? PicklyColor.deepMarket : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .picklyCardSurface(
            cornerRadius: 18,
            fill: isSelected ? PicklyColor.primary.opacity(0.16) : PicklyColor.card,
            stroke: isSelected ? PicklyColor.primary.opacity(0.42) : PicklyColor.stroke.opacity(0.52)
        )
        .contentShape(Capsule())
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isSelected)
    }
}

private struct GoalsSetupCard: View {
    let onChooseGoals: (() -> Void)?

    var body: some View {
        Group {
            if let onChooseGoals {
                Button(action: onChooseGoals) {
                    content
                }
                .buttonStyle(PicklyPressableButtonStyle())
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set grocery goals. Open Profile to choose preferences.")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Set grocery goals")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Turn on preferences in Profile to show quick filters here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if onChooseGoals != nil {
                HStack(spacing: 6) {
                    Text("Open Profile")
                        .font(.subheadline.weight(.semibold))

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(PicklyColor.primary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(
            cornerRadius: 20,
            fill: PicklyColor.card,
            stroke: PicklyColor.stroke.opacity(0.48)
        )
    }
}

private struct SearchProductList: View {
    let products: [Product]
    let selectedGoals: [GroceryGoal]
    let isSaved: (Product) -> Bool
    let accessibilityLabel: (Product) -> String
    let onSelect: (Product) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(products) { product in
                Button {
                    onSelect(product)
                } label: {
                    SearchProductCard(
                        product: product,
                        reason: reason(for: product),
                        isSaved: isSaved(product)
                    )
                }
                .buttonStyle(PicklyPressableButtonStyle())
                .accessibilityLabel(accessibilityLabel(product))
            }
        }
    }

    private func reason(for product: Product) -> String {
        if product.isLimitedData {
            return "Limited data"
        }

        if let matchingGoal = selectedGoals.first(where: { $0.matches(product) }) {
            return matchingGoal.productReason
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
}

private struct SearchProductCard: View {
    let product: Product
    let reason: String
    let isSaved: Bool

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnailView(product: product, size: 48, cornerRadius: 13)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(product.brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(reason)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 8)

            VStack(spacing: 5) {
                CompactVerdictBadge(product: product)

                if isSaved {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(PicklyColor.primary)
                        .accessibilityLabel("Saved")
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(cornerRadius: 18)
    }
}

private struct CompactVerdictBadge: View {
    let product: Product

    var body: some View {
        VStack(spacing: 2) {
            Text(product.verdict)
                .font(.caption2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            if !product.isLimitedData, let score = product.score {
                Text("\(score)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(product.verdictForegroundColor)
        .padding(.horizontal, 9)
        .frame(width: product.isLimitedData ? 76 : 58, height: 42)
        .background(product.verdictFillColor, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(product.verdictColor.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct MissingProductCard: View {
    let onRequestProduct: () -> Void

    var body: some View {
        Button(action: onRequestProduct) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "plus.viewfinder")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(PicklyColor.primary)
                    .frame(width: 34, height: 34)
                    .background(PicklyColor.mint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Missing a product?")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Request it with a barcode and photos.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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

struct ProductRequestPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    let barcode: String?

    init(barcode: String? = nil) {
        self.barcode = barcode
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(PicklyColor.primary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Request product")
                        .font(.title.bold())

                    Text(barcode == nil ? "Request a product with a barcode and optional photos." : "This barcode will be included with your request. You can add photos later.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let barcode {
                    HStack(spacing: 8) {
                        Image(systemName: "number")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(barcode)
                            .font(.footnote.monospacedDigit().weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PicklyColor.stroke.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Barcode \(barcode)")
                }

                VStack(alignment: .leading, spacing: 12) {
                    RequestStepRow(systemImage: "barcode.viewfinder", title: "Share the barcode")
                    RequestStepRow(systemImage: "camera", title: "Add optional photos")
                    RequestStepRow(systemImage: "checkmark.seal", title: "Product can be reviewed later")
                }

                Button {
                    dismiss()
                } label: {
                    Text("Got it")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PicklyColor.primary)
                .picklyProminentButtonForeground()

                Spacer()
            }
            .padding(20)
            .navigationTitle("Request product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RequestStepRow: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(PicklyColor.primary)
                .frame(width: 30, height: 30)
                .background(PicklyColor.mint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(title)
                .font(.headline)

            Spacer()
        }
        .padding(14)
        .picklyCardSurface(cornerRadius: 16)
    }
}

#Preview {
    NavigationStack {
        SearchView(
            catalog: ProductCatalogStore.preview,
            savedStore: SavedProductsStore(),
            preferences: .prototype
        )
    }
}
