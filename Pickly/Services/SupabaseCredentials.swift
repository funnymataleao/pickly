import Foundation

nonisolated enum SupabaseCredentials {
    private static var infoDictionary: [String: Any]? {
        Bundle.main.infoDictionary
    }

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

    static var googleIOSClientID: String? {
        configuredValue(for: "GOOGLE_IOS_CLIENT_ID")
    }

    static var googleServerClientID: String? {
        configuredValue(for: "GOOGLE_SERVER_CLIENT_ID")
    }

    static var accountDeletionFunctionURL: URL? {
        projectURL?.appending(path: "functions/v1/delete-account")
    }

    static var appleTokenFunctionURL: URL? {
        projectURL?.appending(path: "functions/v1/apple-token")
    }

    static var isConfigured: Bool {
        projectURL != nil
            && !publishableKey.isEmpty
            && !publishableKey.hasPrefix("PASTE_")
            && !publishableKey.hasPrefix("$(")
    }

    static var isGoogleConfigured: Bool {
        googleIOSClientID != nil && googleServerClientID != nil
    }

    private static func configuredValue(for key: String) -> String? {
        guard let rawValue = infoDictionary?[key] as? String else {
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !value.isEmpty,
            !value.hasPrefix("PASTE_"),
            !value.hasPrefix("$(")
        else {
            return nil
        }

        return value
    }
}
