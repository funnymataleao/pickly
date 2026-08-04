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

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: insight.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.foreground)
                .frame(width: 32, height: 32)
                .background(palette.fill, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(insight.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(insight.status)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.foreground)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(palette.fill, in: Capsule())

                    Spacer(minLength: 4)

                    Text(insight.value)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Text(insight.explanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(13)
        .picklyCardSurface(
            cornerRadius: 18,
            fill: ResultSurface.card,
            stroke: palette.border.opacity(0.12)
        )
    }
}

struct WatchOutsSection: View {
    let warnings: [String]

    private var visibleWarnings: [String] {
        Array(warnings.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "What to watch", systemImage: "eye")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(visibleWarnings, id: \.self) { warning in
                    Label(warning, systemImage: "circle")
                        .font(.subheadline)
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

struct ForYouSection: View {
    let notes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "For you", systemImage: "person.crop.circle")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(notes, id: \.self) { note in
                    Label(note, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "What's inside", systemImage: "list.bullet.rectangle")

            if ingredients.isEmpty {
                Text("Ingredients not available yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .picklyCardSurface(cornerRadius: 18, fill: ResultSurface.card)
            } else {
                VStack(spacing: 12) {
                    ForEach(ingredients) { ingredient in
                        IngredientCard(ingredient: ingredient)
                    }
                }
            }
        }
    }
}

struct IngredientCard: View {
    let ingredient: IngredientAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(ingredient.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text(ingredient.badge)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ingredient.status.foregroundColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ingredient.status.softColor, in: Capsule())
            }

            Text(ingredient.explanation)
                .font(.subheadline)
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
    let product: Product
    let onAddPhotos: () -> Void
    let onScanAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .foregroundStyle(PicklyColor.statusWarningAccent)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Limited product data")
                        .font(.headline.weight(.bold))

                    Text("We don't have enough nutrition or ingredient data to score this product confidently.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button("Request product", action: onAddPhotos)
                    .buttonStyle(.borderedProminent)
                    .tint(PicklyColor.statusWarningAccent)
                    .picklyProminentButtonForeground()

                Button("Scan again", action: onScanAgain)
                    .buttonStyle(.bordered)
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
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.bold))
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(fact.value)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let percent = fact.percent {
                        Text("\(percent)%")
                            .font(.caption.monospacedDigit())
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
                    Label(recommendation, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
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

struct AlternativesResultSection: View {
    let product: Product
    let alternatives: [Product]
    let productService: any ProductService
    let savedStore: SavedProductsStore

    private var isSampleProduct: Bool {
        productService.product(id: product.id) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Better alternatives", systemImage: "arrow.triangle.branch")

            if alternatives.isEmpty {
                Text(isSampleProduct ? "Already one of the better options in this sample set." : "No alternatives yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .picklyCardSurface(cornerRadius: 20, fill: ResultSurface.card)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(alternatives.prefix(3))) { alternative in
                        NavigationLink(value: alternative) {
                            AlternativeResultCard(
                                product: alternative,
                                reason: alternative.positives.first,
                                isSaved: savedStore.isSaved(alternative)
                            )
                        }
                        .buttonStyle(PicklyPressableButtonStyle())
                    }
                }
            }
        }
    }
}

private struct AlternativeResultCard: View {
    let product: Product
    let reason: String?
    let isSaved: Bool

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnailView(product: product, size: 58)

            VStack(alignment: .leading, spacing: 5) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(product.brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let reason {
                    Text(reason)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(PicklyColor.mint, in: Capsule())
                }
            }

            Spacer(minLength: 8)

            VStack(spacing: 6) {
                ScorePill(product: product)

                if isSaved {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(PicklyColor.primary)
                        .accessibilityLabel("Saved")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(cornerRadius: 20, fill: ResultSurface.card)
    }
}

struct ResultActions: View {
    let isSaved: Bool
    let saveBounce: Bool
    let onScanAnotherProduct: () -> Void
    let onSave: () -> Void
    let onRequestProduct: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onScanAnotherProduct) {
                Label("Scan another product", systemImage: "barcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ResultPrimaryButtonStyle(tint: PicklyColor.primary))

            HStack(spacing: 12) {
                Button(action: onSave) {
                    Label(isSaved ? "Saved" : "Save result", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                        .frame(maxWidth: .infinity)
                        .scaleEffect(saveBounce ? 1.04 : 1)
                }
                .buttonStyle(ResultSecondaryButtonStyle())

                Button(action: onRequestProduct) {
                    Label("Request product", systemImage: "plus.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ResultSecondaryButtonStyle())
            }
        }
        .controlSize(.large)
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
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.headline)
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
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.bold))
            .foregroundStyle(.primary)
    }
}

struct ResultPrimaryButtonStyle: ButtonStyle {
    let tint: Color
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(colorScheme == .dark ? .black : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.vertical, 15)
            .padding(.horizontal, 16)
            .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct ResultSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(ResultSurface.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ResultSurface.stroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
