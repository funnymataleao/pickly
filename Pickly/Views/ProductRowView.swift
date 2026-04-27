import SwiftUI

extension Product {
    var verdictColor: Color {
        switch score {
        case 85...100:
            .green
        case 70..<85:
            .mint
        case 50..<70:
            .orange
        default:
            .brown
        }
    }
}

struct ProductRowView: View {
    let product: Product
    let isSaved: Bool

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

            VStack(alignment: .trailing, spacing: 6) {
                ScorePill(product: product)

                if isSaved {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .accessibilityLabel("Saved")
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct ProductThumbnailView: View {
    let product: Product
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(product.verdictColor.opacity(0.14))

            Image(systemName: product.imageName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(product.verdictColor)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ScorePill: View {
    let product: Product

    var body: some View {
        VStack(spacing: 1) {
            Text(product.verdict)
                .font(.caption.bold())

            Text("\(product.score)")
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(product.verdictColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(product.verdictColor.opacity(0.12))
        )
        .accessibilityLabel("\(product.verdict), score \(product.score)")
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
