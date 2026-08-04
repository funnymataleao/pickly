import SwiftUI

struct PaywallPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(PicklyColor.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pickly Pro")
                                .font(.largeTitle.bold())

                            Text("More context when you need it, without hiding basic grocery clarity.")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.bottom, 6)

                    VStack(spacing: 12) {
                        PaywallFeatureRow(
                            systemImage: "arrow.left.arrow.right",
                            title: "Advanced alternatives",
                            subtitle: "Compare better options by sugar, sodium, protein, and ingredients."
                        )

                        PaywallFeatureRow(
                            systemImage: "slider.horizontal.3",
                            title: "Personal filters",
                            subtitle: "Tune results for your grocery preferences."
                        )

                        PaywallFeatureRow(
                            systemImage: "clock.arrow.circlepath",
                            title: "Full product history",
                            subtitle: "Return to past scans and saved decisions."
                        )

                        PaywallFeatureRow(
                            systemImage: "icloud",
                            title: "Account sync",
                            subtitle: "Keep saved products available across devices later."
                        )
                    }

                    VStack(spacing: 10) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PicklyColor.primary)
                        .picklyProminentButtonForeground()

                        Button("Not now") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }

                    Text("No purchase is available here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(20)
            }
            .scrollClipDisabled()
            .background(PicklyColor.background)
            .navigationTitle("Pickly Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PaywallFeatureRow: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(PicklyColor.primary)
                .frame(width: 32, height: 32)
                .background(PicklyColor.mint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(cornerRadius: 16)
    }
}

#Preview {
    PaywallPlaceholderView()
}
