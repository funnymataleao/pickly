import SwiftUI

struct OnboardingPreferencesPage: View {
    @Binding var preferences: UserPreferences

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                intro
                preferenceCard
                Text("You can change these anytime in Profile.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            // Leave the same calm breathing room below the shared header as
            // the other onboarding pages before the preference content.
            .padding(.top, 88)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose what matters to you")
                .font(dynamicTypeSize.isAccessibilitySize ? .title2.bold() : .title.bold())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("Pickly will use these preferences to make product notes and alternatives more relevant to your everyday choices.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var preferenceCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(OnboardingPreferenceOption.all.enumerated()), id: \.element.id) { index, option in
                OnboardingPreferenceRow(
                    option: option,
                    isOn: binding(for: option.keyPath)
                )

                if index < OnboardingPreferenceOption.all.count - 1 {
                    Divider()
                        .padding(.leading, 78)
                }
            }
        }
        .background(PicklyColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PicklyColor.stroke.opacity(0.54), lineWidth: 1)
        }
        .picklyCardShadow()
    }

    private func binding(for keyPath: WritableKeyPath<UserPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { _preferences.wrappedValue[keyPath: keyPath] },
            set: { _preferences.wrappedValue[keyPath: keyPath] = $0 }
        )
    }
}

private struct OnboardingPreferenceRow: View {
    let option: OnboardingPreferenceOption
    @Binding var isOn: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PreferenceOptionIcon(option: option)

            VStack(alignment: .leading, spacing: 3) {
                Text(option.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(option.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(PicklyColor.primary)
                .accessibilityLabel(option.title)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 15 : 13)
    }
}

private struct PreferenceOptionIcon: View {
    let option: OnboardingPreferenceOption

    var body: some View {
        Group {
            if let iconText = option.iconText {
                Text(iconText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            } else {
                PicklyIconImage(
                    systemName: option.iconSystemName,
                    size: 25,
                    isDecorative: true,
                    scalesWithDynamicType: false
                )
            }
        }
        .foregroundStyle(.black)
        .frame(width: 46, height: 46)
        .background(
            PicklyColor.profilePalette(option.tone).fill,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityHidden(true)
    }
}

private struct OnboardingPreferenceOption: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let iconSystemName: String
    let iconText: String?
    let tone: PicklyColor.ProfileTone
    let keyPath: WritableKeyPath<UserPreferences, Bool>

    static let all: [OnboardingPreferenceOption] = [
        OnboardingPreferenceOption(
            id: "low-sugar",
            title: PicklyCopy.localized("Low sugar"),
            subtitle: PicklyCopy.localized("Prefer products with less added sugar"),
            iconSystemName: GroceryGoal.lowSugar.preferenceIcon,
            iconText: nil,
            tone: .sugar,
            keyPath: \.lowSugar
        ),
        OnboardingPreferenceOption(
            id: "low-sodium",
            title: PicklyCopy.localized("Low sodium"),
            subtitle: PicklyCopy.localized("Prefer lower-sodium options"),
            iconSystemName: GroceryGoal.lowSodium.preferenceIcon,
            iconText: nil,
            tone: .sodium,
            keyPath: \.lowSodium
        ),
        OnboardingPreferenceOption(
            id: "gentler-picks",
            title: PicklyCopy.localized("Gentler picks"),
            subtitle: PicklyCopy.localized("Prefer simpler options that may feel easier to digest"),
            iconSystemName: GroceryGoal.sensitiveDigestion.preferenceIcon,
            iconText: nil,
            tone: .digestion,
            keyPath: \.sensitiveDigestion
        ),
        OnboardingPreferenceOption(
            id: "vegetarian",
            title: PicklyCopy.localized("Vegetarian"),
            subtitle: PicklyCopy.localized("Prioritize vegetarian-friendly products"),
            iconSystemName: GroceryGoal.vegetarian.preferenceIcon,
            iconText: nil,
            tone: .vegetarian,
            keyPath: \.vegetarian
        ),
        OnboardingPreferenceOption(
            id: "vegan",
            title: PicklyCopy.localized("Vegan"),
            subtitle: PicklyCopy.localized("Prefer products without animal ingredients"),
            iconSystemName: GroceryGoal.vegan.preferenceIcon,
            iconText: nil,
            tone: .vegan,
            keyPath: \.vegan
        ),
        OnboardingPreferenceOption(
            id: "gluten-free",
            title: PicklyCopy.localized("Gluten-free"),
            subtitle: PicklyCopy.localized("Flag products that may not fit this preference"),
            iconSystemName: GroceryGoal.glutenFree.preferenceIcon,
            iconText: nil,
            tone: .glutenFree,
            keyPath: \.glutenFree
        ),
        OnboardingPreferenceOption(
            id: "lactose-free",
            title: PicklyCopy.localized("Lactose-free"),
            subtitle: PicklyCopy.localized("Flag products that may not fit this preference"),
            iconSystemName: GroceryGoal.lactoseFree.preferenceIcon,
            iconText: nil,
            tone: .lactoseFree,
            keyPath: \.lactoseFree
        )
    ]
}

#Preview {
    OnboardingPreferencesPage(preferences: .constant(.prototype))
        .background(PicklyColor.background)
}
