import SwiftUI

struct UnlockedProductCarousel: View {
    let products: [Product]
    let reasonProvider: (Product) -> String
    let isSaved: (Product) -> Bool
    let onSelect: (Product) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var carouselCount: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : 5
    }

    private var carouselSpan: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : 4
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(products) { product in
                    Button {
                        onSelect(product)
                    } label: {
                        ProductSliderCard(
                            product: product,
                            reason: reasonProvider(product),
                            reasonIcon: "leaf.fill",
                            isSaved: isSaved(product)
                        )
                    }
                    .buttonStyle(PicklyPressableButtonStyle())
                    .containerRelativeFrame(
                        .horizontal,
                        count: carouselCount,
                        span: carouselSpan,
                        spacing: 12
                    )
                    .accessibilityHint("Opens product details.")
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .contentMargins(.horizontal, PicklyLayout.screenHorizontalPadding, for: .scrollContent)
        .contentMargins(.horizontal, 0, for: .scrollIndicators)
        .padding(.horizontal, -PicklyLayout.screenHorizontalPadding)
        .scrollClipDisabled(true)
    }
}

struct LockedProductCarousel: View {
    let products: [Product]
    let reasonProvider: (Product) -> String
    let accessibilityItemName: String
    let onUpgrade: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var cardWidth: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 214 : 148
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                    Button(action: onUpgrade) {
                        LockedProductCarouselCard(
                            product: product,
                            reason: reasonProvider(product),
                            width: cardWidth
                        )
                    }
                    .buttonStyle(PicklyPressableButtonStyle())
                    .accessibilityLabel(
                        "Locked \(accessibilityItemName) \(index + 1) of \(products.count)"
                    )
                    .accessibilityHint("Opens Pickly Plus to reveal this product.")
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .contentMargins(.horizontal, PicklyLayout.screenHorizontalPadding, for: .scrollContent)
        .contentMargins(.horizontal, 0, for: .scrollIndicators)
        .padding(.horizontal, -PicklyLayout.screenHorizontalPadding)
        .scrollClipDisabled(true)
    }
}

private struct LockedProductCarouselCard: View {
    let product: Product
    let reason: String
    let width: CGFloat

    private var imageSize: CGFloat {
        width - 24
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProductThumbnailView(
                product: product,
                size: imageSize,
                contentMode: .fill,
                cornerRadius: 14
            )
            .blur(radius: 1.7)
            .overlay(alignment: .topTrailing) {
                PicklyIconImage(systemName: "lock.shield.fill", size: 12)
                    .foregroundStyle(PicklyColor.primary)
                    .frame(width: 30, height: 30)
                    .background(.regularMaterial, in: Circle())
                    .padding(7)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .redacted(reason: .placeholder)
                    .accessibilityHidden(true)

                Text(reason)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PicklyColor.primary)
                    .lineLimit(1)
                    .redacted(reason: .placeholder)
                    .accessibilityHidden(true)

                Text("Tap to unlock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.top, 12)
        }
        .padding(12)
        .frame(width: width, alignment: .leading)
        .picklyCardSurface(
            cornerRadius: 20,
            fill: PicklyColor.card,
            stroke: PicklyColor.stroke.opacity(0.54)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
