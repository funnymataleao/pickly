import StoreKit
import SwiftUI

private enum PaywallSpacing {
    static let section: CGFloat = 32
    static let group: CGFloat = 20
    static let item: CGFloat = 16
    static let cardInset: CGFloat = 20
}

enum PicklyPaywallEntryPoint {
    case general
    case alternatives

    var headline: String {
        switch self {
        case .general:
            return PicklyCopy.localized("Choose with less guesswork.")
        case .alternatives:
            return PicklyCopy.localized("Explore Better Choices.")
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return PicklyCopy.localized("Get live catalog matches and compare what matters on every scan.")
        case .alternatives:
            return PicklyCopy.localized("Check the live catalog for higher-scoring products and compare them side by side.")
        }
    }
}

struct PicklyPaywallView: View {
    let entryPoint: PicklyPaywallEntryPoint

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedPlan: SubscriptionStore.Plan = .annual

    init(entryPoint: PicklyPaywallEntryPoint = .general) {
        self.entryPoint = entryPoint
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PaywallSpacing.section) {
                    hero

                    if subscriptionStore.isPlus {
                        activeSubscriptionCard
                    } else if subscriptionStore.hasProducts {
                        subscriptionStoreView
                    } else {
                        unavailableCard
                    }

                    termsAndPrivacy
                }
                .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(PicklyColor.background.ignoresSafeArea())
            .navigationTitle("Pickly Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await subscriptionStore.refresh()
            selectAnAvailablePlanIfNeeded()
        }
        .onChange(of: subscriptionStore.products.map(\.id)) { _, _ in
            selectAnAvailablePlanIfNeeded()
        }
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        PicklyColor.ratingGreatAccent.opacity(0.72),
                        PicklyColor.brandAqua.opacity(0.34),
                        PicklyColor.brandLemon.opacity(0.22)
                    ]
                    : [
                        PicklyColor.ratingGoodFill,
                        PicklyColor.brandAqua.opacity(0.48),
                        PicklyColor.brandLemon.opacity(0.62)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(colorScheme == .dark ? 0.10 : 0.34))
                .frame(width: 180, height: 180)
                .blur(radius: 2)
                .offset(x: 66, y: -74)

            VStack(alignment: .leading, spacing: 18) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        heroBrandLabel
                        heroClarityBadge
                    }
                } else {
                    HStack(spacing: 10) {
                        heroBrandLabel

                        Spacer(minLength: 8)

                        heroClarityBadge
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(entryPoint.headline)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(heroForeground)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(entryPoint.subtitle)
                        .font(.headline)
                        .foregroundStyle(heroForeground.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        HeroValueChip(title: heroMatchTitle, foreground: heroForeground)
                        HeroValueChip(title: "Compare products", foreground: heroForeground)
                    }
                } else {
                    HStack(spacing: 8) {
                        HeroValueChip(title: heroMatchTitle, foreground: heroForeground)
                        HeroValueChip(title: "Compare products", foreground: heroForeground)
                    }
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.52), lineWidth: 1)
        }
        .picklyCardShadow()
        .accessibilityElement(children: .combine)
    }

    private var heroBrandLabel: some View {
        Label("PICKLY PLUS", picklyIcon: "sparkles", iconSize: 13)
            .font(.caption.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(heroForeground)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var heroClarityBadge: some View {
        Text("More clarity")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(colorScheme == .dark ? 0.14 : 0.46), in: Capsule())
            .foregroundStyle(heroForeground)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var heroForeground: Color {
        colorScheme == .dark ? .white : .black
    }

    private var heroMatchTitle: String {
        switch entryPoint {
        case .general:
            PicklyCopy.localized("Live catalog matches")
        case .alternatives:
            PicklyCopy.localized("Live higher-scoring matches")
        }
    }

    private var subscriptionStoreView: some View {
        VStack(alignment: .leading, spacing: PaywallSpacing.section) {
            benefitsCard

            VStack(alignment: .leading, spacing: PaywallSpacing.group) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Choose your pace")
                        .font(.title3.weight(.bold))

                    Text("Try monthly, or choose annual for the best value.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: PaywallSpacing.item) {
                    ForEach(availablePlans) { plan in
                        planCard(for: plan)
                    }
                }

                subscribeButton
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            restoreButton
        }
    }

    private func planCard(for plan: SubscriptionStore.Plan) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            if reduceMotion {
                selectedPlan = plan
            } else {
                withAnimation(.snappy(duration: 0.2)) {
                    selectedPlan = plan
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: PaywallSpacing.item) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(displayName(for: plan))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(displayPrice(for: plan))
                            .font(.body)
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 8) {
                        if plan == .annual {
                            Text(annualValueBadge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(PicklyColor.profilePalette(.pro).fill, in: Capsule())
                        }

                        PicklyIconImage(
                            systemName: isSelected ? "checkmark.circle" : "circle",
                            size: 28
                        )
                            .foregroundStyle(
                                isSelected ? PicklyColor.primary : PicklyColor.stroke
                            )
                            .accessibilityHidden(true)
                    }
                }

                Divider()

                Text(planSupportLine(for: plan))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(PaywallSpacing.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    isSelected
                        ? PicklyColor.ratingGoodFill.opacity(0.20)
                        : PicklyColor.card
                )
                .picklyCardShadow()
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isSelected
                        ? PicklyColor.primary.opacity(0.82)
                        : PicklyColor.stroke.opacity(0.66),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName(for: plan)), \(displayPrice(for: plan))")
        .accessibilityValue(
            isSelected ? PicklyCopy.localized("Selected") : PicklyCopy.localized("Not selected")
        )
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var subscribeButton: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    if await subscriptionStore.purchase(selectedPlan) {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if subscriptionStore.isPurchasing {
                        ProgressView()
                            .tint(PicklyColor.onPrimary(for: colorScheme))
                    }

                    Text(
                        subscriptionStore.isPurchasing
                            ? PicklyCopy.localized("Working…")
                            : PicklyCopy.format("Start with %@", selectedPlan.title)
                    )
                }
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(PicklyColor.primary)
            .picklyProminentButtonForeground()
            .disabled(subscriptionStore.isPurchasing || product(for: selectedPlan) == nil)
            .accessibilityHint("Starts the selected Pickly Plus subscription.")

            Text("Cancel anytime in Apple ID settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private func product(for plan: SubscriptionStore.Plan) -> StoreKit.Product? {
        subscriptionStore.products.first { $0.id == plan.productID }
    }

    private func displayName(for plan: SubscriptionStore.Plan) -> String {
        product(for: plan)?.displayName ?? PicklyCopy.format("Pickly Plus %@", plan.title)
    }

    private func displayPrice(for plan: SubscriptionStore.Plan) -> String {
        if let product = product(for: plan) {
            return "\(product.displayPrice)/\(PicklyCopy.localized(plan == .monthly ? "month" : "year"))"
        }

        return PicklyCopy.localized("Unavailable")
    }

    private var availablePlans: [SubscriptionStore.Plan] {
        SubscriptionStore.Plan.allCases.filter { product(for: $0) != nil }
    }

    private var annualValueBadge: String {
        guard
            let monthlyProduct = product(for: .monthly),
            let annualProduct = product(for: .annual)
        else {
            return PicklyCopy.localized("BEST VALUE")
        }

        let fullYearAtMonthlyRate = monthlyProduct.price * Decimal(12)
        guard fullYearAtMonthlyRate > annualProduct.price else {
            return PicklyCopy.localized("BEST VALUE")
        }

        let savings = (fullYearAtMonthlyRate - annualProduct.price)
            / fullYearAtMonthlyRate
            * Decimal(100)
        let roundedSavings = NSDecimalNumber(decimal: savings).intValue
        return roundedSavings > 0
            ? PicklyCopy.format("SAVE %@%%", String(roundedSavings))
            : PicklyCopy.localized("BEST VALUE")
    }

    private func selectAnAvailablePlanIfNeeded() {
        guard product(for: selectedPlan) == nil, let firstPlan = availablePlans.first else {
            return
        }
        selectedPlan = firstPlan
    }

    private func planSupportLine(for plan: SubscriptionStore.Plan) -> String {
        switch plan {
        case .monthly:
            return PicklyCopy.localized("Ongoing access to live goal-based and higher-scoring product matching.")
        case .annual:
            return PicklyCopy.localized("A year of live catalog matching and side-by-side comparison.")
        }
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: PaywallSpacing.item) {
            Text("More clarity per scan")
                .font(.title3.weight(.bold))

            VStack(spacing: 0) {
                PaywallFeatureRow(
                    systemImage: "arrow.left.arrow.right",
                    title: "Live catalog matching",
                    subtitle: alternativesFeatureSubtitle,
                    fill: PicklyColor.ratingGoodFill
                )

                Divider()
                    .padding(.leading, 48)

                PaywallFeatureRow(
                    systemImage: "rectangle.split.3x1",
                    title: "Compare side by side",
                    subtitle: "See score, sugar, salt, fat, protein, and fiber in one calm view.",
                    fill: PicklyColor.ratingOkayFill
                )
            }
        }
        .padding(PaywallSpacing.cardInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyGlassCardSurface(cornerRadius: 24)
    }

    private var alternativesFeatureSubtitle: String {
        switch entryPoint {
        case .general:
            PicklyCopy.localized("Get current goal-based and related matches as Pickly's catalog evolves.")
        case .alternatives:
            PicklyCopy.localized("Get current higher-scoring matches for this item as catalog data evolves.")
        }
    }

    private var activeSubscriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Pickly Plus is ready", picklyIcon: "checkmark.seal.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PicklyColor.primary)

            Text("Your subscription keeps live catalog matches unlocked. Compare products side by side whenever current product data supports it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            restoreButton
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(
            cornerRadius: 20,
            fill: PicklyColor.ratingGoodFill.opacity(0.74),
            stroke: PicklyColor.primary.opacity(0.2)
        )
    }

    private var unavailableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                subscriptionStore.isLoading ? "Loading Pickly Plus" : "Pickly Plus is unavailable",
                systemImage: subscriptionStore.isLoading ? "arrow.clockwise" : "icloud.slash"
            )
            .font(.headline.weight(.semibold))

            if subscriptionStore.isLoading {
                ProgressView()
                    .tint(PicklyColor.primary)
            } else {
                Text("Product scores and explanations remain free. Try again when the App Store is reachable to unlock alternatives.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Try again") {
                    Task {
                        await subscriptionStore.refresh()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(PicklyColor.primary)
                .picklyProminentButtonForeground()
                .disabled(subscriptionStore.isLoading)
            }

            restoreButton

            if let statusMessage = subscriptionStore.statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyGlassCardSurface(cornerRadius: 20)
    }

    private var restoreButton: some View {
        Button {
            Task {
                await subscriptionStore.restorePurchases()
            }
        } label: {
            Text(subscriptionStore.isPurchasing ? "Restoring…" : "Restore Purchases")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(subscriptionStore.isPurchasing)
        .accessibilityHint("Syncs your Pickly Plus purchases with the App Store.")
    }

    private var termsAndPrivacy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment is charged to your Apple ID at confirmation of purchase.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. You can manage or cancel in Apple ID settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink("How scoring works") {
                ScoringMethodologyView()
            }

            HStack(spacing: 12) {
                NavigationLink("Privacy Policy") {
                    PrivacyPolicyView()
                }

                Link(
                    "Apple Standard EULA",
                    destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
                )
            }
            .font(.footnote.weight(.semibold))
        }
        .font(.footnote.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeroValueChip: View {
    let title: String
    let foreground: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                .white.opacity(0.22),
                in: Capsule()
            )
    }
}

private struct PaywallFeatureRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let fill: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PicklyIconImage(systemName: systemImage, size: 18)
                .foregroundStyle(PicklyColor.onBrandAccent)
                .frame(width: 32, height: 32)
                .background(fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PicklyPaywallView()
        .environmentObject(SubscriptionStore(loadProducts: false))
}
