import SwiftUI

struct ScoringMethodologyView: View {
    var showsDoneButton = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("What the score means") {
                Text(ScoringMethodology.scorePurpose)
            }

            Section("Calculation") {
                Text(ScoringMethodology.calculation)
                Text(ScoringMethodology.verdictRanges)
            }

            Section("Data and confidence") {
                Text(ScoringMethodology.dataSources)
                Text(ScoringMethodology.confidence)
            }

            Section("Important limits") {
                Label {
                    Text(ScoringMethodology.medicalDisclaimer)
                } icon: {
                    PicklyIconImage(systemName: "info.circle.fill", size: 18)
                        .foregroundStyle(PicklyColor.primary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("How scoring works")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ScoringMethodologyLinkCard: View {
    var body: some View {
        NavigationLink {
            ScoringMethodologyView()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                PicklyIconImage(systemName: "info.circle.fill", size: 18)
                    .foregroundStyle(PicklyColor.primary)
                    .frame(width: 36, height: 36)
                    .background(PicklyColor.mint, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("How scoring works")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("See the factors, data sources, confidence rules, and important limits behind every result.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                PicklyIconImage(systemName: "chevron.right", size: 12)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .picklyCardSurface(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens Pickly's scoring methodology and medical disclaimer.")
    }
}

#Preview {
    NavigationStack {
        ScoringMethodologyView()
    }
}
