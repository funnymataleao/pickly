import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security

@MainActor
final class AuthStore: ObservableObject {
    enum NonceError: LocalizedError, Equatable {
        case invalidLength
        case secureRandomUnavailable(OSStatus)

        var errorDescription: String? {
            "Secure sign-in couldn't start. Please try again."
        }
    }

    enum State: Equatable {
        case signedOut
        case signedIn(AuthSession)
        case needsEmailConfirmation(String)
    }

    @Published private(set) var state: State = .signedOut
    @Published private(set) var isWorking = false
    @Published private(set) var isRestoringSession = true
    @Published private(set) var requiresAppleReauthentication = false
    @Published var statusMessage: String?

    private let service: AuthService
    private let googleSignInProvider: GoogleSignInProviding
    private var appleRawNonce: String?
    private var appleDeletionRawNonce: String?
    private var hasAttemptedSessionRestore = false

    var isConfigured: Bool {
        service.isConfigured
    }

    var isGoogleConfigured: Bool {
        service.isConfigured && googleSignInProvider.isConfigured
    }

    var currentEmail: String? {
        switch state {
        case .signedOut:
            return nil
        case .signedIn(let session):
            return session.user.email
        case .needsEmailConfirmation(let email):
            return email
        }
    }

    init(
        service: AuthService? = nil,
        googleSignInProvider: GoogleSignInProviding? = nil
    ) {
        self.service = service ?? FirebaseAuthService()
        self.googleSignInProvider = googleSignInProvider ?? GoogleSignInProvider()
    }

    /// Restores an existing account only when the account surface is opened.
    /// Authentication must not delay the first useful app frame.
    func restoreSessionIfNeeded() async {
        guard !hasAttemptedSessionRestore else { return }
        hasAttemptedSessionRestore = true
        await restoreSession()
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let rawNonce = try Self.randomNonce()
            appleRawNonce = rawNonce
            statusMessage = nil

            request.requestedScopes = [.email, .fullName]
            request.nonce = Self.sha256(rawNonce)
        } catch {
            appleRawNonce = nil
            statusMessage = Self.nonceErrorMessage(error)
        }
    }

    /// Starts a fresh Sign in with Apple request for the destructive account
    /// deletion flow. The nonce is kept only in memory until the callback is
    /// validated; authorization codes are never persisted for this purpose.
    func configureAppleDeletionRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let rawNonce = try Self.randomNonce()
            appleDeletionRawNonce = rawNonce
            statusMessage = nil
            request.nonce = Self.sha256(rawNonce)
        } catch {
            appleDeletionRawNonce = nil
            statusMessage = Self.nonceErrorMessage(error)
        }
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        guard !isWorking else { return }

        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthServiceError.invalidResponse
            }
            guard
                let identityToken = credential.identityToken,
                let idToken = String(data: identityToken, encoding: .utf8),
                let rawNonce = appleRawNonce
            else {
                throw AuthServiceError.invalidResponse
            }

            appleRawNonce = nil
            await runAuthTask {
                let session = try await service.signIn(
                    with: IdentityTokenCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: rawNonce,
                        fullName: credential.fullName
                    )
                )
                state = .signedIn(session)
                requiresAppleReauthentication = false
                statusMessage = PicklyCopy.localized("Signed in with Apple.")
            }
        } catch let error as ASAuthorizationError {
            appleRawNonce = nil

            // Cancelling the system sheet is an expected exit. Clear any
            // stale message so the onboarding surface returns to its normal
            // layout and keeps the guest action available.
            guard error.code != .canceled else {
                statusMessage = nil
                return
            }

#if targetEnvironment(simulator)
            // Sign in with Apple is not available in the iOS Simulator. Do
            // not replace the usable email/Google/guest choices with a
            // diagnostic card when the user taps the Apple button here.
            guard error.code != .unknown else {
                statusMessage = nil
                return
            }
#endif

            statusMessage = Self.appleAuthorizationErrorMessage(error)
        } catch {
            appleRawNonce = nil
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Completes the destructive Apple reauthentication flow. A failed
    /// attempt intentionally keeps the session and the confirmation card
    /// visible so the user can retry without signing out first.
    func completeAppleAccountDeletion(_ result: Result<ASAuthorization, Error>) async -> Bool {
        guard !isWorking else { return false }
        guard
            requiresAppleReauthentication,
            let session = currentSession,
            session.identityProvider == .apple
        else {
            statusMessage = PicklyCopy.localized("Confirm with Apple before deleting your account.")
            return false
        }

        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthServiceError.invalidResponse
            }
            guard
                let identityToken = credential.identityToken,
                let idToken = String(data: identityToken, encoding: .utf8),
                let rawNonce = appleDeletionRawNonce,
                let authorizationCode = credential.authorizationCode
                    .flatMap({ String(data: $0, encoding: .utf8) }),
                !authorizationCode.isEmpty
            else {
                throw AuthServiceError.invalidResponse
            }

            appleDeletionRawNonce = nil
            isWorking = true
            statusMessage = nil
            defer { isWorking = false }

            try await service.deleteAccount(
                session: session,
                appleAuthorizationCode: authorizationCode,
                identityToken: idToken,
                rawNonce: rawNonce
            )
            finishAccountDeletion(for: session)
            return true
        } catch let error as ASAuthorizationError {
            appleDeletionRawNonce = nil
            guard error.code != .canceled else {
                statusMessage = nil
                return false
            }

#if targetEnvironment(simulator)
            guard error.code != .unknown else {
                statusMessage = nil
                return false
            }
#endif

            statusMessage = Self.appleAuthorizationErrorMessage(error)
            return false
        } catch {
            appleDeletionRawNonce = nil
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func signInWithGoogle() async {
        let rawNonce: String
        do {
            rawNonce = try Self.randomNonce()
        } catch {
            statusMessage = Self.nonceErrorMessage(error)
            return
        }
        let hashedNonce = Self.sha256(rawNonce)

        await runAuthTask {
            let tokens = try await googleSignInProvider.signIn(nonce: hashedNonce)
            let session = try await service.signIn(
                with: IdentityTokenCredentials(
                    provider: .google,
                    idToken: tokens.idToken,
                    accessToken: tokens.accessToken,
                    nonce: rawNonce
                )
            )
            state = .signedIn(session)
            requiresAppleReauthentication = false
            statusMessage = PicklyCopy.localized("Signed in with Google.")
        }
    }

    func signUp(email: String, password: String) async {
        await runAuthTask {
            switch try await service.signUp(email: email, password: password) {
            case .signedIn(let session):
                state = .signedIn(session)
                requiresAppleReauthentication = false
                statusMessage = PicklyCopy.localized("Account created.")
            case .confirmationRequired(let email):
                state = .needsEmailConfirmation(email)
                statusMessage = PicklyCopy.localized("Check your email to confirm your account.")
            }
        }
    }

    func signIn(email: String, password: String) async {
        await runAuthTask {
            let session = try await service.signIn(email: email, password: password)
            state = .signedIn(session)
            requiresAppleReauthentication = false
            statusMessage = PicklyCopy.localized("Signed in.")
        }
    }

    func requestPasswordReset(email: String) async {
        await runAuthTask {
            try await service.requestPasswordReset(email: email)
            statusMessage = PicklyCopy.localized("Check your email for a secure password reset link, then return to Pickly to sign in.")
        }
    }

    func signOut() async {
        let session = currentSession
        state = .signedOut
        requiresAppleReauthentication = false
        appleDeletionRawNonce = nil
        googleSignInProvider.signOut()

        guard let session else {
            statusMessage = PicklyCopy.localized("Signed out.")
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            try await service.signOut(session: session)
            statusMessage = PicklyCopy.localized("Signed out.")
        } catch {
            statusMessage = PicklyCopy.localized("Signed out on this device. Reconnect to end the server session.")
        }
    }

    func deleteAccount() async -> Bool {
        guard let session = currentSession else {
            return false
        }

        if session.identityProvider == .apple {
            requiresAppleReauthentication = true
            appleDeletionRawNonce = nil
            statusMessage = PicklyCopy.localized("For your security, confirm with Apple before deleting your account.")
            return false
        }

        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            try await service.deleteAccount(session: session)
            finishAccountDeletion(for: session)
            return true
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    private func finishAccountDeletion(for session: AuthSession) {
        // Server and provider deletion are complete. Reflect the durable
        // success in the UI and clear any local provider state.
        state = .signedOut
        requiresAppleReauthentication = false
        appleDeletionRawNonce = nil
        statusMessage = PicklyCopy.localized("Your account was deleted.")

        if session.identityProvider == .google {
            Task { @MainActor [googleSignInProvider] in
                try? await googleSignInProvider.disconnect()
                googleSignInProvider.signOut()
            }
        } else {
            googleSignInProvider.signOut()
        }
    }

    private func restoreSession() async {
        defer { isRestoringSession = false }

        do {
            if let session = try await service.restoreSession() {
                state = .signedIn(session)
                requiresAppleReauthentication = false
                appleDeletionRawNonce = nil
            }
        } catch {
            state = .signedOut
        }
    }

    private static func appleAuthorizationErrorMessage(_ error: ASAuthorizationError) -> String {
        guard error.code == .unknown else {
            return PicklyCopy.localized("Apple sign-in couldn't be completed. Please try again.")
        }

#if targetEnvironment(simulator)
        return PicklyCopy.localized("Sign in with Apple isn't available in this Simulator. Use email or Google here, or test Apple sign-in on a real iPhone.")
#else
        return PicklyCopy.localized("Apple sign-in couldn't start. Make sure this iPhone is signed in to iCloud, then try again.")
#endif
    }

    var currentSession: AuthSession? {
        switch state {
        case .signedIn(let session):
            return session
        case .signedOut, .needsEmailConfirmation:
            return nil
        }
    }

    private func runAuthTask(_ operation: () async throws -> Void) async {
        guard !isWorking else { return }

        isWorking = true
        statusMessage = nil

        do {
            try await operation()
        } catch GoogleSignInProviderError.cancelled {
            // User cancellation is an expected exit, not an authentication error.
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isWorking = false
    }

    private static func randomNonce(length: Int = 32) throws -> String {
        try makeNonce(length: length) {
            var randomByte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &randomByte)
            guard status == errSecSuccess else {
                throw NonceError.secureRandomUnavailable(status)
            }
            return randomByte
        }
    }

    static func makeNonce(
        length: Int,
        randomByte: () throws -> UInt8
    ) throws -> String {
        guard length > 0 else {
            throw NonceError.invalidLength
        }

        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)

        while result.count < length {
            let byte = try randomByte()

            if Int(byte) < characters.count {
                result.append(characters[Int(byte)])
            }
        }

        return result
    }

    private static func nonceErrorMessage(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? "Secure sign-in couldn't start. Please try again."
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
