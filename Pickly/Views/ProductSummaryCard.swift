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
        ForEach(products) { product in
            ProductSummaryCard(
                product: product,
                reason: reasonProvider(product),
                isSaved: isSaved(product),
                onToggleSave: onToggleSave.map { toggle in
                    { toggle(product) }
                },
                accessibilityLabel: accessibilityLabel(product),
                onSelect: { onSelect(product) }
            )
            .padding(.vertical, 10)
        }
    }
}

struct ProductSummaryCard: View {
    let product: Product
    let reason: String
    let isSaved: Bool
    var onToggleSave: (() -> Void)? = nil
    let accessibilityLabel: String
    let onSelect: () -> Void

    private let imageSize: CGFloat = 96
    private let favoriteVisualSize: CGFloat = 34
    private let favoriteHitSize: CGFloat = 44

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onSelect) {
                cardContent
            }
            .buttonStyle(PicklyPressableButtonStyle())
            .accessibilityLabel(accessibilityLabel)

            if let onToggleSave {
                Button(action: onToggleSave) {
                    favoriteVisual
                }
                .buttonStyle(.plain)
                .frame(width: favoriteHitSize, height: favoriteHitSize)
                .contentShape(Circle())
                .offset(
                    x: 16 + imageSize - favoriteHitSize + 1,
                    y: 17
                )
                .zIndex(2)
                .accessibilityLabel(isSaved ? "Remove from saved" : "Save product")
            }
        }
        // Repeating feed cells stay opaque. A separate Liquid Glass pass on
        // every card is expensive while scrolling and does not add hierarchy.
        .picklyCardSurface(
            cornerRadius: 22,
            fill: PicklyColor.card,
            stroke: PicklyColor.stroke.opacity(0.42)
        )
    }

    @ViewBuilder
    private var cardContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    ProductThumbnailView(product: product, size: imageSize, cornerRadius: 22)
                    productDetails
                }

                HStack(alignment: .center, spacing: 12) {
                    reasonRow
                    Spacer(minLength: 8)
                    ProductSummaryVerdictBadge(product: product)
                }
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
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)

            Text(product.brand)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !dynamicTypeSize.isAccessibilitySize {
                reasonRow
            }

            Text(product.category.capitalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PicklyColor.deepMarket)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(PicklyColor.mint, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reasonRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: "leaf.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PicklyColor.primary)

            Text(reason)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PicklyColor.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var favoriteVisual: some View {
        Image(systemName: isSaved ? "heart.fill" : "heart")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(favoriteAccent)
            .frame(width: favoriteVisualSize, height: favoriteVisualSize)
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

    var body: some View {
        VStack(spacing: 2) {
            Text(product.verdict)
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
        .frame(minWidth: dynamicTypeSize.isAccessibilitySize ? 80 : 68, minHeight: 68)
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
