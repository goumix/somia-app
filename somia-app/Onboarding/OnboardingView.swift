import SwiftUI

struct OnboardingView: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var currentPage: Int = 0

    var body: some View {
        ZStack {
            Color.somiaBackground.ignoresSafeArea()

            switch currentPage {
            case 0:
                WelcomeScreen(onContinue: advance)
                    .transition(.opacity)
            case 1:
                DriftDetectionScreen(onContinue: advance)
                    .transition(.opacity)
            case 2:
                BaselineScreen(onContinue: advance)
                    .transition(.opacity)
            case 3:
                DailyCheckinScreen(onContinue: advance)
                    .transition(.opacity)
            case 4:
                PermissionsScreen(onContinue: advance)
                    .transition(.opacity)
            case 5:
                PaywallScreen(onContinue: coordinator.completeOnboarding)
                    .transition(.opacity)
            default:
                EmptyView()
            }
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.35)) {
            currentPage += 1
        }
    }
}

#Preview {
    OnboardingView()
        .environment(OnboardingCoordinator())
}
