import Auth
import Foundation

struct AuthUser: Equatable, Codable {
    let id: String
    let email: String?
}

struct AuthSession: Equatable, Codable {
    let accessToken: String
    let refreshToken: String?
    let user: AuthUser
    /// Provider used for this session, when it is known locally.
    /// Optional keeps sessions created by older builds decodable.
    let identityProvider: AuthIdentityProvider?

    init(
        accessToken: String,
        refreshToken: String?,
        user: AuthUser,
        identityProvider: AuthIdentityProvider? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.user = user
        self.identityProvider = identityProvider
    }
}

enum EmailAuthResult: Equatable {
    case signedIn(AuthSession)
    case confirmationRequired(email: String)
}

enum AuthIdentityProvider: String, Codable, Equatable {
    case apple
    case google
}

struct IdentityTokenCredentials {
    let provider: AuthIdentityProvider
    let idToken: String
    let accessToken: String?
    let nonce: String?
    let fullName: PersonNameComponents?

    init(
        provider: AuthIdentityProvider,
        idToken: String,
        accessToken: String? = nil,
        nonce: String? = nil,
        fullName: PersonNameComponents? = nil
    ) {
        self.provider = provider
        self.idToken = idToken
        self.accessToken = accessToken
        self.nonce = nonce
        self.fullName = fullName
    }
}

enum AuthServiceError: LocalizedError, Equatable {
    case missingConfiguration
    case invalidResponse
    case requestFailed(String)
    case secureStorageFailed
    case accountDeletionUnavailable

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Account features are not configured yet."
        case .invalidResponse:
            return "Account service returned an unexpected response."
        case .requestFailed(let message):
            return message
        case .secureStorageFailed:
            return "The secure session could not be saved on this device."
        case .accountDeletionUnavailable:
            return "Account deletion is not configured on the server yet."
        }
    }
}

protocol AuthService {
    var isConfigured: Bool { get }

    func restoreSession() async throws -> AuthSession?
    func signUp(email: String, password: String) async throws -> EmailAuthResult
    func signIn(email: String, password: String) async throws -> AuthSession
    func requestPasswordReset(email: String) async throws
    func completePasswordRecovery(from url: URL) async throws -> AuthSession
    func updatePassword(_ password: String) async throws -> AuthSession
    func signIn(with credentials: IdentityTokenCredentials) async throws -> AuthSession
    func storeAppleAuthorizationCode(_ authorizationCode: String, session: AuthSession) async throws
    func signOut(session: AuthSession) async throws
    func deleteAccount(session: AuthSession) async throws
}

struct SupabaseAuthService: AuthService {
    private static let legacyKeychainAccount = "supabase-session"
    private static let keychainService = "com.pickly.app.auth"
    private static let passwordRecoveryRedirectURL = URL(string: "pickly://auth/reset-password")!

    private let client: AuthClient?

    var isConfigured: Bool {
        client != nil
    }

    init() {
        guard
            let projectURL = SupabaseCredentials.projectURL,
            SupabaseCredentials.isConfigured
        else {
            client = nil
            return
        }

        let projectReference = projectURL.host?.split(separator: ".").first.map(String.init)

        client = AuthClient(
            url: projectURL.appendingPathComponent("auth/v1"),
            headers: [
                "apikey": SupabaseCredentials.publishableKey,
                "Authorization": "Bearer \(SupabaseCredentials.publishableKey)"
            ],
            storageKey: projectReference.map { "sb-\($0)-auth-token" },
            localStorage: KeychainLocalStorage(service: Self.keychainService),
            autoRefreshToken: true
        )
    }

    func restoreSession() async throws -> AuthSession? {
        let client = try configuredClient()

        if client.currentSession != nil {
            do {
                return Self.makeSession(from: try await client.session)
            } catch {
                try? await client.signOut(scope: .local)
                return nil
            }
        }

        guard
            let legacySession = try loadLegacySession(),
            let refreshToken = legacySession.refreshToken
        else {
            return nil
        }

        do {
            let session = try await client.setSession(
                accessToken: legacySession.accessToken,
                refreshToken: refreshToken
            )
            KeychainStore.remove(account: Self.legacyKeychainAccount)
            return Self.makeSession(from: session)
        } catch {
            KeychainStore.remove(account: Self.legacyKeychainAccount)
            return nil
        }
    }

    func signUp(email: String, password: String) async throws -> EmailAuthResult {
        let response = try await configuredClient().signUp(email: email, password: password)

        if let session = response.session {
            return .signedIn(Self.makeSession(from: session))
        }

        return .confirmationRequired(email: email)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let session = try await configuredClient().signIn(email: email, password: password)
        return Self.makeSession(from: session)
    }

    func requestPasswordReset(email: String) async throws {
        try await configuredClient().resetPasswordForEmail(
            email,
            redirectTo: Self.passwordRecoveryRedirectURL
        )
    }

    func completePasswordRecovery(from url: URL) async throws -> AuthSession {
        let session = try await configuredClient().session(from: url)
        return Self.makeSession(from: session)
    }

    func updatePassword(_ password: String) async throws -> AuthSession {
        let client = try configuredClient()
        _ = try await client.update(user: UserAttributes(password: password))
        return Self.makeSession(from: try await client.session)
    }

    func signIn(with credentials: IdentityTokenCredentials) async throws -> AuthSession {
        let client = try configuredClient()
        let provider: OpenIDConnectCredentials.Provider = switch credentials.provider {
        case .apple: .apple
        case .google: .google
        }

        let session = try await client.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: provider,
                idToken: credentials.idToken,
                accessToken: credentials.accessToken,
                nonce: credentials.nonce
            )
        )

        if credentials.provider == .apple, let fullName = credentials.fullName {
            await updateAppleNameIfAvailable(fullName, using: client)
        }

        return Self.makeSession(from: (try? await client.session) ?? session, provider: credentials.provider)
    }

    func storeAppleAuthorizationCode(_ authorizationCode: String, session: AuthSession) async throws {
        _ = try await performRequest(
            url: SupabaseCredentials.appleTokenFunctionURL,
            method: "POST",
            body: try JSONSerialization.data(withJSONObject: [
                "authorization_code": authorizationCode
            ]),
            accessToken: session.accessToken
        )
    }

    func signOut(session: AuthSession) async throws {
        try await configuredClient().signOut()
    }

    func deleteAccount(session: AuthSession) async throws {
        let client = try configuredClient()
        let activeSession = try await client.session

        do {
            _ = try await performRequest(
                url: SupabaseCredentials.accountDeletionFunctionURL,
                method: "POST",
                body: Data("{}".utf8),
                accessToken: activeSession.accessToken
            )
            try? await client.signOut(scope: .local)
        } catch AuthServiceError.requestFailed(let message) where message.contains("404") {
            throw AuthServiceError.accountDeletionUnavailable
        }
    }

    private func configuredClient() throws -> AuthClient {
        guard let client else {
            throw AuthServiceError.missingConfiguration
        }

        return client
    }

    private func loadLegacySession() throws -> AuthSession? {
        do {
            return try KeychainStore.load(AuthSession.self, account: Self.legacyKeychainAccount)
        } catch {
            throw AuthServiceError.secureStorageFailed
        }
    }

    private func updateAppleNameIfAvailable(
        _ name: PersonNameComponents,
        using client: AuthClient
    ) async {
        let parts = [name.givenName, name.middleName, name.familyName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return }

        var metadata: [String: AnyJSON] = [
            "full_name": .string(parts.joined(separator: " "))
        ]
        if let givenName = name.givenName, !givenName.isEmpty {
            metadata["given_name"] = .string(givenName)
        }
        if let familyName = name.familyName, !familyName.isEmpty {
            metadata["family_name"] = .string(familyName)
        }

        _ = try? await client.update(user: UserAttributes(data: metadata))
    }

    private static func makeSession(
        from session: Session,
        provider: AuthIdentityProvider? = nil
    ) -> AuthSession {
        AuthSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            user: AuthUser(
                id: session.user.id.uuidString,
                email: session.user.email
            ),
            identityProvider: provider ?? identityProvider(from: session.user)
        )
    }

    private static func identityProvider(from user: User) -> AuthIdentityProvider? {
        if user.identities?.contains(where: { $0.provider == AuthIdentityProvider.apple.rawValue }) == true {
            return .apple
        }
        if user.identities?.contains(where: { $0.provider == AuthIdentityProvider.google.rawValue }) == true {
            return .google
        }
        return nil
    }

    private func performRequest(
        url: URL?,
        method: String,
        body: Data?,
        accessToken: String
    ) async throws -> Data {
        guard isConfigured, let url else {
            throw AuthServiceError.missingConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseCredentials.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = 20

        let data: Data
        let urlResponse: URLResponse

        do {
            (data, urlResponse) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .cannotFindHost {
            throw AuthServiceError.requestFailed("Account service is unavailable right now.")
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw AuthServiceError.requestFailed("No internet connection.")
        } catch let error as URLError where error.code == .timedOut {
            throw AuthServiceError.requestFailed("Account service took too long. Please try again.")
        } catch {
            throw AuthServiceError.requestFailed("Account service is unavailable right now.")
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw AuthServiceError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data)
            let suffix = errorResponse?.displayMessage ?? "Authentication request failed."
            throw AuthServiceError.requestFailed("\(httpResponse.statusCode): \(suffix)")
        }

        return data
    }
}

private struct SupabaseErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?
    let message: String?
    let msg: String?

    var displayMessage: String? {
        message ?? msg ?? errorDescription ?? error
    }

    private enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
        case message
        case msg
    }
}
