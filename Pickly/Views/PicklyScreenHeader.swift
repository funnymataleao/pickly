import SwiftUI

enum PicklyLayout {
    static let screenHorizontalPadding: CGFloat = 16
    static let rootTopPadding: CGFloat = 24
}

struct PicklyContentHeader: View {
    let title: String
    var subtitle: String?
    var usesImageBackdrop = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(dynamicTypeSize.isAccessibilitySize ? .title.bold() : .system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(titleColor)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(subtitleColor)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var titleColor: Color {
        usesImageBackdrop && colorScheme == .dark ? .white : .primary
    }

    private var subtitleColor: Color {
        usesImageBackdrop && colorScheme == .dark ? Color.white.opacity(0.82) : .secondary
    }
}

struct PicklyInlineSearchField: View {
    @Binding var text: String
    let prompt: String
    var onScan: (() -> Void)? = nil
    @FocusState private var isFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private var cornerRadius: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 18 : 28
    }

    var body: some View {
        HStack(spacing: 12) {
                PicklyIconImage(systemName: "magnifyingglass", size: 20)
                    .foregroundStyle(.primary)
                    .accessibilityHidden(true)

                TextField(
                    "",
                    text: $text,
                    prompt: Text(prompt).foregroundStyle(
                        colorScheme == .dark ? Color.white.opacity(0.76) : Color.secondary
                    )
                )
                    .font(.body)
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isFocused)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        PicklyIconImage(systemName: "xmark.circle.fill", size: 18)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                } else if let onScan {
                    Button(action: onScan) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(PicklyColor.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Scan barcode")
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 12 : 0)
        .frame(minHeight: 56)
        .modifier(SearchGlassSurface(cornerRadius: cornerRadius))
        .overlay {
            searchInnerRim
        }
        .picklyCardShadow()
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .accessibilityLabel(prompt)
    }

    private var searchInnerRim: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return shape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.16 : 0.52),
                        Color.black.opacity(colorScheme == .dark ? 0.30 : 0.10)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: reduceTransparency ? 1 : 1.25
            )
            .overlay {
                shape
                    .strokeBorder(
                        Color.black.opacity(colorScheme == .dark ? 0.22 : 0.07),
                        lineWidth: 1.5
                    )
                    .blur(radius: 1.1)
                    .offset(y: 1)
                    .mask(shape)
            }
            .allowsHitTesting(false)
    }
}

private struct SearchGlassSurface: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(
                    PicklyColor.card,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            content
                .glassEffect(
                    .regular
                        .tint(colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.04))
                        .interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
        }
    }
}

struct PicklyContentHeaderRow: ViewModifier {
    let top: CGFloat
    let bottom: CGFloat

    func body(content: Content) -> some View {
        content
            .listRowInsets(EdgeInsets(top: top, leading: 0, bottom: bottom, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

struct PicklyListSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var count: Int? = nil
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)

                    if let count {
                        Text("\(count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PicklyColor.deepMarket)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                PicklyColor.mint,
                                in: Capsule()
                            )
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if let actionTitle {
                Button {
                    onAction?()
                } label: {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                            .font(.subheadline.weight(.semibold))

                        if let actionIcon {
                            Image(systemName: actionIcon)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundStyle(PicklyColor.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, subtitle == nil ? 0 : 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct PicklyListSectionHeaderRow: ViewModifier {
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
    func picklyContentHeaderRow(top: CGFloat = 0, bottom: CGFloat = 8) -> some View {
        modifier(PicklyContentHeaderRow(top: top, bottom: bottom))
    }

    func picklyListSectionHeaderRow(top: CGFloat = 22, bottom: CGFloat = 6) -> some View {
        modifier(PicklyListSectionHeaderRow(top: top, bottom: bottom))
    }
}
