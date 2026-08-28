import FirebaseAuth
import Foundation

struct FirebaseAuthService: AuthService {
    private var auth: Auth? {
        FirebaseCredentials.configureIfNeeded() ? Auth.auth() : nil
    }

    var isConfigured: Bool { FirebaseCredentials.isConfigured }

    func restoreSession() async throws -> AuthSession? {
        guard let user = try configuredAuth().currentUser else { return nil }
        return try await makeSession(for: user)
    }

    func signUp(email: String, password: String) async throws -> EmailAuthResult {
        let result = try await configuredAuth().createUser(withEmail: email, password: password)
        try await result.user.sendEmailVerification()
        try configuredAuth().signOut()
        return .confirmationRequired(email: email)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let result = try await configuredAuth().signIn(withEmail: email, password: password)
        guard result.user.isEmailVerified else {
            try? configuredAuth().signOut()
            throw AuthServiceError.requestFailed(PicklyCopy.localized("Confirm your email before signing in."))
        }
        return try await makeSession(for: result.user)
    }

    func requestPasswordReset(email: String) async throws {
        try await configuredAuth().sendPasswordReset(withEmail: email)
    }

    func signIn(with credentials: IdentityTokenCredentials) async throws -> AuthSession {
        let credential: AuthCredential

        switch credentials.provider {
        case .apple:
            guard let nonce = credentials.nonce else {
                throw AuthServiceError.invalidResponse
            }
            credential = OAuthProvider.credential(
                providerID: .apple,
                idToken: credentials.idToken,
                rawNonce: nonce
            )
        case .google:
            guard let accessToken = credentials.accessToken else {
                throw AuthServiceError.invalidResponse
            }
            credential = GoogleAuthProvider.credential(
                withIDToken: credentials.idToken,
                accessToken: accessToken
            )
        }

        let result = try await configuredAuth().signIn(with: credential)
        return try await makeSession(for: result.user, provider: credentials.provider)
    }

    func signOut(session: AuthSession) async throws {
        try configuredAuth().signOut()
    }

    func deleteAccount(session: AuthSession) async throws {
        let user = try currentUser()
        guard user.uid == session.user.id else {
            throw AuthServiceError.invalidResponse
        }

        // Remove Pickly-owned data while the Firebase credential is still
        // valid. If Firebase deletion fails, the account remains retryable.
        let token = try await user.getIDToken(forcingRefresh: true)
        try await deleteRemoteData(accessToken: token)
        try await user.delete()
    }

    func deleteAccount(
        session: AuthSession,
        appleAuthorizationCode: String,
        identityToken: String,
        rawNonce: String
    ) async throws {
        let user = try currentUser()
        guard user.uid == session.user.id else {
            throw AuthServiceError.invalidResponse
        }

        let credential = OAuthProvider.credential(
            providerID: .apple,
            idToken: identityToken,
            rawNonce: rawNonce
        )

        // A fresh Apple credential satisfies Firebase's recent-login
        // requirement and gives us a valid token for the Cloudflare cleanup.
        _ = try await user.reauthenticate(with: credential)
        let token = try await user.getIDToken(forcingRefresh: true)
        try await deleteRemoteData(accessToken: token)

        // Apple authorization codes are short-lived and single-use. Revoke
        // the Apple session before deleting the Firebase account, but only
        // after Pickly data cleanup has succeeded so the whole operation can
        // be retried if the network is unavailable.
        try await configuredAuth().revokeToken(withAuthorizationCode: appleAuthorizationCode)
        try await user.delete()
    }

    private func configuredAuth() throws -> Auth {
        guard let auth else { throw AuthServiceError.missingConfiguration }
        return auth
    }

    private func currentUser() throws -> User {
        guard let user = try configuredAuth().currentUser else {
            throw AuthServiceError.invalidResponse
        }
        return user
    }

    private func makeSession(
        for user: User,
        provider: AuthIdentityProvider? = nil
    ) async throws -> AuthSession {
        AuthSession(
            accessToken: try await user.getIDToken(),
            refreshToken: nil,
            user: AuthUser(id: user.uid, email: user.email),
            identityProvider: provider ?? identityProvider(for: user)
        )
    }

    private func identityProvider(for user: User) -> AuthIdentityProvider? {
        if user.providerData.contains(where: { $0.providerID == "apple.com" }) { return .apple }
        if user.providerData.contains(where: { $0.providerID == "google.com" }) { return .google }
        return nil
    }

    private func deleteRemoteData(accessToken: String) async throws {
        guard let baseURL = PicklyAPIConfiguration.baseURL else {
            throw AuthServiceError.missingConfiguration
        }

        var request = URLRequest(url: baseURL.appending(path: "v1/account/data"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthServiceError.requestFailed(PicklyCopy.localized("Pickly couldn't remove all server data. Your account is still active; please try again."))
        }
    }
}
