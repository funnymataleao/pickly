import SwiftUI

/// The canonical horizontal product card used by Home, Saved and History.
/// Keeping the complete surface in one component prevents the product feeds
/// from drifting in width, typography, spacing or elevation.
struct ProductSummaryList: View {
    let products: [Product]
    let reasonProvider: (Product) -> String
    let isSaved: (Product) -> Bool
    var onToggleSave: ((Product) -> Void)? = nil
    let accessibilityLabel: (Product) -> String
    let onSelect: (Product) -> Void

    var body: some View {
        LazyVStack(spacing: PicklyLayout.screenHorizontalPadding) {
            ForEach(products) { product in
                ZStack(alignment: .topLeading) {
                    // This entire list can be hosted inside one SwiftUI List
                    // row. Multiple NavigationLinks in that row may all push
                    // from one tap, so the cell reports one explicit selection
                    // to its owning screen instead.
                    Button {
                        onSelect(product)
                    } label: {
                        ProductSummaryCard(
                            product: product,
                            reason: reasonProvider(product)
                        )
                    }
                    .buttonStyle(PicklyPressableButtonStyle())
                    .accessibilityLabel(accessibilityLabel(product))
                    .accessibilityHint("Opens product details.")

                    if let onToggleSave {
                        ProductFavoriteButton(
                            isSaved: isSaved(product),
                            action: { onToggleSave(product) }
                        )
                        .offset(
                            x: 16 + ProductSummaryCard.imageSize - ProductSummaryCard.favoriteHitSize + 1,
                            y: 17
                        )
                        .zIndex(2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Keeps product-feed copy short enough for compact cards while preserving
/// the detailed explanation on the full result screen.
enum ProductCardCopy {
    enum ReasonTone: Equatable {
        case positive
        case attention
        case neutral
    }

    static func shortReason(_ reason: String) -> String {
        let value = reason
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let normalized = value.lowercased()

        // Goal labels are shared with onboarding, Profile, and the filter
        // chips. Handle the canonical values before the free-form fact
        // heuristics below so a compact card never invents a second
        // vocabulary (for example, "Low sodium" becoming "Low salt").
        switch normalized {
        case "low sugar", "low added sugar":
            return PicklyCopy.localized("Low sugar")
        case "low sodium", "low salt", "lower salt", "lower sodium":
            return PicklyCopy.localized("Low sodium")
        case "high protein", "good protein":
            return PicklyCopy.localized("High protein")
        case "short ingredients":
            return PicklyCopy.localized("Short ingredients")
        case "gentler pick", "gentler picks":
            return PicklyCopy.localized("Gentler picks")
        case "vegetarian":
            return PicklyCopy.localized("Vegetarian")
        case "vegan":
            return PicklyCopy.localized("Vegan")
        case "gluten-free", "gluten free":
            return PicklyCopy.localized("Gluten-free")
        case "lactose-free", "lactose free":
            return PicklyCopy.localized("Lactose-free")
        default:
            break
        }

        if normalized.contains("more than") && normalized.contains("times") {
            return PicklyCopy.localized("Worth checking")
        }

        if normalized.contains("ingredient") {
            if normalized.contains("not available") || normalized.contains("missing") {
                return PicklyCopy.localized("Data missing")
            }

            if normalized.contains("more than")
                || normalized.contains("long")
                || normalized.contains("item")
                || normalized.contains("times")
            {
                return PicklyCopy.localized("Long list")
            }

            if normalized.contains("short") {
                return PicklyCopy.localized("Simple recipe")
            }

            return PicklyCopy.localized("Simple recipe")
        }

        if normalized.contains("calor") {
            if normalized.contains("low") || normalized.contains("less") || normalized.contains("lower") {
                return PicklyCopy.localized("Lighter pick")
            }
            if normalized.contains("high") || normalized.contains("more") || normalized.contains("higher") {
                return PicklyCopy.localized("Heavier pick")
            }
            return PicklyCopy.localized("Energy check")
        }

        if normalized.contains("sugar") {
            if normalized.contains("low") || normalized.contains("less") || normalized.contains("lower") {
                return PicklyCopy.localized("Low sugar")
            }
            if normalized.contains("high") || normalized.contains("more") || normalized.contains("higher") {
                return PicklyCopy.localized("Higher sugar")
            }
            if normalized.contains("moderate") {
                return PicklyCopy.localized("Moderate sugar")
            }
        }

        if normalized.contains("sodium") || normalized.contains("salt") {
            if normalized.contains("low") || normalized.contains("less") || normalized.contains("lower") {
                return PicklyCopy.localized("Low sodium")
            }
            if normalized.contains("high") || normalized.contains("more") || normalized.contains("higher") {
                return PicklyCopy.localized("Higher sodium")
            }
            if normalized.contains("moderate") {
                return PicklyCopy.localized("Moderate sodium")
            }
        }

        if normalized.contains("saturated fat") {
            if normalized.contains("low") || normalized.contains("less") || normalized.contains("lower") {
                return PicklyCopy.localized("Low sat fat")
            }
            if normalized.contains("high") || normalized.contains("more") || normalized.contains("higher") {
                return PicklyCopy.localized("Higher sat fat")
            }
            return PicklyCopy.localized("Sat fat")
        }

        if normalized.contains("additive") {
            return normalized.contains("several") || normalized.contains("many")
                ? PicklyCopy.localized("Several additives")
                : PicklyCopy.localized("Some additives")
        }

        if normalized.contains("protein") {
            return normalized.contains("high") || normalized.contains("good")
                ? PicklyCopy.localized("Good protein")
                : PicklyCopy.localized("Some protein")
        }

        if normalized.contains("fiber") {
            return normalized.contains("high") || normalized.contains("good")
                ? PicklyCopy.localized("Good fiber")
                : PicklyCopy.localized("Some fiber")
        }

        if value.count > 28 {
            return normalized.contains("watch") || normalized.contains("check")
                ? PicklyCopy.localized("Worth checking")
                : PicklyCopy.localized("Review details")
        }

        return value
    }

    /// Goal tags share one visual treatment, but each goal keeps its own
    /// familiar SF Symbol so the tag can be recognized at a glance.
    static func icon(for reason: String, fallback: String = "info.circle.fill") -> String {
        switch shortReason(reason).lowercased() {
        case "low sugar":
            return GroceryGoal.lowSugar.systemImage
        case "low sodium", "low salt":
            return GroceryGoal.lowSodium.systemImage
        case "high protein", "good protein":
            return GroceryGoal.highProtein.systemImage
        case "short ingredients", "simple recipe":
            return GroceryGoal.shortIngredients.systemImage
        case "gentler picks", "gentler pick":
            return GroceryGoal.sensitiveDigestion.systemImage
        case "vegetarian":
            return GroceryGoal.vegetarian.systemImage
        case "vegan":
            return GroceryGoal.vegan.systemImage
        case "gluten-free":
            return GroceryGoal.glutenFree.systemImage
        case "lactose-free":
            return GroceryGoal.lactoseFree.systemImage
        default:
            return fallback
        }
    }

    /// Classifies the compact reason independently from the product's overall
    /// score. A product can score below 70 while still having a positive fact
    /// such as low salt, so the reason itself must drive its visual treatment.
    static func reasonTone(_ reason: String) -> ReasonTone {
        switch shortReason(reason).lowercased() {
        case "low sugar", "low sodium", "low salt", "low sat fat", "high protein",
             "good protein", "good fiber", "short ingredients", "simple recipe",
             "gentler picks", "gentler pick", "vegetarian", "vegan", "gluten-free",
             "lactose-free", "less sugar", "lower sodium", "higher protein", "no added sugar",
             "lighter pick":
            return .positive
        case "limited data", "data missing", "worth checking", "review details", "energy check":
            return .neutral
        default:
            return .attention
        }
    }
}

struct ProductSummaryCard: View {
    fileprivate static let imageSize: CGFloat = 84
    fileprivate static let favoriteHitSize: CGFloat = 44

    let product: Product
    let reason: String

    private let imageSize = ProductSummaryCard.imageSize

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesStackedLayout: Bool {
        dynamicTypeSize >= .xxLarge
    }

    var body: some View {
        cardContent
            // Repeating feed cells stay opaque. A separate Liquid Glass pass
            // on every card is expensive while scrolling and does not add
            // hierarchy.
            .picklyCardSurface(
                cornerRadius: 22,
                fill: PicklyColor.card,
                stroke: PicklyColor.stroke.opacity(0.42)
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var cardContent: some View {
        if usesStackedLayout {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    ProductThumbnailView(product: product, size: imageSize, cornerRadius: 22)
                    Spacer(minLength: 12)
                    ProductSummaryVerdictBadge(product: product)
                }

                productDetails
                reasonRow
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 14) {
                ProductThumbnailView(product: product, size: imageSize, cornerRadius: 22)
                productDetails
                ProductSummaryVerdictBadge(product: product)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var productDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(product.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(usesStackedLayout ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            Text(product.brand)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(usesStackedLayout ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)

            if !usesStackedLayout {
                reasonRow
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reasonRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            PicklyIconImage(
                systemName: reasonIcon,
                size: 14,
                isDecorative: true,
                scalesWithDynamicType: false
            )
                .foregroundStyle(reasonColor)

            Text(ProductCardCopy.shortReason(reason))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(reasonColor)
                .lineLimit(usesStackedLayout ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var reasonColor: Color {
        switch ProductCardCopy.reasonTone(reason) {
        case .positive:
            return PicklyColor.primary
        case .neutral:
            return PicklyColor.statusUnknownAccent
        case .attention:
            return product.verdictColor
        }
    }

    private var reasonIcon: String {
        ProductCardCopy.icon(for: reason)
    }

}

private struct ProductFavoriteButton: View {
    let isSaved: Bool
    let action: () -> Void

    private let visualSize: CGFloat = 34
    private let hitSize: CGFloat = ProductSummaryCard.favoriteHitSize

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: isSaved ? "heart.fill" : "heart")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(favoriteAccent)
            .frame(width: visualSize, height: visualSize)
            .background(
                isSaved
                    ? favoriteSelectedFill
                    : Color(uiColor: .systemBackground).opacity(colorScheme == .dark ? 0.74 : 0.86),
                in: Circle()
            )
            .overlay {
                Circle()
                    .stroke(favoriteAccent.opacity(isSaved ? 0.50 : 0.34), lineWidth: 0.9)
            }
            .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
            .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .frame(width: hitSize, height: hitSize)
        .contentShape(Circle())
        .accessibilityLabel(isSaved ? "Remove from saved" : "Save product")
    }

    private var favoriteAccent: Color {
        colorScheme == .dark
            ? Color(red: 1.00, green: 0.48, blue: 0.37)
            : Color(red: 0.86, green: 0.28, blue: 0.21)
    }

    private var favoriteSelectedFill: Color {
        colorScheme == .dark
            ? Color(red: 0.27, green: 0.12, blue: 0.10)
            : Color(red: 1.00, green: 0.88, blue: 0.84)
    }
}

private struct ProductSummaryVerdictBadge: View {
    let product: Product
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var usesStackedLayout: Bool {
        dynamicTypeSize >= .xxLarge
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(product.localizedVerdict)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            if !product.isLimitedData, let score = product.score {
                Text("\(score)")
                    .font(.title2.bold().monospacedDigit())
                    .lineLimit(1)
            }
        }
        .foregroundStyle(product.verdictForegroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(minWidth: usesStackedLayout ? 80 : 68, minHeight: 68)
        .background(
            product.verdictFillColor,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(product.verdictColor.opacity(0.20), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
