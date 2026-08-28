import SwiftUI
import AuthenticationServices

#if canImport(UIKit)
import UIKit
#endif

struct OnboardingAuthPage: View {
    @ObservedObject var authStore: AuthStore
    let onComplete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @State private var isEmailAuthPresented = false

    // Keep the complete auth choice set above the fold on an iPhone-sized
    // viewport. Larger Dynamic Type still gets a scroll fallback below.
    private let heroHeightRatio: CGFloat = 0.44
    // Match the bottom breathing room of the shared onboarding CTA. This
    // shifts foreground content down while the hero image stays anchored.
    private let foregroundVerticalOffset: CGFloat = 88

    var body: some View {
        GeometryReader { geometry in
            if dynamicTypeSize.isAccessibilitySize || geometry.size.height < 760 {
                // Accessibility sizes and compact devices may genuinely need
                // more vertical space; preserve readable text there.
                ScrollView {
                    pageContent(in: geometry, constrainedToViewport: false)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            } else {
                // The normal path is a single, non-scrolling auth surface:
                // every provider and the guest action remain visible together.
                pageContent(in: geometry, constrainedToViewport: true)
            }
        }
        .background(PicklyColor.background.ignoresSafeArea())
        .task {
            await authStore.restoreSessionIfNeeded()
            completeIfSignedIn(authStore.state)
        }
        .onChange(of: authStore.state) { _, state in
            completeIfSignedIn(state)
        }
        .sheet(isPresented: $isEmailAuthPresented) {
            AccountAuthView(
                authStore: authStore,
                onAccountDeleted: {},
                showsSocialProviders: false
            )
        }
    }

    @ViewBuilder
    private func pageContent(
        in geometry: GeometryProxy,
        constrainedToViewport: Bool
    ) -> some View {
        let imageHeight = geometry.size.height * heroHeightRatio
        let heroSectionHeight = imageHeight + foregroundVerticalOffset

        VStack(spacing: 0) {
            // MARK: – Background image + hero overlay
            ZStack(alignment: .topLeading) {
                Image("OnboardingAuthBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: geometry.size.width,
                        height: imageHeight
                    )
                    .clipped()

                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    hero
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                }
                .frame(
                    width: geometry.size.width,
                    height: heroSectionHeight,
                    alignment: .bottomLeading
                )
            }
            .frame(
                width: geometry.size.width,
                height: heroSectionHeight
            )

            // MARK: – Auth actions
            VStack(spacing: 0) {
                if authStore.isRestoringSession {
                    restoringSession
                } else {
                    accountContent
                }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .frame(maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: .infinity)
        }
        .frame(
            width: geometry.size.width,
            height: constrainedToViewport ? geometry.size.height : nil,
            alignment: .top
        )
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.15)
                          : Color.white.opacity(0.9))

                PicklyIconImage(
                    systemName: "barcode.viewfinder.fill",
                    size: 34,
                    scalesWithDynamicType: false
                )
                .foregroundStyle(PicklyColor.primary)
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Welcome to")
                        .foregroundStyle(.primary)
                    Text("Pickly")
                        .foregroundStyle(PicklyColor.primary)
                }
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)

                Text("Sign in to manage your Pickly account. Saved products and preferences stay on this device.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Account content

    @ViewBuilder
    private var accountContent: some View {
        switch authStore.state {
        case .signedOut:
            signInMethods
        case .signedIn:
            ProgressView("Opening Pickly...")
                .frame(maxWidth: .infinity, alignment: .leading)
        case .needsEmailConfirmation(let email):
            confirmationContent(email: email)
        }
    }

    // MARK: - Sign-in methods

    private var signInMethods: some View {
        VStack(spacing: 10) {
            SignInWithAppleButton(.continue) { request in
                authStore.configureAppleRequest(request)
            } onCompletion: { result in
                Task { await authStore.completeAppleSignIn(result) }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(!authStore.isConfigured || authStore.isWorking)
            .accessibilityHint("Creates or opens your Pickly account using your Apple Account.")

            Button {
                Task { await authStore.signInWithGoogle() }
            } label: {
                HStack(spacing: 11) {
                    GoogleBrandMark()
                    Text("Continue with Google")
                        .font(.headline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(AuthProviderButtonStyle())
            .disabled(!authStore.isGoogleConfigured || authStore.isWorking)
            .accessibilityHint("Creates or opens your Pickly account using Google.")

            HStack(spacing: 12) {
                Rectangle()
                    .fill(PicklyColor.stroke.opacity(0.5))
                    .frame(height: 1)
                Text("or")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(PicklyColor.stroke.opacity(0.5))
                    .frame(height: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Or continue with email")

            Button {
                isEmailAuthPresented = true
            } label: {
                HStack(spacing: 10) {
                    PicklyIconImage(systemName: "envelope.fill", size: 18)
                        .foregroundStyle(PicklyColor.primary)
                    Text("Continue with email")
                        .font(.headline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(AuthProviderButtonStyle())
            .disabled(!authStore.isConfigured || authStore.isWorking)
            .accessibilityHint("Opens email account creation and sign in.")

            if !authStore.isConfigured {
                statusMessage("Account access is unavailable right now. You can continue without an account.")
            } else if let message = authStore.statusMessage {
                statusMessage(message)
            }

            privacyNote
        }
    }

    // MARK: - Confirmation

    private func confirmationContent(email: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Check your email")
                    .font(.title2.bold())
                Text("We sent a confirmation link to \(email). After confirming, return here and sign in.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Sign in with email") {
                isEmailAuthPresented = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(PicklyColor.primary)
            .picklyProminentButtonForeground()

        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(cornerRadius: 20, stroke: PicklyColor.stroke.opacity(0.5))
    }

    // MARK: - Privacy note

    private var privacyNote: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.12)
                          : PicklyColor.mint.opacity(0.35))
                PicklyIconImage(
                    systemName: "lock.shield.fill",
                    size: 24,
                    scalesWithDynamicType: false
                )
                .foregroundStyle(PicklyColor.primary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("Authentication is handled securely by Firebase.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Saved products and preferences stay on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Keep the privacy copy inline with the auth surface instead of
        // introducing a second white card that reads like a bottom sheet.
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Restoring

    private var restoringSession: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Restoring account session...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Status message

    private func statusMessage(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            PicklyIconImage(systemName: "info.circle.fill", size: 18)
                .foregroundStyle(PicklyColor.primary)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func completeIfSignedIn(_ state: AuthStore.State) {
        guard case .signedIn = state else { return }
        onComplete()
    }
}

// MARK: - Google Brand Mark

private struct GoogleBrandMark: View {
    var body: some View {
        Group {
            #if canImport(UIKit)
            if let image = GoogleBrandAsset.image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                fallback
            }
            #else
            fallback
            #endif
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Text("G")
            .font(.headline.weight(.bold))
            .foregroundStyle(.blue)
    }
}

#if canImport(UIKit)
private enum GoogleBrandAsset {
    static let image: UIImage? = {
        let resourceBundles = Bundle.main.urls(
            forResourcesWithExtension: "bundle",
            subdirectory: nil
        ) ?? []
        for bundleURL in resourceBundles where bundleURL.lastPathComponent.contains("GoogleSignIn") {
            guard let bundle = Bundle(url: bundleURL),
                  let image = UIImage(named: "google", in: bundle, compatibleWith: nil) else {
                continue
            }
            return image
        }
        return nil
    }()
}
#endif

#Preview {
    OnboardingAuthPage(
        authStore: AuthStore(),
        onComplete: {}
    )
    .environmentObject(SubscriptionStore(loadProducts: false))
}
