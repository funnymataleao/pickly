import Foundation
import Combine

@MainActor
final class AuthStore: ObservableObject {
    enum State: Equatable {
        case signedOut
        case signedIn(AuthSession)
        case needsEmailConfirmation(String)
    }

    @Published private(set) var state: State = .signedOut
    @Published private(set) var isWorking = false
    @Published private(set) var isRestoringSession = true
    @Published var statusMessage: String?

    private let service: EmailAuthService

    var isConfigured: Bool {
        service.isConfigured
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

    init(service: EmailAuthService? = nil) {
        self.service = service ?? SupabaseEmailAuthService()

        Task { [weak self] in
            await self?.restoreSession()
        }
    }

    func signUp(email: String, password: String) async {
        await runAuthTask {
            switch try await service.signUp(email: email, password: password) {
            case .signedIn(let session):
                state = .signedIn(session)
                statusMessage = "Account created."
            case .confirmationRequired(let email):
                state = .needsEmailConfirmation(email)
                statusMessage = "Check your email to confirm your account."
            }
        }
    }

    func signIn(email: String, password: String) async {
        await runAuthTask {
            let session = try await service.signIn(email: email, password: password)
            state = .signedIn(session)
            statusMessage = "Signed in."
        }
    }

    func signOut() async {
        let session = currentSession
        state = .signedOut

        guard let session else {
            statusMessage = "Signed out."
            return
        }

        isWorking = true
        defer { isWorking = false }

        do {
            try await service.signOut(session: session)
            statusMessage = "Signed out."
        } catch {
            statusMessage = "Signed out on this device. Reconnect to end the server session."
        }
    }

    func deleteAccount() async -> Bool {
        guard let session = currentSession else {
            return false
        }

        isWorking = true
        statusMessage = nil
        defer { isWorking = false }

        do {
            try await service.deleteAccount(session: session)
            state = .signedOut
            statusMessage = "Your account was deleted."
            return true
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    private func restoreSession() async {
        defer { isRestoringSession = false }

        do {
            if let session = try await service.restoreSession() {
                state = .signedIn(session)
            }
        } catch {
            state = .signedOut
        }
    }

    private var currentSession: AuthSession? {
        guard case .signedIn(let session) = state else {
            return nil
        }

        return session
    }

    private func runAuthTask(_ operation: () async throws -> Void) async {
        guard !isWorking else { return }

        isWorking = true
        statusMessage = nil

        do {
            try await operation()
        } catch {
            statusMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        isWorking = false
    }
}
