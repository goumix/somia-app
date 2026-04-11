import SwiftUI
import Observation

enum OnboardingStep: Hashable {
    case driftDetection
    case baseline
    case dailyCheckin
    case permissions
    case paywall
    case userName
}

@Observable
final class OnboardingCoordinator {
    var path = NavigationPath()
    var hasSeenOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenOnboarding, forKey: "somia.hasSeenOnboarding")
        }
    }

    init() {
        self.hasSeenOnboarding = UserDefaults.standard.bool(forKey: "somia.hasSeenOnboarding")
    }

    func navigate(to step: OnboardingStep) {
        path.append(step)
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
    }
}
