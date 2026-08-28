import SwiftUI

private struct PicklyProminentButtonForegroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.foregroundStyle(PicklyColor.onPrimary(for: colorScheme))
    }
}

extension View {
    func picklyProminentButtonForeground() -> some View {
        modifier(PicklyProminentButtonForegroundModifier())
    }
}

struct PicklyPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct PicklyRequestButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.78))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                PicklyColor.brandDarkGreen.opacity(isEnabled ? 1 : 0.48),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}
