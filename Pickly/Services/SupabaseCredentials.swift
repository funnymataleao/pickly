import Foundation

enum SupabaseCredentials {
    private static let infoDictionary = Bundle.main.infoDictionary

    static var projectURL: URL? {
        guard
            let value = infoDictionary?["SUPABASE_URL"] as? String,
            let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
            url.scheme == "https",
            url.host != nil
        else {
            return nil
        }

        return url
    }

    static var publishableKey: String {
        (infoDictionary?["SUPABASE_PUBLISHABLE_KEY"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var accountDeletionFunctionURL: URL? {
        projectURL?.appending(path: "functions/v1/delete-account")
    }

    static var isConfigured: Bool {
        projectURL != nil
            && !publishableKey.isEmpty
            && !publishableKey.hasPrefix("PASTE_")
            && !publishableKey.hasPrefix("$(")
    }
}
