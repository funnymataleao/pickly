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
            SectionTitle(title: PicklyCopy.localized("Why this score?"), systemImage: "sparkle.magnifyingglass")

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
        Array(warnings.filter(Self.isConcreteConcern).prefix(3))
    }

    var body: some View {
        if !visibleWarnings.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: PicklyCopy.localized("Things to consider"), systemImage: "exclamationmark.circle")

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(visibleWarnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 10) {
                            PicklyIconImage(systemName: "exclamationmark.circle", size: 17)
                                .foregroundStyle(PicklyColor.statusWarningAccent)
                                .frame(width: 22, height: 22)

                            Text(warning)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
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

    nonisolated private static func isConcreteConcern(_ warning: String) -> Bool {
        let normalized = warning.lowercased()
        let dataQualityPhrases = [
            "no major watch-outs",
            "not available",
            "incomplete",
            "lowers confidence",
            "confidence is lower"
        ]

        return !dataQualityPhrases.contains { normalized.contains($0) }
    }
}

struct ForYouSection: View {
    let notes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: PicklyCopy.localized("For you"), systemImage: "person.crop.circle")

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

struct ProductFactsOverview: View {
    let facts: [ProductQuickFact]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: PicklyCopy.localized("At a glance"), systemImage: "text.magnifyingglass")

            VStack(spacing: 0) {
                ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        PicklyIconImage(systemName: fact.systemImage, size: 17)
                            .foregroundStyle(PicklyColor.primary)
                            .frame(width: 24)

                        Text(fact.title)
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 12)

                        Text(fact.value)
                            .font(.body.weight(.semibold).monospacedDigit())
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 12)
                    .accessibilityElement(children: .combine)

                    if index < facts.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .picklyCardSurface(cornerRadius: 20, fill: ResultSurface.card)
        }
    }
}

struct IngredientSafetySection: View {
    let facts: Product.Facts

    private var allergens: [String] {
        facts.allergens.map { ProductFactFormatter.displayName(for: $0) }
    }

    private var traces: [String] {
        facts.traces.map { ProductFactFormatter.displayName(for: $0) }
    }

    private var additives: [String] {
        facts.additives.map { ProductFactFormatter.displayName(for: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(
                title: PicklyCopy.localized("Allergens & additives"),
                systemImage: "checklist"
            )

            VStack(alignment: .leading, spacing: 14) {
                if !allergens.isEmpty {
                    SafetyFactRow(
                        title: PicklyCopy.localized("Contains"),
                        values: allergens,
                        systemImage: "exclamationmark.circle"
                    )
                }

                if !traces.isEmpty {
                    SafetyFactRow(
                        title: PicklyCopy.localized("May contain"),
                        values: traces,
                        systemImage: "info.circle"
                    )
                }

                if !additives.isEmpty {
                    AdditivesDisclosure(additives: additives)
                }

                if !allergens.isEmpty || !traces.isEmpty {
                    Text(PicklyCopy.localized("Always check the package. Community data may be incomplete."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .picklyCardSurface(cornerRadius: 20, fill: ResultSurface.card)
        }
    }
}

private struct SafetyFactRow: View {
    let title: String
    let values: [String]
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PicklyIconImage(systemName: systemImage, size: 18)
                .foregroundStyle(PicklyColor.statusWarningAccent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(values.joined(separator: ", "))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AdditivesDisclosure: View {
    let additives: [String]

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(additives.joined(separator: ", "))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        } label: {
            Label {
                Text(PicklyCopy.format("Additives: %d", locale: PicklyCopy.appLocale, additives.count))
                    .font(.body.weight(.semibold))
            } icon: {
                PicklyIconImage(systemName: "testtube.2", size: 18)
                    .foregroundStyle(PicklyColor.primary)
            }
        }
        .tint(PicklyColor.primary)
    }
}

struct ProductDataSourceCard: View {
    let product: Product

    private var resolvedSource: ProductSource {
        product.facts.source == .unknown ? product.source : product.facts.source
    }

    private var sourceTitle: String {
        switch resolvedSource {
        case .openFoodFacts:
            return "Open Food Facts"
        case .mock:
            return PicklyCopy.localized("Sample data")
        case .unknown:
            return PicklyCopy.localized("Pickly catalog")
        }
    }

    private var sourceURL: URL? {
        guard resolvedSource == .openFoodFacts else { return nil }
        return URL(string: "https://world.openfoodfacts.org/product/\(product.barcode)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: PicklyCopy.localized("Data source"), systemImage: "doc.text.magnifyingglass")

            VStack(alignment: .leading, spacing: 12) {
                Label(sourceTitle, picklyIcon: "globe.europe.africa", iconSize: 18)
                    .font(.body.weight(.semibold))

                if let completeness = product.facts.completeness,
                   (0...1).contains(completeness) {
                    Text(PicklyCopy.format(
                        "Source record completeness: %d%%",
                        locale: PicklyCopy.appLocale,
                        Int((completeness * 100).rounded())
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if let date = product.facts.lastUpdatedAt {
                    Text(PicklyCopy.format(
                        "Source updated: %@",
                        locale: PicklyCopy.appLocale,
                        date.formatted(
                            .dateTime
                                .year()
                                .month(.abbreviated)
                                .day()
                                .locale(PicklyCopy.appLocale)
                        )
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                if let sourceURL {
                    Link(destination: sourceURL) {
                        Label {
                            Text(PicklyCopy.localized("View source record"))
                        } icon: {
                            PicklyIconImage(systemName: "arrow.up.right", size: 14)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }

                Text(PicklyCopy.localized("Product data can change. Check the package when a detail matters to you."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .picklyCardSurface(cornerRadius: 20, fill: ResultSurface.card)
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
            SectionTitle(title: PicklyCopy.localized("What's inside"), systemImage: "list.bullet.rectangle")

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
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                PicklyIconImage(systemName: "info.circle", size: 21)
                    .foregroundStyle(PicklyColor.statusWarningAccent)

                VStack(alignment: .leading, spacing: 5) {
                            Text("Some details are missing")
                        .font(.title3.weight(.bold))

                            Text("Pickly can only assess the details available for this product. Try another item if you need a more complete comparison.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
                    SectionTitle(title: PicklyCopy.localized("Nutrition facts"), systemImage: "chart.bar.doc.horizontal")
                    Spacer()
                    PicklyIconImage(systemName: "chevron.down", size: 15)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Collapses nutrition facts." : "Expands nutrition facts.")

            Text(product.nutritionBasisLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
            SectionTitle(title: PicklyCopy.localized("What to look for"), systemImage: "arrow.up.forward.circle")

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

nonisolated enum AlternativePreviewBuilder {
    static func selection(
        for currentProduct: Product,
        alternatives: [Product],
        catalog: [Product],
        limit: Int = 100
    ) -> AlternativeShelfSelection {
        guard limit > 0 else {
            return AlternativeShelfSelection(kind: .similar, products: [])
        }

        let rankedProducts = RelatedProductRanker.products(
            for: currentProduct,
            explicitAlternatives: alternatives,
            catalog: catalog,
            limit: max(limit, catalog.count + alternatives.count)
        )
        let comparableProducts = deduplicatedProducts(
            rankedProducts.filter {
                !$0.isLimitedData
                    && !ProductIdentity.isSame($0, as: currentProduct)
                    && ProductSimilarity.isComparable($0, to: currentProduct)
            }
        )
        // Better Choices is a paid trust surface. A candidate can tie the
        // current rating when its nutrition profile offers a useful trade-off,
        // but a lower-rated product must never appear in this section.
        let eligibleProducts = comparableProducts.filter {
            isEligible($0, for: currentProduct)
        }
        let rankedBetterChoices = eligibleProducts.enumerated().sorted { lhs, rhs in
            let lhsIsBetter = AlternativeBenefitBuilder.isBetter(lhs.element, than: currentProduct)
            let rhsIsBetter = AlternativeBenefitBuilder.isBetter(rhs.element, than: currentProduct)
            if lhsIsBetter != rhsIsBetter {
                return lhsIsBetter
            }

            let lhsScore = lhs.element.score ?? Int.min
            let rhsScore = rhs.element.score ?? Int.min
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }

            return lhs.offset < rhs.offset
        }.map(\.element)

        return AlternativeShelfSelection(
            kind: .similar,
            products: Array(rankedBetterChoices.prefix(limit))
        )
    }

    static func products(
        for currentProduct: Product,
        alternatives: [Product],
        catalog: [Product],
        limit: Int = 100
    ) -> [Product] {
        guard limit > 0 else {
            return []
        }

        let rankedProducts = RelatedProductRanker.products(
            for: currentProduct,
            explicitAlternatives: alternatives,
            catalog: catalog,
            limit: max(limit, catalog.count + alternatives.count)
        )

        let eligibleProducts = rankedProducts.filter {
            !ProductIdentity.isSame($0, as: currentProduct)
                && ProductSimilarity.isComparable($0, to: currentProduct)
                && !$0.isLimitedData
                && isEligible($0, for: currentProduct)
        }

        return Array(deduplicatedProducts(eligibleProducts).prefix(limit))
    }

    static func isEligible(_ candidate: Product, for currentProduct: Product) -> Bool {
        guard let candidateScore = candidate.score,
              let currentScore = currentProduct.score else {
            return false
        }

        return candidateScore >= currentScore
    }

    private static func deduplicatedProducts(_ products: [Product]) -> [Product] {
        var seen = Set<String>()
        return products.filter { seen.insert(ProductIdentity.key(for: $0)).inserted }
    }
}

nonisolated enum AlternativeShelfKind: Equatable, Sendable {
    case similar
}

nonisolated struct AlternativeShelfSelection: Sendable {
    let kind: AlternativeShelfKind
    let products: [Product]
}

nonisolated enum AlternativeBenefitBuilder {
    static func isBetter(_ candidate: Product, than current: Product) -> Bool {
        guard !candidate.isLimitedData,
              let candidateScore = candidate.score,
              let currentScore = current.score else {
            return false
        }

        // This helper marks a strict improvement for ordering and copy. Shelf
        // eligibility is handled separately so equal-rated nutrition trade-offs
        // can remain visible while lower-rated products stay excluded.
        guard candidateScore >= max(currentScore, 50) else { return false }
        return candidateScore > currentScore
    }

    static func reason(for candidate: Product, comparedTo current: Product) -> String {
        if let comparativeReason = comparativeReason(for: candidate, comparedTo: current) {
            return comparativeReason
        }

        if let candidateScore = candidate.score,
           let currentScore = current.score,
           candidateScore > currentScore {
            return PicklyCopy.format("Pickly score +%@", String(candidateScore - currentScore))
        }

        return candidate.positives.first
            ?? PicklyCopy.localized("Better choice")
    }

    private static func comparativeReason(for candidate: Product, comparedTo current: Product) -> String? {
        if isMeaningfullyLower(candidate.sugarForScoring, than: current.sugarForScoring, minimumDifference: 0.4) {
            return PicklyCopy.localized("Less sugar")
        }
        if isMeaningfullyLower(candidate.nutrition.salt100g, than: current.nutrition.salt100g, minimumDifference: 0.05) {
            return PicklyCopy.localized("Lower sodium")
        }
        if isMeaningfullyLower(candidate.nutrition.saturatedFat100g, than: current.nutrition.saturatedFat100g, minimumDifference: 0.3) {
            return PicklyCopy.localized("Less saturated fat")
        }
        if isMeaningfullyHigher(candidate.nutrition.proteins100g, than: current.nutrition.proteins100g, minimumDifference: 1) {
            return PicklyCopy.localized("Higher protein")
        }
        if isMeaningfullyHigher(candidate.nutrition.fiber100g, than: current.nutrition.fiber100g, minimumDifference: 1) {
            return PicklyCopy.localized("More fiber")
        }
        return nil
    }

    private static func isMeaningfullyLower(
        _ candidate: Double?,
        than current: Double?,
        minimumDifference: Double
    ) -> Bool {
        guard let candidate, let current else { return false }
        return current - candidate >= minimumDifference
    }

    private static func isMeaningfullyHigher(
        _ candidate: Double?,
        than current: Double?,
        minimumDifference: Double
    ) -> Bool {
        guard let candidate, let current else { return false }
        return candidate - current >= minimumDifference
    }
}

struct AlternativesResultSection: View {
    let product: Product
    let selection: AlternativeShelfSelection
    let productService: any ProductService
    let savedStore: SavedProductsStore
    let preferences: UserPreferences
    let onScanAnotherProduct: (() -> Void)?
    let isPlus: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onUpgrade: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let carouselPreviewLimit = 12

    private var availableAlternatives: [Product] {
        selection.products.filter {
            AlternativePreviewBuilder.isEligible($0, for: product)
        }
    }

    private var lockedPreviewProducts: [Product] {
        Array(availableAlternatives.prefix(carouselPreviewLimit))
    }

    private var contentState: PicklyPlusContentState {
        PicklyPlusContentGate.state(
            isPlus: isPlus,
            hasContent: !availableAlternatives.isEmpty
        )
    }

    private var carouselCount: Int { dynamicTypeSize.isAccessibilitySize ? 1 : 5 }
    private var carouselSpan: Int { dynamicTypeSize.isAccessibilitySize ? 1 : 4 }

    @ViewBuilder
    var body: some View {
        VStack(alignment: .leading, spacing: PicklyLayout.screenHorizontalPadding) {
            sectionHeader

            if isLoading && availableAlternatives.isEmpty {
                AlternativeCarouselSkeleton()
            } else {
                switch contentState {
                case .unavailable:
                    unavailableContent
                case .unlocked:
                    unlockedContent
                case .locked:
                    lockedContent
                }
            }
        }
        // Give the section its own breathing room after the insight cards while
        // keeping the header and its related carousel visually grouped.
        .padding(.top, 12)
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                SectionTitle(title: sectionTitle, systemImage: "sparkles")

                Spacer(minLength: 8)

                PicklyPlusBadge()
            }

            Text(sectionSubtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sectionSubtitle: String {
        switch contentState {
        case .unavailable:
            if errorMessage != nil {
                return PicklyCopy.localized("Better Choices couldn't be refreshed right now.")
            }
            return isLoading
                ? PicklyCopy.localized("Finding verified products from the same category…")
                : PicklyCopy.localized("Pickly Plus checks for verified products from the same category.")
        case .locked:
            return PicklyCopy.localized("Relevant products from the same category.")
        case .unlocked:
            return PicklyCopy.localized("Relevant products from the same category.")
        }
    }

    private var sectionTitle: String {
        PicklyCopy.localized("Better Choices")
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PicklyIconImage(systemName: "magnifyingglass", size: 18)
                    .foregroundStyle(PicklyColor.primary)
                    .frame(width: 36, height: 36)
                    .background(PicklyColor.primary.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(errorMessage == nil ? PicklyCopy.localized("No verified matches yet") : PicklyCopy.localized("Catalog unavailable"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(unavailableMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: onRetry) {
                Label(PicklyCopy.localized("Try again"), picklyIcon: "arrow.clockwise", iconSize: 16)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ResultSecondaryButtonStyle())
            .accessibilityHint("Searches the catalog for higher-scoring products again.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(
            cornerRadius: 20,
            fill: ResultSurface.card,
            stroke: PicklyColor.primary.opacity(0.18)
        )
    }

    private var unavailableMessage: String {
        if let errorMessage {
            return errorMessage
        }
        if isPlus {
            return PicklyCopy.localized("We couldn't find another verified product in the same category. Your Plus access is active — try the catalog again.")
        }

        return PicklyCopy.localized("We couldn't find another verified product in the same category. Try the catalog again.")
    }

    private var unlockedContent: some View {
        VStack(alignment: .leading, spacing: PicklyLayout.screenHorizontalPadding) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(availableAlternatives.prefix(carouselPreviewLimit)) { alternative in
                        NavigationLink {
                            ProductResultView(
                                product: alternative,
                                productService: productService,
                                savedStore: savedStore,
                                preferences: preferences,
                                onScanAnotherProduct: onScanAnotherProduct
                            )
                        } label: {
                            ProductSliderCard(
                                product: alternative,
                                reason: AlternativeBenefitBuilder.reason(
                                    for: alternative,
                                    comparedTo: product
                                ),
                                reasonIcon: "arrow.left.arrow.right",
                                isSaved: savedStore.isSaved(alternative)
                            )
                        }
                        .buttonStyle(PicklyPressableButtonStyle())
                        .contentShape(Rectangle())
                        .accessibilityHint("Opens this product.")
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
            .contentMargins(.horizontal, PicklyLayout.screenHorizontalPadding, for: .scrollContent)
            .contentMargins(.horizontal, 0, for: .scrollIndicators)
            .padding(.horizontal, -PicklyLayout.screenHorizontalPadding)
            .scrollClipDisabled(true)

            if availableAlternatives.count > 1 {
                NavigationLink {
                    SimilarProductsView(
                        product: product,
                        selection: selection,
                        productService: productService,
                        savedStore: savedStore,
                        preferences: preferences,
                        onScanAnotherProduct: onScanAnotherProduct
                    )
                } label: {
                    HStack(spacing: 12) {
                        PicklyIconImage(systemName: "list.bullet.rectangle", size: 18)
                            .foregroundStyle(PicklyColor.primary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(seeAllTitle)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)

                    Text("Ranked by score and nutrition")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        PicklyIconImage(systemName: "chevron.right", size: 12)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .picklyCardSurface(
                        cornerRadius: 18,
                        fill: ResultSurface.card,
                        stroke: PicklyColor.primary.opacity(0.18)
                    )
                }
                .buttonStyle(PicklyPressableButtonStyle())
                .accessibilityHint("Opens the ranked product list.")
            }
        }
    }

    private var lockedContent: some View {
        VStack(alignment: .leading, spacing: PicklyLayout.screenHorizontalPadding) {
            LockedProductCarousel(
                products: lockedPreviewProducts,
                reasonProvider: { product in
                    AlternativeBenefitBuilder.reason(
                        for: product,
                        comparedTo: self.product
                    )
                },
                accessibilityItemName: "better choice",
                onUpgrade: onUpgrade
            )

            Button(action: onUpgrade) {
                Label(
                    unlockTitle,
                    picklyIcon: "lock.shield.fill",
                    iconSize: 18
                )
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ResultPrimaryButtonStyle(tint: PicklyColor.primary))
            .accessibilityHint("Opens Pickly Plus subscription options.")
        }
    }

    private var seeAllTitle: String {
        PicklyCopy.format("See all %@ Better Choices", String(availableAlternatives.count))
    }

    private var unlockTitle: String {
        PicklyCopy.format("Unlock %@ Better Choices", String(availableAlternatives.count))
    }
}

private struct AlternativeCarouselSkeleton: View {
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 12) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.secondary.opacity(0.12))
                            .frame(height: 144)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.secondary.opacity(0.12))
                            .frame(width: 160, height: 16)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.secondary.opacity(0.08))
                            .frame(width: 110, height: 13)
                    }
                    .padding(10)
                    .containerRelativeFrame(.horizontal, count: 5, span: 4, spacing: 12)
                    .picklyCardSurface(cornerRadius: 20, fill: ResultSurface.card)
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, PicklyLayout.screenHorizontalPadding, for: .scrollContent)
        .contentMargins(.horizontal, 0, for: .scrollIndicators)
        .padding(.horizontal, -PicklyLayout.screenHorizontalPadding)
        .scrollClipDisabled(true)
        .accessibilityLabel("Finding Better Choices")
    }
}

struct SimilarProductsView: View {
    let product: Product
    let selection: AlternativeShelfSelection
    let productService: any ProductService
    let savedStore: SavedProductsStore
    let preferences: UserPreferences
    let onScanAnotherProduct: (() -> Void)?

    private var title: String {
        "Better Choices"
    }

    private var displayedProducts: [Product] {
        return selection.products
            .filter { AlternativePreviewBuilder.isEligible($0, for: product) }
            .enumerated()
            .sorted { lhs, rhs in
                let leftScore = lhs.element.score ?? Int.min
                let rightScore = rhs.element.score ?? Int.min
                return leftScore == rightScore ? lhs.offset < rhs.offset : leftScore > rightScore
            }
            .map(\.element)
    }

    var body: some View {
        List {
            Section("Compared with") {
                ComparisonReferenceRow(product: product)
                    .listRowBackground(ResultSurface.card)
            }

            Section("Best matches") {
                ForEach(displayedProducts) { alternative in
                    NavigationLink {
                        ProductComparisonView(
                            currentProduct: product,
                            alternative: alternative,
                            productService: productService,
                            savedStore: savedStore,
                            preferences: preferences,
                            onScanAnotherProduct: onScanAnotherProduct
                        )
                    } label: {
                        BetterChoiceListRow(
                            product: alternative,
                            reason: AlternativeBenefitBuilder.reason(
                                for: alternative,
                                comparedTo: product
                            ),
                            isSaved: savedStore.isSaved(alternative)
                        )
                    }
                    .listRowBackground(ResultSurface.card)
                    .accessibilityHint("Compares this product with the current product.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(PicklyColor.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ComparisonReferenceRow: View {
    let product: Product

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnailView(product: product, size: 60, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

                Text(product.brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 10) {
                ScorePill(product: product)

                PicklyIconImage(systemName: "chevron.right", size: 12)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PicklyCopy.format(
                "Current product, %@, %@, %@",
                product.name,
                product.brand,
                product.localizedVerdict
            )
        )
    }
}

private struct BetterChoiceListRow: View {
    let product: Product
    let reason: String
    let isSaved: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ProductThumbnailView(product: product, size: 60, cornerRadius: 14)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(product.brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    PicklyIconImage(systemName: "arrow.left.arrow.right", size: 14)

                    Text(ProductCardCopy.shortReason(reason))
                        .font(.footnote.weight(.semibold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(PicklyColor.primary)
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                if isSaved {
                    PicklyIconImage(systemName: "bookmark.fill", size: 12)
                        .foregroundStyle(.secondary)
                }

                ScorePill(product: product)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [product.name, product.brand, product.localizedVerdict, reason]
        if let score = product.score {
            parts.append(PicklyCopy.format("Score %@ out of 100", String(score)))
        }
        if isSaved {
            parts.append(PicklyCopy.localized("Saved"))
        }
        return parts.joined(separator: ", ")
    }
}

private struct ProductComparisonView: View {
    let currentProduct: Product
    let alternative: Product
    let productService: any ProductService
    let savedStore: SavedProductsStore
    let preferences: UserPreferences
    let onScanAnotherProduct: (() -> Void)?

    @State private var showsUnchangedMetrics = false

    private var metrics: [ComparisonMetric] {
        ComparisonMetric.metrics(current: currentProduct, alternative: alternative)
    }

    private var differingMetrics: [ComparisonMetric] {
        metrics.filter { !$0.isUnchanged }
    }

    private var unchangedMetrics: [ComparisonMetric] {
        metrics.filter(\.isUnchanged)
    }

    private var visibleMetrics: [ComparisonMetric] {
        if differingMetrics.isEmpty || showsUnchangedMetrics {
            return metrics
        }
        return differingMetrics
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: PicklyLayout.screenHorizontalPadding) {
                ComparisonProductHeader(
                    product: currentProduct,
                    label: PicklyCopy.localized("Current product"),
                    isSelected: false
                )

                ComparisonProductHeader(
                    product: alternative,
                    label: AlternativeBenefitBuilder.reason(for: alternative, comparedTo: currentProduct),
                    isSelected: true
                )

                ComparisonSummaryCard(metrics: metrics)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(differingMetrics.isEmpty ? PicklyCopy.localized("Nutrition comparison") : PicklyCopy.localized("Key differences"))
                            .font(.title3.weight(.semibold))

                        Spacer(minLength: 8)

                        Text("per 100 g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ComparisonMetricTable(metrics: visibleMetrics)

                    if !unchangedMetrics.isEmpty, !differingMetrics.isEmpty {
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                showsUnchangedMetrics.toggle()
                            }
                        } label: {
                            Label(
                                showsUnchangedMetrics
                                    ? PicklyCopy.localized("Hide unchanged values")
                                    : PicklyCopy.format("Show %@ unchanged values", String(unchangedMetrics.count)),
                                picklyIcon: showsUnchangedMetrics ? "chevron.up" : "chevron.down",
                                iconSize: 12
                            )
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(PicklyColor.primary)
                        .accessibilityHint("Shows or hides nutrition values that match.")
                    }
                }
                .padding(16)
                .picklyCardSurface(
                    cornerRadius: 22,
                    fill: ResultSurface.card,
                    stroke: PicklyColor.stroke.opacity(0.45)
                )

                NavigationLink {
                    ProductResultView(
                        product: alternative,
                        productService: productService,
                        savedStore: savedStore,
                        preferences: preferences,
                        onScanAnotherProduct: onScanAnotherProduct
                    )
                } label: {
                    Label(PicklyCopy.localized("View product"), picklyIcon: "arrow.right", iconSize: 16)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ResultPrimaryButtonStyle(tint: PicklyColor.primary))
                .accessibilityHint("Opens the selected product details.")
            }
            .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(PicklyColor.background)
        .navigationTitle(PicklyCopy.localized("Compare"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ComparisonProductHeader: View {
    let product: Product
    let label: String
    let isSelected: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ProductThumbnailView(product: product, size: 68, cornerRadius: 17)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? PicklyColor.primary : .secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)

                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(product.brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }

            Spacer(minLength: 8)

            ScorePill(product: product)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(
            cornerRadius: 20,
            fill: ResultSurface.card,
            stroke: isSelected ? PicklyColor.primary.opacity(0.22) : PicklyColor.stroke.opacity(0.45)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PicklyCopy.format(
                "%@: %@, %@, %@",
                label,
                product.name,
                product.brand,
                product.localizedVerdict
            )
        )
    }
}

private struct ComparisonSummaryCard: View {
    let metrics: [ComparisonMetric]

    private var improvement: ComparisonMetric? {
        metrics.first { $0.change == .better }
    }

    private var tradeoff: ComparisonMetric? {
        metrics.first { $0.change == .worse }
    }

    private var title: String {
        improvement?.summaryText ?? PicklyCopy.localized("Similar overall profile")
    }

    private var subtitle: String {
        if let tradeoff {
            return PicklyCopy.format(
                "Trade-off: %@.",
                tradeoff.summaryText.lowercased()
            )
        }
        if improvement != nil {
            return PicklyCopy.localized("No major trade-off is visible in the available values.")
        }
        return PicklyCopy.localized("The available values do not show a clear overall advantage.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, picklyIcon: "arrow.left.arrow.right", iconSize: 18)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(
            cornerRadius: 20,
            fill: PicklyColor.primary.opacity(0.08),
            stroke: PicklyColor.primary.opacity(0.18)
        )
    }
}

private struct ComparisonMetric: Identifiable {
    enum Preference: Equatable {
        case higher
        case lower
    }

    enum Change: Equatable {
        case better
        case worse
        case same
        case unavailable
    }

    let title: String
    let currentValue: Double?
    let alternativeValue: Double?
    let unit: String
    let precision: Int
    let preference: Preference
    let isDirectlyComparable: Bool
    let equalityTolerance: Double

    var id: String { title }

    var change: Change {
        if currentValue == nil, alternativeValue == nil {
            return .same
        }
        guard isDirectlyComparable, let difference else { return .unavailable }
        guard abs(difference) > equalityTolerance else { return .same }

        switch preference {
        case .higher:
            return difference > 0 ? .better : .worse
        case .lower:
            return difference < 0 ? .better : .worse
        }
    }

    var isUnchanged: Bool {
        change == .same
    }

    var currentText: String {
        formatted(currentValue)
    }

    var alternativeText: String {
        formatted(alternativeValue)
    }

    var changeText: String {
        guard isDirectlyComparable else { return PicklyCopy.localized("Different data basis") }
        guard let difference else { return PicklyCopy.localized("Not available") }
        guard abs(difference) > equalityTolerance else { return PicklyCopy.localized("Same") }

        let magnitude = formatted(abs(difference))
        return difference > 0
            ? PicklyCopy.format("%@ higher", magnitude)
            : PicklyCopy.format("%@ lower", magnitude)
    }

    var summaryText: String {
        guard let difference, abs(difference) > equalityTolerance else {
            return PicklyCopy.format("Similar %@", PicklyCopy.localized(title))
        }

        if title == "Pickly score" {
            let points = Int(abs(difference).rounded())
            let unit = PicklyCopy.localized(points == 1 ? "point" : "points")
            return difference > 0
                ? PicklyCopy.format("Pickly score is %@ %@ higher", String(points), unit)
                : PicklyCopy.format("Pickly score is %@ %@ lower", String(points), unit)
        }

        let magnitude = formatted(abs(difference))
        return difference > 0
            ? PicklyCopy.format("%@ is %@ higher", PicklyCopy.localized(title), magnitude)
            : PicklyCopy.format("%@ is %@ lower", PicklyCopy.localized(title), magnitude)
    }

    var symbolName: String {
        switch change {
        case .better:
            return preference == .higher ? "arrow.up.right" : "arrow.down.right"
        case .worse:
            return preference == .higher ? "arrow.down.right" : "arrow.up.right"
        case .same:
            return "equal"
        case .unavailable:
            return "questionmark.circle"
        }
    }

    var changeColor: Color {
        switch change {
        case .better:
            return PicklyColor.primary
        case .worse:
            return PicklyColor.statusWarningAccent
        case .same, .unavailable:
            return .secondary
        }
    }

    private var difference: Double? {
        guard let currentValue, let alternativeValue else { return nil }
        return alternativeValue - currentValue
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "—" }
        let number = value.formatted(
            .number
                .locale(PicklyCopy.appLocale)
                .precision(.fractionLength(precision))
        )
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    static func metrics(current: Product, alternative: Product) -> [ComparisonMetric] {
        let sugarIsComparable = current.sugarLabel == alternative.sugarLabel
        let sugarTitle = sugarIsComparable && current.sugarLabel == "added sugar"
            ? "Added sugar"
            : "Sugar"

        return [
            ComparisonMetric(
                title: "Pickly score",
                currentValue: current.score.map(Double.init),
                alternativeValue: alternative.score.map(Double.init),
                unit: "",
                precision: 0,
                preference: .higher,
                isDirectlyComparable: true,
                equalityTolerance: 0
            ),
            ComparisonMetric(
                title: sugarTitle,
                currentValue: current.sugarForScoring,
                alternativeValue: alternative.sugarForScoring,
                unit: "g",
                precision: 1,
                preference: .lower,
                isDirectlyComparable: sugarIsComparable,
                equalityTolerance: 0.05
            ),
            ComparisonMetric(
                title: "Salt",
                currentValue: current.nutrition.salt100g,
                alternativeValue: alternative.nutrition.salt100g,
                unit: "g",
                precision: 1,
                preference: .lower,
                isDirectlyComparable: true,
                equalityTolerance: 0.05
            ),
            ComparisonMetric(
                title: "Saturated fat",
                currentValue: current.nutrition.saturatedFat100g,
                alternativeValue: alternative.nutrition.saturatedFat100g,
                unit: "g",
                precision: 1,
                preference: .lower,
                isDirectlyComparable: true,
                equalityTolerance: 0.05
            ),
            ComparisonMetric(
                title: "Protein",
                currentValue: current.nutrition.proteins100g,
                alternativeValue: alternative.nutrition.proteins100g,
                unit: "g",
                precision: 1,
                preference: .higher,
                isDirectlyComparable: true,
                equalityTolerance: 0.05
            ),
            ComparisonMetric(
                title: "Fiber",
                currentValue: current.nutrition.fiber100g,
                alternativeValue: alternative.nutrition.fiber100g,
                unit: "g",
                precision: 1,
                preference: .higher,
                isDirectlyComparable: true,
                equalityTolerance: 0.05
            )
        ]
    }
}

private struct ComparisonMetricTable: View {
    let metrics: [ComparisonMetric]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 12) {
                    Text("Metric")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Current")
                        .frame(width: 68, alignment: .trailing)
                    Text("Selected")
                        .frame(width: 72, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 6)
            }

            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                ComparisonMetricPairRow(metric: metric)

                if index < metrics.count - 1 {
                    Divider()
                }
            }
        }
    }
}

private struct ComparisonMetricPairRow: View {
    let metric: ComparisonMetric

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(PicklyCopy.localized(metric.title))
                        .font(.body.weight(.semibold))

                    LabeledContent(PicklyCopy.localized("Current"), value: metric.currentText)
                    LabeledContent(PicklyCopy.localized("Selected"), value: metric.alternativeText)

                    changeLabel
                }
                .font(.body)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(PicklyCopy.localized(metric.title))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(metric.currentText)
                            .frame(width: 68, alignment: .trailing)

                        Text(metric.alternativeText)
                            .frame(width: 72, alignment: .trailing)
                    }
                    .font(.subheadline.weight(.semibold).monospacedDigit())

                    changeLabel
                }
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            PicklyCopy.format(
                "%@, current %@, selected %@, %@",
                PicklyCopy.localized(metric.title),
                metric.currentText,
                metric.alternativeText,
                metric.changeText
            )
        )
    }

    private var changeLabel: some View {
        Label(metric.changeText, picklyIcon: metric.symbolName, iconSize: 11)
            .font(.caption.weight(.semibold))
            .foregroundStyle(metric.changeColor)
            .fixedSize(horizontal: false, vertical: true)
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
                if !dynamicTypeSize.isAccessibilitySize {
                    ScorePill(product: product)
                        .padding(10)
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                ScorePill(product: product)
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
                    Label(
                        ProductCardCopy.shortReason(reason),
                        picklyIcon: ProductCardCopy.icon(for: reason, fallback: reasonIcon),
                        iconSize: 13
                    )
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
        var parts = [product.name, product.brand, product.localizedVerdict]
        if let score = product.score {
            parts.append(PicklyCopy.format("Score %@ out of 100", String(score)))
        }
        if let reason {
            parts.append(ProductCardCopy.shortReason(reason))
        }
        if isSaved {
            parts.append(PicklyCopy.localized("Saved"))
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
        VStack(spacing: PicklyLayout.screenHorizontalPadding) {
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
                picklyIcon: isSaved ? "bookmark.fill" : "bookmark.outline",
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
                    systemName: isSaved ? "bookmark.fill" : "bookmark.outline",
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(PicklyColor.onPrimary(for: colorScheme))
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
