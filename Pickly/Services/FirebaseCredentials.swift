import FirebaseCore
import Foundation

enum FirebaseCredentials {
    static var isConfigured: Bool {
        !apiKey.isEmpty && !appID.isEmpty && !senderID.isEmpty && !projectID.isEmpty
    }

    static func configureIfNeeded() -> Bool {
        guard isConfigured else { return false }
        guard FirebaseApp.app() == nil else { return true }

        let options = FirebaseOptions(googleAppID: appID, gcmSenderID: senderID)
        options.apiKey = apiKey
        options.clientID = GoogleSignInConfiguration.iosClientID
        options.projectID = projectID
        options.storageBucket = storageBucket
        FirebaseApp.configure(options: options)
        return true
    }

    private static var apiKey: String { value(for: "FIREBASE_API_KEY") }
    private static var appID: String { value(for: "FIREBASE_APP_ID") }
    private static var senderID: String { value(for: "FIREBASE_GCM_SENDER_ID") }
    private static var projectID: String { value(for: "FIREBASE_PROJECT_ID") }
    private static var storageBucket: String { value(for: "FIREBASE_STORAGE_BUCKET") }

    private static func value(for key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

enum GoogleSignInConfiguration {
    static var isConfigured: Bool {
        iosClientID != nil
    }

    static var iosClientID: String? {
        value(for: "GOOGLE_IOS_CLIENT_ID")
    }

    private static func value(for key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum PicklyAPIConfiguration {
    static var baseURL: URL? {
        validatedBaseURL(
            from: Bundle.main.object(forInfoDictionaryKey: "PICKLY_API_BASE_URL") as? String
        )
    }

    static var isConfigured: Bool { baseURL != nil }

    static func validatedBaseURL(from rawValue: String?) -> URL? {
        guard
            let rawValue,
            let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
            url.scheme?.lowercased() == "https",
            let host = url.host,
            !host.isEmpty,
            url.user == nil,
            url.password == nil,
            url.query == nil,
            url.fragment == nil
        else {
            return nil
        }

        return url
    }
}
