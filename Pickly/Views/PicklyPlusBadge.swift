import SwiftUI

struct PicklyPlusBadge: View {
    var body: some View {
        HStack(spacing: 5) {
            PicklyIconImage(systemName: "sparkles", size: 11)

            Text("Plus")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(PicklyColor.profilePalette(.pro).fill, in: Capsule())
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.32), lineWidth: 0.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pickly Plus")
    }
}
