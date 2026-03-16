import SwiftUI

@main
struct somia_appApp: App {
    @State private var coordinator = OnboardingCoordinator()

    var body: some Scene {
        WindowGroup {
            if coordinator.hasSeenOnboarding {
                ContentView()
            } else {
                OnboardingView()
                    .environment(coordinator)
            }
        }
    }
}
