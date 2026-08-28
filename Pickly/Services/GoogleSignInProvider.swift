import Foundation
import GoogleSignIn
import UIKit

struct GoogleIdentityTokens {
    let idToken: String
    let accessToken: String
}

enum GoogleSignInProviderError: LocalizedError {
    case missingConfiguration
    case missingPresenter
    case missingIDToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return PicklyCopy.localized("Google sign-in is not configured yet.")
        case .missingPresenter:
            return PicklyCopy.localized("Google sign-in could not be presented. Please try again.")
        case .missingIDToken:
            return PicklyCopy.localized("Google did not return a valid identity token.")
        case .cancelled:
            return nil
        }
    }
}

@MainActor
protocol GoogleSignInProviding {
    var isConfigured: Bool { get }

    func signIn(nonce: String) async throws -> GoogleIdentityTokens
    func signOut()
    func disconnect() async throws
}

@MainActor
struct GoogleSignInProvider: GoogleSignInProviding {
    nonisolated private static let cancelledErrorCode = -5

    var isConfigured: Bool {
        GoogleSignInConfiguration.isConfigured
    }

    func signIn(nonce: String) async throws -> GoogleIdentityTokens {
        guard
            isConfigured,
            let iOSClientID = GoogleSignInConfiguration.iosClientID,
            let serverClientID = GoogleSignInConfiguration.serverClientID
        else {
            throw GoogleSignInProviderError.missingConfiguration
        }

        guard let presenter = Self.presentingViewController else {
            throw GoogleSignInProviderError.missingPresenter
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: iOSClientID,
            serverClientID: serverClientID
        )

        let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter,
                hint: nil,
                additionalScopes: nil,
                nonce: nonce
            ) { result, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == kGIDSignInErrorDomain,
                       nsError.code == Self.cancelledErrorCode {
                        continuation.resume(throwing: GoogleSignInProviderError.cancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: GoogleSignInProviderError.missingIDToken)
                }
            }
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw GoogleSignInProviderError.missingIDToken
        }

        return GoogleIdentityTokens(
            idToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    func disconnect() async throws {
        guard GIDSignIn.sharedInstance.currentUser != nil else {
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            GIDSignIn.sharedInstance.disconnect { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    static func handle(url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }

    private static var presentingViewController: UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        var presenter = window?.rootViewController
        while let presented = presenter?.presentedViewController {
            presenter = presented
        }

        if let navigationController = presenter as? UINavigationController {
            return navigationController.visibleViewController ?? navigationController
        }
        if let tabBarController = presenter as? UITabBarController {
            return tabBarController.selectedViewController ?? tabBarController
        }

        return presenter
    }
}
