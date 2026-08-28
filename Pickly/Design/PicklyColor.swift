import SwiftUI

enum PicklyColor {
    enum SemanticStatus {
        case positive
        case attention
        case critical
        case neutral
    }

    enum InsightTone {
        case sodium
        case sugar
        case additives
        case proteinFiber
        case neutral
    }

    enum ProfileTone {
        case account
        case sugar
        case sodium
        case digestion
        case vegetarian
        case vegan
        case glutenFree
        case lactoseFree
        case pro
        case camera
        case privacy
    }

    struct StatusPalette {
        let accent: Color
        let fill: Color
        let foreground: Color
        let border: Color
    }

    static let brandLime = Color("PicklyBrandLime")
    static let brandAqua = Color("PicklyBrandAqua")
    static let brandLemon = Color("PicklyBrandLemon")

    static let primary = Color("PicklyPrimary")
    static let onBrandAccent = Color.black

    /// The dark brand green used for actions that must remain stable in both
    /// light and dark appearance. `primary` intentionally adapts to a bright
    /// lime in dark mode, so it is not suitable for this fixed white-on-green
    /// action treatment.
    static let brandDarkGreen = rgb(0x7D8A58)

    /// Foreground for the primary button fill, which changes from a dark
    /// olive in light mode to a bright lime in dark mode.
    static func onPrimary(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }

    static let deepMarket = Color("PicklyDeepMarket")
    static let mint = Color("PicklyMint")
    static let citrus = Color("PicklyCitrus")
    static let blueberry = Color("PicklyBlueberry")
    static let tomato = Color("PicklyTomato")
    static let success = Color("PicklySuccess")
    static let background = Color("PicklyBackground")
    static let card = Color("PicklyCard")
    static let stroke = Color("PicklyStroke")

    static let statusGoodAccent = primary
    static let statusGoodFill = brandLime
    static let statusGoodForeground = Color.black

    static let statusWarningAccent = citrus
    static let statusWarningFill = brandLemon
    static let statusWarningForeground = Color.black

    static let statusDangerAccent = tomato
    static let statusDangerFill = tomato
    static let statusDangerForeground = Color.white

    static let statusUnknownAccent = Color.secondary
    static let statusUnknownFill = stroke.opacity(0.55)
    static let statusUnknownForeground = Color.primary

    static let ratingGreatAccent = rgb(0x7D8A58)
    static let ratingGreatFill = brandLime
    static let ratingGoodAccent = rgb(0x0CE07A)
    static let ratingGoodFill = rgb(0x93FFC4)
    static let ratingOkayAccent = rgb(0xFFD211)
    static let ratingOkayFill = brandLemon
    static let ratingNotGreatAccent = tomato
    static let ratingNotGreatFill = rgb(0xFFBBBB)
    static let scoreRingAccent = ratingGreatAccent

    static func statusPalette(_ status: SemanticStatus) -> StatusPalette {
        switch status {
        case .positive:
            return StatusPalette(
                accent: statusGoodAccent,
                fill: statusGoodFill,
                foreground: statusGoodForeground,
                border: statusGoodAccent
            )
        case .attention:
            return StatusPalette(
                accent: statusWarningAccent,
                fill: statusWarningFill,
                foreground: statusWarningForeground,
                border: statusWarningAccent
            )
        case .critical:
            return StatusPalette(
                accent: statusDangerAccent,
                fill: statusDangerFill,
                foreground: statusDangerForeground,
                border: statusDangerAccent
            )
        case .neutral:
            return StatusPalette(
                accent: statusUnknownAccent,
                fill: statusUnknownFill,
                foreground: statusUnknownForeground,
                border: stroke
            )
        }
    }

    static func ratingPalette(forScore score: Int?, isLimitedData: Bool = false) -> StatusPalette {
        guard !isLimitedData, let score else {
            return StatusPalette(
                accent: statusUnknownAccent,
                fill: statusUnknownFill,
                foreground: statusUnknownForeground,
                border: stroke
            )
        }

        switch score {
        case 85...100:
            return StatusPalette(
                accent: ratingGreatAccent,
                fill: ratingGreatFill,
                foreground: .black,
                border: ratingGreatAccent
            )
        case 70..<85:
            return StatusPalette(
                accent: ratingGoodAccent,
                fill: ratingGoodFill,
                foreground: .black,
                border: ratingGoodAccent
            )
        case 50..<70:
            return StatusPalette(
                accent: ratingOkayAccent,
                fill: ratingOkayFill,
                foreground: .black,
                border: ratingOkayAccent
            )
        default:
            return StatusPalette(
                accent: ratingNotGreatAccent,
                fill: ratingNotGreatFill,
                foreground: .black,
                border: ratingNotGreatAccent
            )
        }
    }

    static func insightPalette(_ tone: InsightTone) -> StatusPalette {
        switch tone {
        case .sodium:
            return pastelPalette(fill: rgb(0x93F2FF))
        case .sugar:
            return pastelPalette(fill: rgb(0xFFEE93))
        case .additives:
            return pastelPalette(fill: rgb(0xD8C6FF))
        case .proteinFiber:
            return pastelPalette(fill: rgb(0x93FFC4))
        case .neutral:
            return pastelPalette(fill: rgb(0xD6DEE2))
        }
    }

    static func profilePalette(_ tone: ProfileTone) -> StatusPalette {
        switch tone {
        case .account:
            return pastelPalette(fill: rgb(0xD8C6FF))
        case .sugar:
            return pastelPalette(fill: rgb(0xFFEE93))
        case .sodium:
            return pastelPalette(fill: rgb(0x93F2FF))
        case .digestion:
            return pastelPalette(fill: rgb(0x93FFC4))
        case .vegetarian:
            return pastelPalette(fill: rgb(0xC1F679))
        case .vegan:
            return pastelPalette(fill: rgb(0xD0F2B1))
        case .glutenFree:
            return pastelPalette(fill: rgb(0xFFD97B))
        case .lactoseFree:
            return pastelPalette(fill: rgb(0xB5DBFF))
        case .pro:
            return pastelPalette(fill: rgb(0xFFBDE9))
        case .camera:
            return pastelPalette(fill: rgb(0x8FE3FF))
        case .privacy:
            return pastelPalette(fill: rgb(0xCBC7FF))
        }
    }

    static func status(forScore score: Int?, isLimitedData: Bool = false) -> SemanticStatus {
        guard !isLimitedData, let score else {
            return .neutral
        }

        switch score {
        case 70...100:
            return .positive
        case 50..<70:
            return .attention
        default:
            return .critical
        }
    }

    static func verdict(score: Int?) -> Color {
        ratingPalette(forScore: score).accent
    }

    static func verdictFill(score: Int?, isLimitedData: Bool = false) -> Color {
        ratingPalette(forScore: score, isLimitedData: isLimitedData).fill
    }

    static func verdictForeground(score: Int?, isLimitedData: Bool = false) -> Color {
        ratingPalette(forScore: score, isLimitedData: isLimitedData).foreground
    }

    private static func pastelPalette(fill: Color) -> StatusPalette {
        StatusPalette(
            accent: fill,
            fill: fill,
            foreground: .black,
            border: fill
        )
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct PicklyCardShadow: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .shadow(
                color: colorScheme == .light
                    ? Color(red: 0.15, green: 0.22, blue: 0.12).opacity(0.055)
                    : Color.black.opacity(0.16),
                radius: 12,
                x: 0,
                y: 4
            )
    }
}

struct PicklyCardSurface: ViewModifier {
    let cornerRadius: CGFloat
    let fill: Color
    let stroke: Color?

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .picklyCardShadow()
            }
            .overlay {
                if let stroke {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                }
            }
    }
}

/// A native Liquid Glass surface for interactive cards.
///
/// The opaque fallback is intentional: users who reduce transparency should
/// get the same hierarchy and contrast without a translucent material.
struct PicklyGlassCardSurface: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    PicklyColor.card,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(PicklyColor.stroke.opacity(0.45), lineWidth: 1)
                }
                .picklyCardShadow()
        } else {
            content
                // Draw the shadow on an independent shape. Applying it after
                // Liquid Glass lets the glass compositing pass clip the blur.
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(PicklyColor.card)
                        .picklyCardShadow()
                }
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

struct PicklyListCardRow: ViewModifier {
    let top: CGFloat
    let bottom: CGFloat

    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: top, leading: 0, bottom: bottom, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

extension View {
    func picklyCardShadow() -> some View {
        modifier(PicklyCardShadow())
    }

    func picklyCardSurface(
        cornerRadius: CGFloat = 20,
        fill: Color = PicklyColor.card,
        stroke: Color? = nil
    ) -> some View {
        modifier(PicklyCardSurface(cornerRadius: cornerRadius, fill: fill, stroke: stroke))
    }

    func picklyGlassCardSurface(cornerRadius: CGFloat = 20) -> some View {
        modifier(PicklyGlassCardSurface(cornerRadius: cornerRadius))
    }

    func picklyListCardRow(top: CGFloat = 8, bottom: CGFloat = 14) -> some View {
        modifier(PicklyListCardRow(top: top, bottom: bottom))
    }
}
