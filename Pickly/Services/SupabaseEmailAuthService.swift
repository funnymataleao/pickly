import Foundation

struct AuthUser: Equatable, Codable {
    let id: String
    let email: String?
}

struct AuthSession: Equatable, Codable {
    let accessToken: String
    let refreshToken: String?
    let user: AuthUser
}

enum EmailAuthResult: Equatable {
    case signedIn(AuthSession)
    case confirmationRequired(email: String)
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

protocol EmailAuthService {
    var isConfigured: Bool { get }

    func restoreSession() async throws -> AuthSession?
    func signUp(email: String, password: String) async throws -> EmailAuthResult
    func signIn(email: String, password: String) async throws -> AuthSession
    func signOut(session: AuthSession) async throws
    func deleteAccount(session: AuthSession) async throws
}

struct SupabaseEmailAuthService: EmailAuthService {
    private static let keychainAccount = "supabase-session"

    var isConfigured: Bool {
        SupabaseCredentials.isConfigured
    }

    func restoreSession() async throws -> AuthSession? {
        guard let storedSession = try loadSession() else {
            return nil
        }

        guard let refreshToken = storedSession.refreshToken else {
            return storedSession
        }

        do {
            return try await refreshSession(storedSession, refreshToken: refreshToken)
        } catch {
            KeychainStore.remove(account: Self.keychainAccount)
            return nil
        }
    }

    func signUp(email: String, password: String) async throws -> EmailAuthResult {
        let response = try await performAuthRequest(
            path: "/auth/v1/signup",
            query: nil,
            body: EmailPasswordRequest(email: email, password: password)
        )

        if let accessToken = response.accessToken, let user = response.user {
            let session = AuthSession(
                accessToken: accessToken,
                refreshToken: response.refreshToken,
                user: AuthUser(id: user.id, email: user.email)
            )
            try saveSession(session)
            return .signedIn(session)
        }

        return .confirmationRequired(email: email)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let response = try await performAuthRequest(
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "password")],
            body: EmailPasswordRequest(email: email, password: password)
        )

        guard
            let accessToken = response.accessToken,
            let refreshToken = response.refreshToken,
            let user = response.user
        else {
            throw AuthServiceError.invalidResponse
        }

        let session = AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            user: AuthUser(id: user.id, email: user.email)
        )
        try saveSession(session)
        return session
    }

    func signOut(session: AuthSession) async throws {
        defer {
            KeychainStore.remove(account: Self.keychainAccount)
        }

        _ = try await performRequest(
            url: SupabaseCredentials.projectURL?.appending(path: "auth/v1/logout"),
            method: "POST",
            body: nil,
            accessToken: session.accessToken
        )
    }

    func deleteAccount(session: AuthSession) async throws {
        guard SupabaseCredentials.isConfigured else {
            throw AuthServiceError.missingConfiguration
        }

        defer {
            KeychainStore.remove(account: Self.keychainAccount)
        }

        do {
            _ = try await performRequest(
                url: SupabaseCredentials.accountDeletionFunctionURL,
                method: "POST",
                body: Data("{}".utf8),
                accessToken: session.accessToken
            )
        } catch AuthServiceError.requestFailed(let message) where message.contains("404") {
            throw AuthServiceError.accountDeletionUnavailable
        }
    }

    private func refreshSession(
        _ previousSession: AuthSession,
        refreshToken: String
    ) async throws -> AuthSession {
        let response = try await performAuthRequest(
            path: "/auth/v1/token",
            query: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: RefreshTokenRequest(refreshToken: refreshToken)
        )

        guard let accessToken = response.accessToken else {
            throw AuthServiceError.invalidResponse
        }

        let session = AuthSession(
            accessToken: accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            user: response.user.map { AuthUser(id: $0.id, email: $0.email) } ?? previousSession.user
        )
        try saveSession(session)
        return session
    }

    private func loadSession() throws -> AuthSession? {
        do {
            return try KeychainStore.load(AuthSession.self, account: Self.keychainAccount)
        } catch {
            throw AuthServiceError.secureStorageFailed
        }
    }

    private func saveSession(_ session: AuthSession) throws {
        do {
            try KeychainStore.save(session, account: Self.keychainAccount)
        } catch {
            throw AuthServiceError.secureStorageFailed
        }
    }

    private func performAuthRequest<Body: Encodable>(
        path: String,
        query: [URLQueryItem]?,
        body: Body
    ) async throws -> SupabaseAuthResponse {
        let data = try await performRequest(
            url: makeURL(path: path, query: query),
            method: "POST",
            body: try JSONEncoder().encode(body),
            accessToken: nil
        )

        do {
            return try JSONDecoder().decode(SupabaseAuthResponse.self, from: data)
        } catch {
            throw AuthServiceError.invalidResponse
        }
    }

    private func performRequest(
        url: URL?,
        method: String,
        body: Data?,
        accessToken: String?
    ) async throws -> Data {
        guard isConfigured, let url else {
            throw AuthServiceError.missingConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SupabaseCredentials.publishableKey, forHTTPHeaderField: "apikey")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let data: Data
        let urlResponse: URLResponse

        do {
            (data, urlResponse) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .cannotFindHost {
            throw AuthServiceError.requestFailed("Account service is unavailable right now.")
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw AuthServiceError.requestFailed("No internet connection.")
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

    private func makeURL(path: String, query: [URLQueryItem]?) -> URL? {
        guard let projectURL = SupabaseCredentials.projectURL else {
            return nil
        }

        var components = URLComponents(
            url: projectURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = query
        return components?.url
    }
}

private struct EmailPasswordRequest: Encodable {
    let email: String
    let password: String
}

private struct RefreshTokenRequest: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

private struct SupabaseAuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let user: SupabaseUser?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

private struct SupabaseUser: Decodable {
    let id: String
    let email: String?
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
