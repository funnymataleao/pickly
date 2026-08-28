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
            return PicklyCopy.localized("Account features are not configured yet.")
        case .invalidResponse:
            return PicklyCopy.localized("Account service returned an unexpected response.")
        case .requestFailed(let message):
            return message
        case .secureStorageFailed:
            return PicklyCopy.localized("The secure session could not be saved on this device.")
        case .accountDeletionUnavailable:
            return PicklyCopy.localized("Account deletion is not configured on the server yet.")
        }
    }
}

protocol AuthService {
    var isConfigured: Bool { get }

    func restoreSession() async throws -> AuthSession?
    func signUp(email: String, password: String) async throws -> EmailAuthResult
    func signIn(email: String, password: String) async throws -> AuthSession
    func requestPasswordReset(email: String) async throws
    func signIn(with credentials: IdentityTokenCredentials) async throws -> AuthSession
    func signOut(session: AuthSession) async throws
    func deleteAccount(session: AuthSession) async throws

    /// Permanently deletes an Apple account after a fresh Sign in with Apple
    /// authorization. Firebase needs both the short-lived authorization code
    /// (to revoke Apple's token) and the nonce-bound identity token (to
    /// reauthenticate the current user before deletion).
    func deleteAccount(
        session: AuthSession,
        appleAuthorizationCode: String,
        identityToken: String,
        rawNonce: String
    ) async throws
}

extension AuthService {
    /// Providers without a native token-revocation implementation must not
    /// silently delete an account without fresh credentials.
    func deleteAccount(
        session: AuthSession,
        appleAuthorizationCode: String,
        identityToken: String,
        rawNonce: String
    ) async throws {
        throw AuthServiceError.accountDeletionUnavailable
    }
}
