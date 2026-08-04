import Combine
import Foundation

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var preferences: UserPreferences {
        didSet {
            persist()
        }
    }

    private let defaults: UserDefaults
    private let storageKey = "pickly.user-preferences.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = .prototype
        }
    }

    func reset() {
        preferences = .prototype
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(preferences) else {
            return
        }

        defaults.set(data, forKey: storageKey)
    }
}
