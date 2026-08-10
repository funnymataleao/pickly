import Combine
import Foundation

@MainActor
final class OnboardingStore: ObservableObject {
    @Published private(set) var hasCompletedOnboarding: Bool

    private let defaults: UserDefaults
    private let key: String

    private static let forceOnboardingForTesting = false

    init(
        defaults: UserDefaults = .standard,
        key: String = "pickly.has-completed-onboarding.v1"
    ) {
        self.defaults = defaults
        self.key = key
        let shouldForceOnboarding = defaults === UserDefaults.standard
            && Self.forceOnboardingForTesting
        self.hasCompletedOnboarding = shouldForceOnboarding
            ? false
            : defaults.bool(forKey: key)
    }

    func complete() {
        defaults.set(true, forKey: key)
        hasCompletedOnboarding = true
    }
}
