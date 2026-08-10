import SwiftUI

struct ResultHero: View {
    let product: Product
    let imageRevealed: Bool
    let displayedScore: Int
    let showVerdict: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ProductHeroImageView(
                product: product,
                imageRevealed: imageRevealed
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(PicklyColor.stroke.opacity(0.7), lineWidth: 1)
            }
            .picklyCardShadow()

            identity

            ProductResultVerdictCard(
                title: product.resultHeadline,
                subtitle: product.resultSummary,
                confidence: product.confidenceText,
                verdict: product.verdict,
                displayedScore: displayedScore,
                scoreColor: product.resultScoreColor,
                verdictFill: product.resultScoreFillColor,
                verdictForeground: product.resultScoreForegroundColor,
                isLimitedData: product.isLimitedData,
                scoreAccessibilityLabel: scoreAccessibilityLabel
            )
            .opacity(showVerdict ? 1 : 0)
            .offset(y: showVerdict ? 0 : 10)
        }
        .frame(maxWidth: .infinity)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(product.resultDisplayName)
                .font(.title.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            Text(product.resultSubtitle)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(product.category)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(PicklyColor.mint.opacity(0.72), in: Capsule())
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scoreAccessibilityLabel: String {
        guard !product.isLimitedData, let score = product.score else {
            return "Limited data, no reliable score"
        }

        return "Score \(score) out of 100"
    }
}

private struct ProductResultVerdictCard: View {
    let title: String
    let subtitle: String
    let confidence: String
    let verdict: String
    let displayedScore: Int
    let scoreColor: Color
    let verdictFill: Color
    let verdictForeground: Color
    let isLimitedData: Bool
    let scoreAccessibilityLabel: String

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    verdictBadge
                    Text(title)
                        .font(.title.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    scoreBadge
                }
            } else {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        verdictBadge
                        Text(title)
                            .font(.title.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 4)
                    scoreBadge
                }
            }

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.primary.opacity(colorScheme == .dark ? 0.82 : 0.72))
                .fixedSize(horizontal: false, vertical: true)

            Label(confidenceLabel, picklyIcon: confidenceIcon, iconSize: 14)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(PicklyColor.card)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(verdictFill.opacity(colorScheme == .dark ? 0.18 : 0.42))
                }
                .picklyCardShadow()
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(scoreColor.opacity(colorScheme == .dark ? 0.34 : 0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [title, subtitle, confidenceLabel, verdict, scoreAccessibilityLabel]
                .joined(separator: ", ")
        )
    }

    private var verdictBadge: some View {
        Label(verdict, picklyIcon: verdictIcon, iconSize: 13)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(verdictForeground)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(verdictFill, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(scoreColor.opacity(0.2), lineWidth: 1)
            }
    }

    private var scoreBadge: some View {
        Group {
            if isLimitedData {
                Text("Limited data")
                    .font(.subheadline.weight(.bold))
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(displayedScore)")
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                    Text("/100")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(
            PicklyColor.card.opacity(colorScheme == .dark ? 0.82 : 0.9),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.68), lineWidth: 1)
        }
    }

    private var confidenceLabel: String {
        guard let separator = confidence.firstIndex(of: ":") else {
            return confidence
        }

        let value = confidence[confidence.index(after: separator)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(value.capitalized) confidence"
    }

    private var confidenceIcon: String {
        confidence.localizedCaseInsensitiveContains("low")
            ? "info.circle.fill"
            : "checkmark.shield.fill"
    }

    private var verdictIcon: String {
        if isLimitedData {
            return "info.circle.fill"
        }

        switch displayedScore {
        case 85...100:
            return "checkmark.seal.fill"
        case 70..<85:
            return "checkmark.circle.fill"
        case 50..<70:
            return "minus.circle.fill"
        default:
            return "arrow.left.arrow.right"
        }
    }
}

private struct ProductHeroImageView: View {
    let product: Product
    let imageRevealed: Bool

    private let cornerRadius: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let imageSize = min(proxy.size.width, proxy.size.height)

            Group {
                if let imageURL = product.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: imageSize, height: imageSize)
                                .clipShape(heroShape)
                        case .failure, .empty:
                            fallbackImage(size: imageSize)
                        @unknown default:
                            fallbackImage(size: imageSize)
                        }
                    }
                } else {
                    fallbackImage(size: imageSize)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .scaleEffect(imageRevealed ? 1 : 0.96)
        .opacity(imageRevealed ? 1 : 0)
        .accessibilityLabel("\(product.resultDisplayName) image")
    }

    private var heroShape: some Shape {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private func fallbackImage(size: CGFloat) -> some View {
        ProductThumbnailView(
            product: product,
            size: size,
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
                        .font(.largeTitle.weight(.bold).monospacedDigit())
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.subheadline)
                .lineLimit(3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ResultOverviewCardContent: View {
    let title: String
    let subtitle: String
    let confidence: String
    let verdict: String
    let displayedScore: Int
    let scoreProgress: Double
    let scoreColor: Color
    let verdictFill: Color
    let verdictForeground: Color
    let isLimitedData: Bool
    let scoreAccessibilityLabel: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var standardLayout: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 18) {
                summary
                    .layoutPriority(1)

                scoreRing(diameter: 104)
            }

            HStack(spacing: 0) {
                confidenceBadge

                Spacer(minLength: 8)

                verdictBadge
            }
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 18) {
            summary
            scoreRing(diameter: 124)
            confidenceBadge
            verdictBadge
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summary: some View {
        ResultSummaryCard(
            title: title,
            subtitle: subtitle
        )
    }

    private func scoreRing(diameter: CGFloat) -> some View {
        AnimatedScoreRing(
            score: isLimitedData ? nil : displayedScore,
            displayedScore: displayedScore,
            progress: scoreProgress,
            color: scoreColor,
            isLimitedData: isLimitedData
        )
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    private var confidenceBadge: some View {
        ConfidenceBadge(text: confidence)
    }

    private var verdictBadge: some View {
        VerdictBadge(
            text: verdict,
            accent: scoreColor,
            fill: verdictFill,
            foreground: verdictForeground
        )
    }

    private var accessibilitySummary: String {
        "\(title). \(subtitle). \(confidence). \(verdict). \(scoreAccessibilityLabel)."
    }
}

private struct ConfidenceBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(.primary)

            if !value.isEmpty {
                Text(value)
                    .foregroundStyle(PicklyColor.ratingGreatAccent)
            }
        }
        .font(.caption2.weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.secondary.opacity(0.08), in: Capsule())
        .accessibilityLabel(text)
    }

    private var label: String {
        guard let separator = text.firstIndex(of: ":") else { return text }
        return String(text[...separator])
    }

    private var value: String {
        guard let separator = text.firstIndex(of: ":") else { return "" }
        return text[text.index(after: separator)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct VerdictBadge: View {
    let text: String
    let accent: Color
    let fill: Color
    let foreground: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 9, height: 9)

            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(fill, in: Capsule())
        .accessibilityLabel(text)
    }
}
