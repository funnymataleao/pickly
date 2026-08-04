import SwiftUI

struct ResultHero: View {
    let product: Product
    let imageRevealed: Bool
    let scoreProgress: Double
    let displayedScore: Int
    let showVerdict: Bool

    var body: some View {
        VStack(spacing: 20) {
            ProductHeroImageView(
                product: product,
                imageRevealed: imageRevealed
            )

            VStack(spacing: 8) {
                Text(product.resultDisplayName)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .foregroundStyle(.primary)

                Text(product.resultSubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(product.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.secondary.opacity(0.1), in: Capsule())
            }

            HStack(alignment: .center, spacing: 20) {
                ResultSummaryCard(
                    title: product.resultHeadline,
                    subtitle: product.resultSummary,
                    confidence: product.confidenceText
                )
                .layoutPriority(1)
                .opacity(showVerdict ? 1 : 0)
                .offset(y: showVerdict ? 0 : 10)

                ResultScoreColumn(
                    product: product,
                    displayedScore: displayedScore,
                    scoreProgress: scoreProgress
                )
                .accessibilityLabel(scoreAccessibilityLabel)
            }
            .padding(.top, 2)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .picklyCardSurface(cornerRadius: 30)
    }

    private var scoreAccessibilityLabel: String {
        guard !product.isLimitedData, let score = product.score else {
            return "Limited data, no reliable score"
        }

        return "Score \(score) out of 100"
    }
}

private struct ProductHeroImageView: View {
    let product: Product
    let imageRevealed: Bool

    private let imageSize: CGFloat = 246
    private let cornerRadius: CGFloat = 24

    var body: some View {
        Group {
            if let imageURL = product.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: imageSize, height: imageSize)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    case .failure, .empty:
                        fallbackImage
                    @unknown default:
                        fallbackImage
                    }
                }
            } else {
                fallbackImage
            }
        }
        .scaleEffect(imageRevealed ? 1 : 0.96)
        .opacity(imageRevealed ? 1 : 0)
        .accessibilityLabel("\(product.resultDisplayName) image")
    }

    private var fallbackImage: some View {
        ProductThumbnailView(
            product: product,
            size: imageSize,
            contentMode: .fill,
            cornerRadius: cornerRadius
        )
    }
}

struct AnimatedScoreRing: View {
    let score: Int?
    let displayedScore: Int
    let progress: Double
    let color: Color
    let isLimitedData: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.14), lineWidth: 10)

            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                if isLimitedData {
                    Text("Limited")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("data")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(displayedScore)")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)

                    Text("/ 100")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ResultSummaryCard: View {
    let title: String
    let subtitle: String
    let confidence: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.subheadline)
                .lineLimit(4)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ResultHeroBadge(text: confidence, color: PicklyColor.stroke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ResultScoreColumn: View {
    let product: Product
    let displayedScore: Int
    let scoreProgress: Double

    var body: some View {
        VStack(spacing: 9) {
            AnimatedScoreRing(
                score: product.score,
                displayedScore: displayedScore,
                progress: scoreProgress,
                color: product.resultScoreColor,
                isLimitedData: product.isLimitedData
            )
            .frame(width: 104, height: 104)

            Text(product.verdict)
                .font(.caption.weight(.bold))
                .foregroundStyle(product.resultScoreForegroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(product.resultScoreFillColor, in: Capsule())
        }
        .frame(width: 112)
    }
}

private struct ResultHeroBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.16), in: Capsule())
    }
}
