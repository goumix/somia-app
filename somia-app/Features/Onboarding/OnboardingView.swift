import SwiftUI

struct OnboardingView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            WelcomeScreen()
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .driftDetection: DriftDetectionScreen()
                    case .baseline:       BaselineScreen()
                    case .dailyCheckin:   DailyCheckinScreen()
                    case .permissions:    PermissionsScreen()
                    case .userName:       UserNameScreen()
                    }
                }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(OnboardingCoordinator())
}
