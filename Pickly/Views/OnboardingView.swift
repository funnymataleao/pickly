import SwiftUI
import Foundation

#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    let onComplete: () -> Void
    @Binding var preferences: UserPreferences
    @ObservedObject var authStore: AuthStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedPage = 0

    private let pageCount = 4
    private let headerControlSize: CGFloat = 36
    private let continueButtonInset: CGFloat = 96

    init(
        onComplete: @escaping () -> Void,
        preferences: Binding<UserPreferences> = .constant(.prototype),
        authStore: AuthStore
    ) {
        self.onComplete = onComplete
        _preferences = preferences
        self.authStore = authStore

#if DEBUG
        if let argumentIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-pickly-onboarding-page"),
           let rawPage = ProcessInfo.processInfo.arguments.dropFirst(argumentIndex + 1).first,
           let page = Int(rawPage) {
            _selectedPage = State(initialValue: min(max(page, 0), 3))
        }
#endif
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedPage) {
                OnboardingCarouselPage(isActive: selectedPage == 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaPadding(.bottom, continueButtonInset)
                    .tag(0)

                OnboardingResultPage(isActive: selectedPage == 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaPadding(.bottom, continueButtonInset)
                    .tag(1)

                OnboardingPreferencesPage(preferences: $preferences)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaPadding(.bottom, continueButtonInset)
                    .tag(2)

                OnboardingAuthPage(
                    authStore: authStore,
                    onComplete: onComplete
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaPadding(.bottom, continueButtonInset)
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Keep the custom header under the status bar. Every page reserves
            // the same bottom overlay footprint, including the auth footer.
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                header
                Spacer()
            }

        }
        .overlay(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                continueButton
                    .opacity(selectedPage < pageCount - 1 ? 1 : 0)
                    .allowsHitTesting(selectedPage < pageCount - 1)
                    .disabled(selectedPage >= pageCount - 1)
                    .accessibilityHidden(selectedPage >= pageCount - 1)

                continueWithoutAccountButton
                    .opacity(selectedPage == pageCount - 1 ? 1 : 0)
                    .allowsHitTesting(selectedPage == pageCount - 1)
                    .disabled(selectedPage != pageCount - 1)
                    .accessibilityHidden(selectedPage != pageCount - 1)
            }
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.16),
                value: selectedPage
            )
        }
        .background(PicklyColor.background.ignoresSafeArea())
        .interactiveDismissDisabled()
    }

    private var continueButton: some View {
        Button(action: advance) {
            Text("Continue")
                .font(dynamicTypeSize.isAccessibilitySize ? .body.weight(.semibold) : .headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 34)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(PicklyColor.primary)
        .picklyProminentButtonForeground()
        .accessibilityHint("Shows the next introduction page.")
        .frame(maxWidth: .infinity)
        .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
        // Keep the CTA visually separated from the page copy while the
        // bottom safe-area inset remains aligned with the horizontal margins.
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var continueWithoutAccountButton: some View {
        Button(action: skipOnboarding) {
            HStack(spacing: 6) {
                Text("Continue without account")
                    .font(.body.weight(.semibold))
                PicklyIconImage(
                    systemName: "chevron.right",
                    size: 13,
                    scalesWithDynamicType: false
                )
            }
            .foregroundStyle(PicklyColor.primary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityHint("Finishes setup without creating an account.")
        .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private var header: some View {
        Group {
            ZStack {
                pageIndicator

                HStack {
                    if selectedPage > 0 {
                        Button(action: goBack) {
                            PicklyIconImage(
                                systemName: "chevron.left",
                                size: 18,
                                scalesWithDynamicType: false
                            )
                                .foregroundStyle(selectedPage == pageCount - 1 ? Color.primary : PicklyColor.primary)
                        }
                        .frame(width: headerControlSize, height: headerControlSize)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Back")
                        .accessibilityHint("Goes to the previous page.")
                    } else {
                        Color.clear
                            .frame(width: headerControlSize, height: headerControlSize)
                            .accessibilityHidden(true)
                    }

                    Spacer()

                    if selectedPage < pageCount - 1 {
                        Button("Skip", action: skipToAccount)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(PicklyColor.primary)
                            .accessibilityHint("Shows account options.")
                    } else {
                        Button("Skip", action: skipOnboarding)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .accessibilityHint("Finishes setup without creating an account.")
                    }
                }
                // Keep the header's vertical footprint stable while the Back
                // control appears on the second page.
                .frame(minHeight: headerControlSize)
            }
            .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 4 : 10)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == selectedPage ? PicklyColor.primary : PicklyColor.stroke)
                    .frame(width: 28, height: 7)
            }
        }
        // Critically damped motion keeps the indicator responsive without
        // adding a second, competing easing curve to the page transition.
        .animation(
            reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 1),
            value: selectedPage
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(selectedPage + 1) of \(pageCount)")
    }

    private func advance() {
        playImpactHaptic()

        if reduceMotion {
            selectedPage += 1
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 1)) {
                selectedPage += 1
            }
        }
    }

    private func skipToAccount() {
        playImpactHaptic()

        // Skip is a direct route to auth. Do not animate through the
        // intermediate carousel pages; that produces a long, artificial
        // page sweep and makes the destination feel unstable.
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            selectedPage = pageCount - 1
        }
    }

    private func goBack() {
        playImpactHaptic()

        if reduceMotion {
            selectedPage -= 1
        } else {
            withAnimation(.spring(response: 0.38, dampingFraction: 1)) {
                selectedPage -= 1
            }
        }
    }

    private func skipOnboarding() {
        playImpactHaptic()
        onComplete()
    }

    private func playImpactHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
}

#Preview {
    OnboardingView(
        onComplete: {},
        authStore: AuthStore()
    )
}
