import AuthenticationServices
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct AuthProviderButtons: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var authStore: AuthStore

    var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { request in
                authStore.configureAppleRequest(request)
            } onCompletion: { result in
                Task {
                    await authStore.completeAppleSignIn(result)
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .disabled(!authStore.isConfigured || authStore.isWorking)
            .accessibilityHint("Creates or opens your Pickly account using your Apple Account.")

            Button {
                Task {
                    await authStore.signInWithGoogle()
                }
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
        }
    }
}

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

struct AuthProviderButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
            .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
            .background(
                colorScheme == .dark ? Color.white.opacity(0.08) : Color.white,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PicklyColor.stroke.opacity(isEnabled ? 0.72 : 0.42), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.78 : isEnabled ? 1 : 0.58)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 1),
                value: configuration.isPressed
            )
    }
}
