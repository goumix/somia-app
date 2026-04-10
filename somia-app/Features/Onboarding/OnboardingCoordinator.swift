import SwiftUI
import Observation

@Observable
final class OnboardingCoordinator {
    var hasSeenOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenOnboarding, forKey: "somia.hasSeenOnboarding")
        }
    }

    init() {
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "somia.hasSeenOnboarding")
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
    }
}
