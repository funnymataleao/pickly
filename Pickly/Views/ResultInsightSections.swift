import SwiftUI

private enum ResultSurface {
    static let card = PicklyColor.card
    static let stroke = PicklyColor.stroke.opacity(0.72)
}

struct KeyInsights: View {
    let insights: [ProductInsight]
    let visibleCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Why this score?", systemImage: "sparkle.magnifyingglass")

            VStack(spacing: 10) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    if index < visibleCount {
                        InsightRow(insight: insight)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
    }
}

struct InsightRow: View {
    let insight: ProductInsight

    private var palette: PicklyColor.StatusPalette {
        insight.visualPalette
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            PicklyIconImage(systemName: insight.icon, size: 18)
                .foregroundStyle(palette.foreground)
                .frame(width: 36, height: 36)
                .background(palette.fill, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(insight.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            insightStatus
                            Text(insight.value)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(insight.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                        insightStatus

                    Spacer(minLength: 4)

                    Text(insight.value)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    }
                }

                Text(insight.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .picklyCardSurface(
            cornerRadius: 18,
            fill: ResultSurface.card,
            stroke: palette.border.opacity(0.12)
        )
    }

    private var insightStatus: some View {
        Text(insight.status)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(palette.foreground)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(palette.fill, in: Capsule())
    }
}

struct WatchOutsSection: View {
    let warnings: [String]

    private var visibleWarnings: [String] {
        Array(warnings.prefix(3))
    }

    var body: some View {
        if !visibleWarnings.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "What to watch", systemImage: "eye")

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(visibleWarnings, id: \.self) { warning in
                        Label(warning, picklyIcon: "circle", iconSize: 8)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .picklyCardSurface(
                    cornerRadius: 20,
                    fill: ResultSurface.card,
                    stroke: PicklyColor.statusWarningAccent.opacity(0.18)
                )
            }
        }
    }
}

struct ForYouSection: View {
    let notes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "For you", systemImage: "person.crop.circle")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(notes, id: \.self) { note in
                    let presentation = Self.presentation(for: note)
                    Label(note, picklyIcon: presentation.icon, iconSize: 16)
                        .font(.body)
                        .foregroundStyle(presentation.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .picklyCardSurface(
                cornerRadius: 20,
                fill: ResultSurface.card,
                stroke: PicklyColor.primary.opacity(0.14)
            )
        }
    }
}

struct IngredientsSection: View {
    let ingredients: [IngredientAnalysis]

    private var explainedIngredients: [IngredientAnalysis] {
        ingredients.filter { $0.status != .unknown }
    }

    private var limitedIngredients: [IngredientAnalysis] {
        ingredients.filter { $0.status == .unknown }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "What's inside", systemImage: "list.bullet.rectangle")

            if ingredients.isEmpty {
                Text("Ingredients not available yet.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .picklyCardSurface(cornerRadius: 18, fill: ResultSurface.card)
            } else {
                VStack(spacing: 12) {
                    ForEach(explainedIngredients) { ingredient in
                        IngredientCard(ingredient: ingredient)
                    }

                    if !limitedIngredients.isEmpty {
                        LimitedIngredientsDisclosure(ingredients: limitedIngredients)
                    }
                }
            }
        }
    }
}

private struct LimitedIngredientsDisclosure: View {
    let ingredients: [IngredientAnalysis]

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                    .padding(.vertical, 12)

                ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    Text(ingredient.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)

                    if index < ingredients.count - 1 {
                        Divider()
                    }
                }

                Text("Detailed information isn't available for these ingredients yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("Other ingredients")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("\(ingredients.count) neutral \(ingredients.count == 1 ? "item" : "items")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(PicklyColor.primary)
        .padding(16)
        .picklyCardSurface(
            cornerRadius: 20,
            fill: ResultSurface.card,
            stroke: PicklyColor.stroke.opacity(0.5)
        )
    }
}

struct IngredientCard: View {
    let ingredient: IngredientAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(ingredient.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(ingredient.badge)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ingredient.status.foregroundColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ingredient.status.softColor, in: Capsule())
            }

            Text(ingredient.explanation)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .picklyCardSurface(
            cornerRadius: 20,
            fill: ResultSurface.card,
            stroke: ingredient.status.borderColor.opacity(0.34)
        )
    }
}

struct DataConfidenceCard: View {
    let onScanAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PicklyIconImage(systemName: "info.circle", size: 21)
                    .foregroundStyle(PicklyColor.statusWarningAccent)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Limited product data")
                        .font(.title3.weight(.bold))

                    Text("We don't have enough nutrition or ingredient data to score this product confidently.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button("Scan again", action: onScanAgain)
                    .buttonStyle(.borderedProminent)
                    .tint(PicklyColor.primary)
                    .picklyProminentButtonForeground()
            }
            .controlSize(.large)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(
            cornerRadius: 20,
            fill: ResultSurface.card,
            stroke: PicklyColor.statusWarningAccent.opacity(0.24)
        )
    }
}

struct NutritionSummary: View {
    let product: Product

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    private var keyFacts: [NutritionFact] {
        product.nutritionFacts.filter(\.isKeyFact)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(reduceMotion ? .easeOut(duration: 0.01) : .spring(duration: 0.38, bounce: 0.14)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionTitle(title: "Nutrition facts", systemImage: "chart.bar.doc.horizontal")
                    Spacer()
                    PicklyIconImage(systemName: "chevron.down", size: 15)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapses nutrition facts." : "Expands nutrition facts.")

            VStack(spacing: 12) {
                ForEach(keyFacts) { fact in
                    NutritionFactRow(fact: fact)
                }

                if isExpanded {
                    NutritionFactsExpanded(facts: product.nutritionFacts.filter { !$0.isKeyFact })
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .picklyCardSurface(cornerRadius: 20, fill: ResultSurface.card)
        }
    }
}

struct NutritionFactsExpanded: View {
    let facts: [NutritionFact]

    var body: some View {
        VStack(spacing: 12) {
            Divider()

            ForEach(facts) { fact in
                NutritionFactRow(fact: fact)
            }
        }
    }
}

private struct NutritionFactRow: View {
    let fact: NutritionFact

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(fact.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(fact.value)
                        .font(.body.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let percent = fact.percent {
                        Text("\(percent)%")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if fact.percent != nil {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.secondary.opacity(0.12))

                        Capsule()
                            .fill(fact.status.color.opacity(0.42))
                            .frame(width: max(6, proxy.size.width * fact.progress))
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

struct RecommendationsCard: View {
    let recommendations: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Better choice next time", systemImage: "arrow.up.forward.circle")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(recommendations, id: \.self) { recommendation in
                    Label(recommendation, picklyIcon: "checkmark.circle", iconSize: 16)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .labelStyle(.titleAndIcon)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .picklyCardSurface(
                cornerRadius: 20,
                fill: ResultSurface.card,
                stroke: PicklyColor.primary.opacity(0.18)
            )
        }
    }
}

enum AlternativePreviewBuilder {
    static func products(
        for currentProduct: Product,
        alternatives: [Product],
        catalog: [Product],
        limit: Int = 30
    ) -> [Product] {
        RelatedProductRanker.products(
            for: currentProduct,
            explicitAlternatives: alternatives,
            catalog: catalog,
            limit: limit
        )
    }
}

struct AlternativesResultSection: View {
    let product: Product
    let alternatives: [Product]
    let previewProducts: [Product]
    let savedStore: SavedProductsStore
    let isPlus: Bool
    let onUpgrade: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showComparison = false

    private var isSampleProduct: Bool {
        product.isSampleData
    }

    private var availableAlternatives: [Product] {
        previewProducts.isEmpty ? alternatives : previewProducts
    }

    private var lockedPreviewProducts: [Product] {
        Array(availableAlternatives.prefix(30))
    }

    private var carouselCount: Int { dynamicTypeSize.isAccessibilitySize ? 1 : 5 }
    private var carouselSpan: Int { dynamicTypeSize.isAccessibilitySize ? 1 : 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader

            if isPlus {
                unlockedContent
            } else {
                lockedContent
            }
        }
        .sheet(isPresented: $showComparison) {
            AlternativeComparisonView(
                product: product,
                alternatives: availableAlternatives
            )
        }
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                SectionTitle(title: "Similar products", systemImage: "arrow.triangle.branch")

                Spacer(minLength: 8)

                if !isPlus {
                    PicklyPlusBadge()
                }
            }

            Text(
                isPlus
                    ? "Similar products first, followed by the closest catalog matches."
                    : "Related to this product. Swipe the preview and tap to unlock."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var unlockedContent: some View {
        if availableAlternatives.isEmpty {
            Text(
                isSampleProduct
                    ? "No similar products are available in this sample set yet."
                    : "No similar products are available yet."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .picklyCardSurface(cornerRadius: 20, fill: ResultSurface.card)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(availableAlternatives.prefix(30)) { alternative in
                            NavigationLink(value: alternative) {
                                ProductSliderCard(
                                    product: alternative,
                                    reason: alternative.positives.first,
                                    reasonIcon: "arrow.left.arrow.right",
                                    isSaved: savedStore.isSaved(alternative)
                                )
                            }
                            .buttonStyle(PicklyPressableButtonStyle())
                            .containerRelativeFrame(
                                .horizontal,
                                count: carouselCount,
                                span: carouselSpan,
                                spacing: 12
                            )
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)

                if availableAlternatives.count > 1 {
                    Button {
                        showComparison = true
                    } label: {
                        HStack(spacing: 10) {
                            PicklyIconImage(systemName: "rectangle.split.3x1", size: 16)

                            Text("Compare up to 3 alternatives")
                                .font(.body.weight(.semibold))

                            Spacer(minLength: 8)

                            PicklyIconImage(systemName: "chevron.right", size: 12)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(PicklyColor.primary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .picklyCardSurface(
                            cornerRadius: 18,
                            fill: PicklyColor.mint.opacity(0.7),
                            stroke: PicklyColor.primary.opacity(0.18)
                        )
                    }
                    .buttonStyle(PicklyPressableButtonStyle())
                    .accessibilityHint("Opens a side-by-side comparison.")
                }
            }
        }
    }

    private var lockedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            LockedProductCarousel(
                products: lockedPreviewProducts,
                reasonProvider: { product in
                    product.positives.first ?? "Similar product"
                },
                accessibilityItemName: "similar product",
                onUpgrade: onUpgrade
            )

            Button(action: onUpgrade) {
                Label("Reveal similar products", picklyIcon: "lock.shield.fill", iconSize: 18)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ResultPrimaryButtonStyle(tint: PicklyColor.primary))
            .accessibilityHint("Opens Pickly Plus subscription options.")
        }
    }
}

private struct AlternativeComparisonView: View {
    let product: Product
    let alternatives: [Product]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ComparisonProductColumn(product: product, isCurrent: true)

                    ForEach(alternatives.prefix(3)) { alternative in
                        ComparisonProductColumn(product: alternative, isCurrent: false)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(PicklyColor.background)
            .navigationTitle("Compare products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ComparisonProductColumn: View {
    let product: Product
    let isCurrent: Bool

    private var scoreText: String {
        product.score.map(String.init) ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ProductThumbnailView(product: product, size: 82)

            VStack(alignment: .leading, spacing: 4) {
                Text(isCurrent ? "Current product" : "Alternative")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isCurrent ? .secondary : PicklyColor.primary)

                Text(product.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(3)

                Text(product.brand)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ComparisonMetricRow(title: "Score", value: scoreText)
            ComparisonMetricRow(title: product.sugarLabel.capitalized, value: format(product.sugarForScoring, suffix: "g"))
            ComparisonMetricRow(title: "Salt", value: format(product.nutrition.salt100g, suffix: "g"))
            ComparisonMetricRow(title: "Sat. fat", value: format(product.nutrition.saturatedFat100g, suffix: "g"))
            ComparisonMetricRow(title: "Protein", value: format(product.nutrition.proteins100g, suffix: "g"))
            ComparisonMetricRow(title: "Fiber", value: format(product.nutrition.fiber100g, suffix: "g"))
        }
        .padding(16)
        .frame(width: 220, alignment: .leading)
        .picklyCardSurface(
            cornerRadius: 22,
            fill: isCurrent ? PicklyColor.card : PicklyColor.mint.opacity(0.74),
            stroke: isCurrent ? PicklyColor.stroke : PicklyColor.primary.opacity(0.2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(isCurrent ? "Current product" : "Alternative"): \(product.name), score \(scoreText), "
                + "\(product.sugarLabel) \(format(product.sugarForScoring, suffix: "g")), "
                + "salt \(format(product.nutrition.salt100g, suffix: "g")), "
                + "saturated fat \(format(product.nutrition.saturatedFat100g, suffix: "g")), "
                + "protein \(format(product.nutrition.proteins100g, suffix: "g")), "
                + "fiber \(format(product.nutrition.fiber100g, suffix: "g"))"
        )
    }

    private func format(_ value: Double?, suffix: String) -> String {
        guard let value else {
            return "—"
        }

        return "\(value.formatted(.number.precision(.fractionLength(1))))\(suffix)"
    }
}

private extension ForYouSection {
    static func presentation(for note: String) -> (icon: String, color: Color) {
        let normalized = note.lowercased()
        let isWarning = normalized.contains("may not")
            || normalized.contains("not confirmed")
            || normalized.contains("might prefer")
            || normalized.contains("watch-out")

        return isWarning
            ? ("exclamationmark.circle", PicklyColor.statusWarningAccent)
            : ("checkmark.circle", .primary)
    }
}

private struct ComparisonMetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
    }
}

struct ProductSliderCard: View {
    let product: Product
    let reason: String?
    let reasonIcon: String
    let isSaved: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AlternativeProductArtwork(
                product: product,
                height: dynamicTypeSize.isAccessibilitySize ? 180 : 144,
                isLocked: false
            )
            .overlay(alignment: .topTrailing) {
                ScorePill(product: product)
                    .padding(10)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(product.brand)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)

                if let reason {
                    Label(reason, picklyIcon: reasonIcon, iconSize: 13)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PicklyColor.primary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if isSaved {
                Label("Saved", picklyIcon: "bookmark.fill", iconSize: 14)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PicklyColor.primary)
            }
        }
        .padding(10)
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? 300 : 260,
            alignment: .topLeading
        )
        .picklyCardSurface(cornerRadius: 20, fill: ResultSurface.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        var parts = [product.name, product.brand, product.verdict]
        if let score = product.score {
            parts.append("Score \(score) out of 100")
        }
        if let reason {
            parts.append(reason)
        }
        if isSaved {
            parts.append("Saved")
        }
        return parts.joined(separator: ", ")
    }
}

private struct AlternativeProductArtwork: View {
    let product: Product
    let height: CGFloat
    let isLocked: Bool

    var body: some View {
        GeometryReader { proxy in
            ProductThumbnailView(
                product: product,
                size: max(proxy.size.width, height),
                contentMode: .fill,
                cornerRadius: 0
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(isLocked ? 1.025 : 1)
            .blur(radius: isLocked ? 0.7 : 0)
            .overlay {
                if isLocked {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PicklyColor.stroke.opacity(0.52), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

struct ResultActions: View {
    let isSaved: Bool
    let saveBounce: Bool
    let onScanAnotherProduct: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onScanAnotherProduct) {
                Label("Scan another product", picklyIcon: "barcode.viewfinder", iconSize: 18)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ResultPrimaryButtonStyle(tint: PicklyColor.primary))

            saveButton
        }
        .controlSize(.large)
    }

    private var saveButton: some View {
        Button(action: onSave) {
            Label(
                isSaved ? "Saved" : "Save result",
                picklyIcon: isSaved ? "bookmark.fill" : "bookmark",
                iconSize: 18
            )
                .frame(maxWidth: .infinity)
                .scaleEffect(saveBounce ? 1.04 : 1)
        }
        .buttonStyle(ResultSecondaryButtonStyle())
    }

}

struct StickyResultHeader: View {
    let product: Product
    let isSaved: Bool
    let saveBounce: Bool
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnailView(product: product, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(product.resultDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(product.resultVerdict)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let score = product.score, !product.isLimitedData {
                Text("\(score)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(product.resultScoreForegroundColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(product.resultScoreFillColor, in: Capsule())
            } else {
                Text("Limited")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PicklyColor.statusUnknownForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(PicklyColor.statusUnknownFill, in: Capsule())
            }

            Button(action: onSave) {
                PicklyIconImage(
                    systemName: isSaved ? "bookmark.fill" : "bookmark",
                    size: 20
                )
                    .foregroundStyle(isSaved ? PicklyColor.primary : .primary)
                    .frame(width: 38, height: 38)
                    .scaleEffect(saveBounce ? 1.18 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "Saved" : "Save result")
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .picklyCardShadow()
    }
}

struct SectionTitle: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, picklyIcon: systemImage)
            .font(.title3.weight(.bold))
            .foregroundStyle(.primary)
    }
}

struct ResultPrimaryButtonStyle: ButtonStyle {
    let tint: Color
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(PicklyColor.onBrandAccent)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, ResultActionButtonMetrics.horizontalPadding)
            .frame(maxWidth: .infinity, minHeight: minimumHeight)
            .background(tint, in: ResultActionButtonMetrics.shape)
            .contentShape(ResultActionButtonMetrics.shape)
            .scaleEffect(configuration.isPressed ? ResultActionButtonMetrics.pressedScale : 1)
            .opacity(configuration.isPressed ? ResultActionButtonMetrics.pressedOpacity : 1)
            .animation(ResultActionButtonMetrics.pressAnimation, value: configuration.isPressed)
    }

    private var minimumHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? ResultActionButtonMetrics.accessibilityHeight
            : ResultActionButtonMetrics.height
    }
}

struct ResultSecondaryButtonStyle: ButtonStyle {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, ResultActionButtonMetrics.horizontalPadding)
            .frame(maxWidth: .infinity, minHeight: minimumHeight)
            .background(ResultSurface.card, in: ResultActionButtonMetrics.shape)
            .overlay {
                ResultActionButtonMetrics.shape
                    .stroke(ResultSurface.stroke, lineWidth: 1)
            }
            .contentShape(ResultActionButtonMetrics.shape)
            .scaleEffect(configuration.isPressed ? ResultActionButtonMetrics.pressedScale : 1)
            .opacity(configuration.isPressed ? ResultActionButtonMetrics.pressedOpacity : 1)
            .animation(ResultActionButtonMetrics.pressAnimation, value: configuration.isPressed)
    }

    private var minimumHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? ResultActionButtonMetrics.accessibilityHeight
            : ResultActionButtonMetrics.height
    }
}

private enum ResultActionButtonMetrics {
    static let height: CGFloat = 56
    static let accessibilityHeight: CGFloat = 68
    static let horizontalPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 18
    static let pressedScale: CGFloat = 0.98
    static let pressedOpacity: CGFloat = 0.92
    static let pressAnimation = Animation.easeOut(duration: 0.14)

    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}
