import SwiftUI

/// A single rendering surface for Pickly's Reicon-based interface icon system.
///
/// Existing semantic identifiers intentionally stay independent from asset names so
/// product fixtures and view state don't need to know how a glyph is implemented.
struct PicklyIconImage: View {
    let systemName: String
    let isDecorative: Bool
    let scalesWithDynamicType: Bool

    private let baseSize: CGFloat
    @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 18

    init(
        systemName: String,
        size: CGFloat = 18,
        isDecorative: Bool = true,
        scalesWithDynamicType: Bool = true
    ) {
        self.systemName = systemName
        self.isDecorative = isDecorative
        self.scalesWithDynamicType = scalesWithDynamicType
        baseSize = size
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Image(resolvedIcon.assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .scaleEffect(
                x: resolvedIcon.mirrorsHorizontally ? -1 : 1,
                y: resolvedIcon.mirrorsVertically ? -1 : 1
            )
            .frame(width: renderedSize, height: renderedSize)
            .accessibilityHidden(isDecorative)
    }

    private var resolvedIcon: ReiconAsset {
        ReiconAsset.resolve(systemName)
    }

    private var renderedSize: CGFloat {
        scalesWithDynamicType ? scaledSize : baseSize
    }
}

extension Label where Title == Text, Icon == PicklyIconImage {
    init(
        _ titleKey: LocalizedStringKey,
        picklyIcon systemName: String,
        iconSize: CGFloat = 18
    ) {
        self.init {
            Text(titleKey)
        } icon: {
            PicklyIconImage(systemName: systemName, size: iconSize)
        }
    }

    init<S>(
        _ title: S,
        picklyIcon systemName: String,
        iconSize: CGFloat = 18
    ) where S: StringProtocol {
        self.init {
            Text(title)
        } icon: {
            PicklyIconImage(systemName: systemName, size: iconSize)
        }
    }
}

private struct ReiconAsset {
    enum Style {
        case filled
        case outline
    }

    let name: String
    var style: Style = .filled
    var mirrorsHorizontally = false
    var mirrorsVertically = false

    var assetName: String {
        "Reicon\(name)\(style == .filled ? "Filled" : "Outline")"
    }

    static func resolve(_ semanticName: String) -> ReiconAsset {
        let baseName = semanticName.replacingOccurrences(of: ".fill", with: "")

        return switch baseName {
        case "allergens": ReiconAsset(name: "ShieldCheck")
        case "arrow.clockwise": ReiconAsset(name: "Refresh")
        case "arrow.left.arrow.right", "arrow.up.arrow.down": ReiconAsset(name: "ArrowSwapHorizontal")
        case "arrow.right": ReiconAsset(name: "ChevronRight")
        case "arrow.triangle.branch": ReiconAsset(name: "BranchUp")
        case "arrow.up.forward.circle": ReiconAsset(name: "ArrowUpRightCircle")
        case "barcode": ReiconAsset(name: "Barcode")
        case "barcode.viewfinder": ReiconAsset(name: "ScanBarcode")
        case "basket": ReiconAsset(name: "Basket")
        case "bolt.heart": ReiconAsset(name: "HeartPulse")
        case "bookmark.outline": ReiconAsset(name: "Bookmark", style: .outline)
        case "bookmark": ReiconAsset(name: "Bookmark")
        case "camera": ReiconAsset(name: "Camera")
        case "camera.viewfinder": ReiconAsset(name: "ScanBarcode")
        case "carrot": ReiconAsset(name: "FoodTray")
        case "chart.bar.doc.horizontal": ReiconAsset(name: "ChartBar")
        case "checkmark": ReiconAsset(name: "Check")
        case "checkmark.circle": ReiconAsset(name: "CheckCircle")
        case "checkmark.seal": ReiconAsset(name: "Verified")
        case "checkmark.shield": ReiconAsset(name: "ShieldCheck")
        case "chevron.down": ReiconAsset(name: "ChevronDown")
        case "chevron.left": ReiconAsset(name: "ChevronRight", mirrorsHorizontally: true)
        case "chevron.right": ReiconAsset(name: "ChevronRight")
        case "chevron.up": ReiconAsset(name: "ChevronDown", mirrorsVertically: true)
        case "circle": ReiconAsset(name: "Record")
        case "clock": ReiconAsset(name: "Clock")
        case "cube", "cube.transparent": ReiconAsset(name: "ThreeDCube")
        case "cup.and.saucer": ReiconAsset(name: "Milk")
        case "doc.text", "square.and.pencil": ReiconAsset(name: "DocText")
        case "drop": ReiconAsset(name: "Drop")
        case "droplet": ReiconAsset(name: "Droplet")
        case "envelope": ReiconAsset(name: "Envelope")
        case "envelope.badge": ReiconAsset(name: "EnvelopeCheck")
        case "exclamationmark.circle", "exclamationmark.triangle": ReiconAsset(name: "AlertTriangle")
        case "eye": ReiconAsset(name: "Eye")
        case "feather": ReiconAsset(name: "Feather")
        case "flask": ReiconAsset(name: "Flask")
        case "fork.knife.circle": ReiconAsset(name: "ForkKnife")
        case "hand.raised": ReiconAsset(name: "Shield")
        case "heart.text.square": ReiconAsset(name: "HeartSquare")
        case "icloud.slash": ReiconAsset(name: "CloudX")
        case "info.circle": ReiconAsset(name: "InfoCircle")
        case "iphone": ReiconAsset(name: "Mobile")
        case "keyboard": ReiconAsset(name: "Keyboard")
        case "leaf": ReiconAsset(name: "Leaf")
        case "line.3.horizontal.decrease.circle", "slider.horizontal.3": ReiconAsset(name: "Sliders")
        case "list.bullet.rectangle": ReiconAsset(name: "ListSquare")
        case "lock.shield": ReiconAsset(name: "ShieldLock")
        case "magnifyingglass": ReiconAsset(name: "Search", style: .outline)
        case "minus", "minus.circle": ReiconAsset(name: "Minus")
        case "number": ReiconAsset(name: "Hashtag")
        case "person.badge.key": ReiconAsset(name: "UserId")
        case "person.crop.circle", "person.crop.circle.badge.exclamationmark": ReiconAsset(name: "ProfileCircle")
        case "photo": ReiconAsset(name: "Image")
        case "plus.viewfinder": ReiconAsset(name: "SearchPlus")
        case "rectangle.split.3x1": ReiconAsset(name: "Layout")
        case "sparkle.magnifyingglass": ReiconAsset(name: "SearchStatus")
        case "sparkles": ReiconAsset(name: "Sparkles")
        case "square.grid.2x2": ReiconAsset(name: "Grid")
        case "takeoutbag.and.cup.and.straw": ReiconAsset(name: "Bag")
        case "wifi.exclamationmark": ReiconAsset(name: "SignalSquare")
        case "xmark.circle": ReiconAsset(name: "CloseCircle")
        default: ReiconAsset(name: "InfoCircle")
        }
    }
}
