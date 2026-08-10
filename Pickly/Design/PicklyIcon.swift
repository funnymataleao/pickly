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
    let name: String
    let isFilled: Bool

    var assetName: String {
        "Reicon\(name)\(isFilled ? "Filled" : "Outline")"
    }

    static func resolve(_ semanticName: String) -> ReiconAsset {
        let isFilled = semanticName.contains(".fill")
        let baseName = semanticName.replacingOccurrences(of: ".fill", with: "")

        let reiconName: String = switch baseName {
        case "allergens": "ShieldCheck"
        case "arrow.clockwise": "Refresh"
        case "arrow.left.arrow.right": "ArrowSwapHorizontal"
        case "arrow.triangle.branch": "BranchUp"
        case "arrow.up.forward.circle": "ArrowUpRightCircle"
        case "barcode": "Barcode"
        case "barcode.viewfinder": "ScanBarcode"
        case "basket": "Basket"
        case "bolt.heart": "HeartPulse"
        case "bookmark": "Bookmark"
        case "camera": "Camera"
        case "camera.viewfinder": "ScanBarcode"
        case "carrot": "FoodTray"
        case "chart.bar.doc.horizontal": "ChartBar"
        case "checkmark": "Check"
        case "checkmark.circle": "CheckCircle"
        case "checkmark.seal": "Verified"
        case "checkmark.shield": "ShieldCheck"
        case "chevron.down": "ChevronDown"
        case "chevron.right": "ChevronRight"
        case "circle": "Record"
        case "clock": "Clock"
        case "cube", "cube.transparent": "ThreeDCube"
        case "cup.and.saucer": "Milk"
        case "doc.text": "DocText"
        case "drop": "Drop"
        case "droplet": "Droplet"
        case "envelope": "Envelope"
        case "envelope.badge": "EnvelopeCheck"
        case "exclamationmark.triangle": "AlertTriangle"
        case "eye": "Eye"
        case "feather": "Feather"
        case "flask": "Flask"
        case "fork.knife.circle": "ForkKnife"
        case "hand.raised": "Shield"
        case "heart.text.square": "HeartSquare"
        case "icloud.slash": "CloudX"
        case "info.circle": "InfoCircle"
        case "iphone": "Mobile"
        case "keyboard": "Keyboard"
        case "leaf": "Leaf"
        case "list.bullet.rectangle": "ListSquare"
        case "lock.shield": "ShieldLock"
        case "magnifyingglass": "Search"
        case "minus": "Minus"
        case "number": "Hashtag"
        case "person.badge.key": "UserId"
        case "person.crop.circle": "ProfileCircle"
        case "photo": "Image"
        case "plus.viewfinder": "SearchPlus"
        case "rectangle.split.3x1": "Layout"
        case "slider.horizontal.3": "Sliders"
        case "sparkle.magnifyingglass": "SearchStatus"
        case "sparkles": "Sparkles"
        case "square.grid.2x2": "Grid"
        case "takeoutbag.and.cup.and.straw": "Bag"
        case "wifi.exclamationmark": "SignalSquare"
        case "xmark.circle": "CloseCircle"
        default: "InfoCircle"
        }

        return ReiconAsset(name: reiconName, isFilled: isFilled)
    }
}
