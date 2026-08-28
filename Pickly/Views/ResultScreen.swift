import SwiftUI
import UIKit

struct ResultScreen: View {
    let product: Product
    let productService: any ProductService
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences
    var onScanAnotherProduct: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var showStickyHeader = false
    @State private var saveBounce = false
    @State private var showPaywall = false
    @State private var alternativeSelection = AlternativeShelfSelection(kind: .similar, products: [])
    @State private var isLoadingRelatedProducts = false
    @State private var hasLoadedRelatedProducts = false
    @State private var relatedProductsErrorMessage: String?

    // One native content grid for the image, verdict, and every detail card.
    private let contentHorizontalInset = PicklyLayout.screenHorizontalPadding

    private var visibleInsights: [ProductInsight] {
        product.keyInsights.filter { $0.resultStatus != .unknown }
    }

    private var shouldShowStickyHeader: Bool {
        showStickyHeader
    }

    private var shouldShowDataConfidence: Bool {
        product.isLimitedData || product.name == "Unknown product"
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    scrollOffsetReader

                    VStack(alignment: .leading, spacing: 22) {
                        ResultHero(
                            product: product,
                            imageRevealed: true,
                            displayedScore: product.score ?? 0,
                            showVerdict: true
                        )

                        if product.isSampleData {
                            SampleDataNotice()
                        }

                        KeyInsights(
                            insights: visibleInsights,
                            visibleCount: visibleInsights.count
                        )

                        AlternativesResultSection(
                            product: product,
                            selection: alternativeSelection,
                            productService: productService,
                            savedStore: savedStore,
                            preferences: preferences,
                            onScanAnotherProduct: onScanAnotherProduct,
                            isPlus: subscriptionStore.isPlus,
                            isLoading: isLoadingRelatedProducts,
                            errorMessage: relatedProductsErrorMessage,
                            onRetry: {
                                Task {
                                    await retryRelatedProducts()
                                }
                            },
                            onUpgrade: { showPaywall = true }
                        )
                        .id("better-choices")

                        WatchOutsSection(warnings: product.warnings)

                        if !product.ingredients.isEmpty {
                            IngredientsSection(ingredients: product.ingredientAnalyses)
                        }

                        if shouldShowDataConfidence {
                            DataConfidenceCard()
                        }

                        NutritionSummary(product: product)

                        ScoringMethodologyLinkCard()

                        if !product.recommendations.isEmpty {
                            RecommendationsCard(recommendations: product.recommendations)
                        }

                        ResultActions(
                            isSaved: savedStore.isSaved(product),
                            saveBounce: saveBounce,
                            onScanAnotherProduct: scanAnotherProduct,
                            onSave: toggleSave
                        )
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, contentHorizontalInset)
                    .padding(.top, 12)
                }
                .coordinateSpace(name: "resultScroll")
                .onPreferenceChange(ResultScrollOffsetPreferenceKey.self) { value in
                    let shouldShow = value < -190
                    guard shouldShow != showStickyHeader else { return }
                    showStickyHeader = shouldShow
                }
                .onAppear {
#if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-pickly-scroll-alternatives") {
                        Task { @MainActor in
                            await Task.yield()
                            proxy.scrollTo("better-choices", anchor: .top)
                        }
                    }
#endif
                }
            }
        }
        .background(PicklyColor.background)
        .navigationTitle(shouldShowStickyHeader ? product.resultDisplayName : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleSave) {
                    PicklyIconImage(
                        systemName: savedStore.isSaved(product) ? "bookmark.fill" : "bookmark.outline",
                        size: 19
                    )
                    .foregroundStyle(savedStore.isSaved(product) ? PicklyColor.primary : .primary)
                    .frame(width: 36, height: 36)
                    .scaleEffect(saveBounce ? 1.14 : 1)
                }
                .accessibilityLabel(savedStore.isSaved(product) ? "Saved" : "Save result")
                .accessibilityHint("Adds or removes this product from Saved.")
            }
        }
        // Product details are a focused drill-down. Keeping the tab bar visible
        // here obscures the first result card and competes with the native back action.
        .toolbar(.hidden, for: .tabBar)
        .task(id: product.id) {
            // History is not needed to draw the destination. Let the native
            // push finish first and cancel this work if the user immediately
            // goes back.
            guard await pauseBackgroundWork(for: 350_000_000) else { return }
            savedStore.recordView(product)
        }
        .task(id: "related-\(product.id)") {
            await loadRelatedProducts()
        }
        .sheet(isPresented: $showPaywall) {
            PicklyPaywallView(entryPoint: .alternatives)
        }
    }

    private var scrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: ResultScrollOffsetPreferenceKey.self,
                    value: proxy.frame(in: .named("resultScroll")).minY
                )
        }
        .frame(height: 0)
    }

    private func pauseBackgroundWork(for nanoseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    @MainActor
    private func loadRelatedProducts() async {
        guard !hasLoadedRelatedProducts else { return }
        relatedProductsErrorMessage = nil
        isLoadingRelatedProducts = true
        defer { isLoadingRelatedProducts = false }

        // Keep the initial push completely free for navigation and touch
        // handling. The shelf can populate a fraction of a second later.
        guard await pauseBackgroundWork(for: 180_000_000) else { return }

        // Ranking a large catalog during the push animation made the first tap
        // feel ignored. Snapshot the actor-owned data, then rank it away from
        // the main actor.
        let catalog = productService.products
        let localSelection = await Self.makeAlternativeSelection(
            for: product,
            alternatives: [],
            catalog: catalog
        )
        guard !Task.isCancelled else { return }
        applyAlternativeSelectionIfChanged(localSelection)

        let relatedProducts = await productService.relatedProducts(for: product, limit: 100)
        guard !Task.isCancelled else { return }
        relatedProductsErrorMessage = productService.relatedProductsErrorMessage

        let updatedCatalog = productService.products
        let updatedSelection = await Self.makeAlternativeSelection(
            for: product,
            alternatives: relatedProducts,
            catalog: updatedCatalog
        )
        guard !Task.isCancelled else { return }
        applyAlternativeSelectionIfChanged(updatedSelection)
        hasLoadedRelatedProducts = true
    }

    private func applyAlternativeSelectionIfChanged(_ selection: AlternativeShelfSelection) {
        let currentIDs = alternativeSelection.products.map(\.id)
        let updatedIDs = selection.products.map(\.id)
        guard alternativeSelection.kind != selection.kind || currentIDs != updatedIDs else {
            return
        }
        alternativeSelection = selection
    }

    @MainActor
    private func retryRelatedProducts() async {
        hasLoadedRelatedProducts = false
        await loadRelatedProducts()
    }

    private nonisolated static func makeAlternativeSelection(
        for product: Product,
        alternatives: [Product],
        catalog: [Product]
    ) async -> AlternativeShelfSelection {
        await Task.detached(priority: .userInitiated) {
            let resolvedAlternatives = alternatives.isEmpty
                ? product.alternativeIDs.compactMap { alternativeID in
                    catalog.first { $0.id == alternativeID }
                }
                : alternatives
            return AlternativePreviewBuilder.selection(
                for: product,
                alternatives: resolvedAlternatives,
                catalog: catalog,
                limit: 100
            )
        }.value
    }

    private func toggleSave() {
        savedStore.toggle(product)
        playTapHaptic()

        withAnimation(.spring(response: 0.22, dampingFraction: 0.48)) {
            saveBounce = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                saveBounce = false
            }
        }
    }

    private func scanAnotherProduct() {
        playTapHaptic()
        dismiss()

        Task { @MainActor in
            await Task.yield()
            onScanAnotherProduct?()
        }
    }

    private func playTapHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct SampleDataNotice: View {
    var body: some View {
        Label {
            Text("Sample product data for this prototype")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            PicklyIconImage(systemName: "flask")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(
            cornerRadius: 16,
            fill: PicklyColor.mint.opacity(0.72),
            stroke: PicklyColor.stroke.opacity(0.45)
        )
        .accessibilityLabel("Sample product data for this prototype")
    }
}

private struct ResultSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.secondary.opacity(0.12))
                    .frame(height: 316)

                ForEach(0..<4, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 12) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.secondary.opacity(0.14))
                            .frame(width: index == 0 ? 180 : 140, height: 18)

                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.secondary.opacity(0.1))
                            .frame(height: index == 1 ? 150 : 96)
                    }
                }
            }
            .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
            .padding(.vertical, 16)
        }
        .scrollClipDisabled()
        .background(PicklyColor.background)
        .accessibilityLabel("Loading product analysis")
    }
}

private struct ResultScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue = 0.0

    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = nextValue()
    }
}
