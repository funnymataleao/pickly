import SwiftUI

extension Product {
    var verdictColor: Color {
        verdictPalette.accent
    }

    var verdictFillColor: Color {
        verdictPalette.fill
    }

    var verdictForegroundColor: Color {
        verdictPalette.foreground
    }

    private var verdictPalette: PicklyColor.StatusPalette {
        PicklyColor.ratingPalette(forScore: score, isLimitedData: isLimitedData)
    }
}

struct ProductRowView: View {
    let product: Product
    let isSaved: Bool
    var showsChevron = false

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnailView(product: product, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(product.brand)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(product.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .center, spacing: 5) {
                ScorePill(product: product)

                if isSaved {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(PicklyColor.primary)
                        .accessibilityLabel("Saved")
                }
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 12)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProductRowsCard: View {
    let products: [Product]
    let isSaved: (Product) -> Bool
    let accessibilityLabel: (Product) -> String
    let onSelect: (Product) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                Button {
                    onSelect(product)
                } label: {
                    ProductRowView(
                        product: product,
                        isSaved: isSaved(product),
                        showsChevron: true
                    )
                    .padding(.leading, 14)
                    .padding(.trailing, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PicklyPressableButtonStyle())
                .accessibilityLabel(accessibilityLabel(product))

                if index < products.count - 1 {
                    Divider()
                        .padding(.leading, 80)
                        .padding(.trailing, 14)
                }
            }
        }
        .picklyCardSurface(cornerRadius: 22)
    }
}

struct ProductThumbnailView: View {
    let product: Product
    let size: CGFloat
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = 14

    var body: some View {
        Group {
            if let imageURL = product.imageURL {
                remoteImage(url: imageURL)
            } else {
                fallbackImage
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private func remoteImage(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: size, height: size)
                    .clipped()
            case .failure, .empty:
                fallbackImage
            @unknown default:
                fallbackImage
            }
        }
    }

    private var fallbackImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(product.verdictFillColor.opacity(0.22))

            Image(systemName: product.imageName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(product.verdictColor)
        }
    }
}

struct ScorePill: View {
    let product: Product
    private let size: CGFloat = 54

    var body: some View {
        VStack(spacing: 1) {
            Text(product.verdict)
                .font(.caption2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            if !product.isLimitedData, let score = product.score {
                Text("\(score)")
                    .font(.caption2.monospacedDigit())
                    .lineLimit(1)
            }
        }
        .foregroundStyle(product.verdictForegroundColor)
        .frame(width: size, height: size)
        .background(
            Circle()
                .fill(product.verdictFillColor)
        )
        .overlay {
            Circle()
                .stroke(product.verdictColor.opacity(0.22), lineWidth: 1)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if !product.isLimitedData, let score = product.score {
            return "\(product.verdict), score \(score)"
        }

        return "Limited data, no reliable score"
    }
}

#Preview {
    List {
        ProductRowView(
            product: MockProductService().products[1],
            isSaved: true
        )
    }
}
