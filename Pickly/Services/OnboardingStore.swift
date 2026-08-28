import Combine
import Foundation

@MainActor
final class OnboardingStore: ObservableObject {
    @Published private(set) var hasCompletedOnboarding: Bool

    private let defaults: UserDefaults
    private let key: String

#if DEBUG
    /// Keeps onboarding available for screenshots without changing persisted state
    /// or the Release/App Store build. Pass `-pickly-force-onboarding` at launch.
    private static var forceOnboardingForTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-pickly-force-onboarding")
    }

    /// Lets the screenshot runner open the main app without completing setup
    /// interactively. This is Debug-only and never changes persisted state.
    private static var skipOnboardingForTesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-pickly-skip-onboarding")
    }
#else
    private static let forceOnboardingForTesting = false
    private static let skipOnboardingForTesting = false
#endif

    init(
        defaults: UserDefaults = .standard,
        key: String = "pickly.has-completed-onboarding.v1"
    ) {
        self.defaults = defaults
        self.key = key
        let shouldForceOnboarding = defaults === UserDefaults.standard
            && Self.forceOnboardingForTesting
        let shouldSkipOnboarding = defaults === UserDefaults.standard
            && Self.skipOnboardingForTesting
        self.hasCompletedOnboarding = shouldSkipOnboarding
            ? true
            : shouldForceOnboarding
                ? false
                : defaults.bool(forKey: key)
    }

    func complete() {
        defaults.set(true, forKey: key)
        hasCompletedOnboarding = true
    }
}
