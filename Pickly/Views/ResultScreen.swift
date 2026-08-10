import SwiftUI
import UIKit

struct ResultScreen: View {
    let product: Product
    let productService: any ProductService
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences
    var onScanAnotherProduct: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var isShowingSkeleton = true
    @State private var imageRevealed = false
    @State private var displayedScore = 0
    @State private var showVerdict = false
    @State private var visibleInsightCount = 0
    @State private var showStickyHeader = false
    @State private var saveBounce = false
    @State private var showPaywall = false

    // One native content grid for the image, verdict, and every detail card.
    private let contentHorizontalInset = PicklyLayout.screenHorizontalPadding

    private var alternatives: [Product] {
        productService.alternatives(for: product)
    }

    private var alternativePreviewProducts: [Product] {
        return AlternativePreviewBuilder.products(
            for: product,
            alternatives: alternatives,
            catalog: productService.products,
            limit: 30
        )
    }

    private var shouldShowStickyHeader: Bool {
        showStickyHeader && !isShowingSkeleton
    }

    private var shouldShowDataConfidence: Bool {
        product.isLimitedData || product.name == "Unknown product" || product.ingredients.isEmpty
    }

    var body: some View {
        ZStack(alignment: .top) {
            if isShowingSkeleton {
                ResultSkeletonView()
                    .transition(.opacity)
            } else {
                ScrollView {
                    scrollOffsetReader

                    VStack(alignment: .leading, spacing: 22) {
                        ResultHero(
                            product: product,
                            imageRevealed: imageRevealed,
                            displayedScore: displayedScore,
                            showVerdict: showVerdict
                        )

                        if product.isSampleData {
                            SampleDataNotice()
                        }

                        KeyInsights(
                            insights: product.keyInsights,
                            visibleCount: visibleInsightCount
                        )

                        WatchOutsSection(warnings: product.warnings)

                        ForYouSection(notes: product.forYouMessages(preferences: preferences))

                        IngredientsSection(ingredients: product.ingredientAnalyses)

                        if shouldShowDataConfidence {
                            DataConfidenceCard(
                                onScanAgain: scanAnotherProduct
                            )
                        }

                        NutritionSummary(product: product)

                        if !product.recommendations.isEmpty {
                            RecommendationsCard(recommendations: product.recommendations)
                        }

                        AlternativesResultSection(
                            product: product,
                            alternatives: alternatives,
                            previewProducts: alternativePreviewProducts,
                            savedStore: savedStore,
                            isPlus: subscriptionStore.isPlus,
                            onUpgrade: { showPaywall = true }
                        )

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
                .transition(.opacity)
            }

        }
        .background(PicklyColor.background)
        .navigationTitle(shouldShowStickyHeader ? product.resultDisplayName : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleSave) {
                    PicklyIconImage(
                        systemName: savedStore.isSaved(product) ? "bookmark.fill" : "bookmark",
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
            savedStore.recordView(product)
            await runRevealSequence()
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

    @MainActor
    private func runRevealSequence() async {
        resetRevealState()

        let finalScore = product.score ?? 0
        if reduceMotion {
            isShowingSkeleton = false
            imageRevealed = true
            displayedScore = finalScore
            showVerdict = true
            visibleInsightCount = product.keyInsights.count
            return
        }

        guard await pauseReveal(for: 80_000_000) else { return }
        guard !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.16)) {
            isShowingSkeleton = false
        }

        guard await pauseReveal(for: 40_000_000) else { return }
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            imageRevealed = true
        }

        withAnimation(.easeOut(duration: 0.18)) {
            showVerdict = true
            visibleInsightCount = product.keyInsights.count
        }

        guard !Task.isCancelled else { return }
        playAnalysisHaptic()
        await countScore(to: finalScore)
    }

    @MainActor
    private func resetRevealState() {
        isShowingSkeleton = true
        imageRevealed = false
        displayedScore = 0
        showVerdict = false
        visibleInsightCount = 0
    }

    @MainActor
    private func countScore(to finalScore: Int) async {
        guard finalScore > 0 else {
            displayedScore = 0
            return
        }

        let steps = 16
        for step in 0...steps {
            guard !Task.isCancelled else { return }
            displayedScore = Int((Double(finalScore) * Double(step) / Double(steps)).rounded())
            guard await pauseReveal(for: 14_000_000) else { return }
        }
    }

    private func pauseReveal(for nanoseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
            return !Task.isCancelled
        } catch {
            return false
        }
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

    private func playAnalysisHaptic() {
        guard !reduceMotion else {
            return
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
