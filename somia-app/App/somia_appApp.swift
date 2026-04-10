import SwiftUI

@main
struct somia_appApp: App {
    @State private var onboardingCoordinator = OnboardingCoordinator()
    @State private var healthKit: any HealthKitManaging = {
        #if targetEnvironment(simulator)
        return HealthKitManagerMock()
        #else
        return HealthKitManager()
        #endif
    }()

    var body: some Scene {
        WindowGroup {
            if onboardingCoordinator.hasSeenOnboarding {
                ContentView()
                    .environment(\.healthKit, healthKit)
            } else {
                OnboardingView()
                    .environment(onboardingCoordinator)
                    .environment(\.healthKit, healthKit)
            }
        }
    }
}
