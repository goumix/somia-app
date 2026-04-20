import SwiftUI

struct DriftDetectionScreen: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.somiaBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Color.somiaAccent.opacity(0.10), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )
            .frame(width: 400, height: 400)
            .offset(y: -60)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                PulseHeroView()
                    .frame(width: 240, height: 240)
                    .opacity(appeared ? 1.0 : 0.0)
                    .scaleEffect(appeared ? 1.0 : 0.9)

                Spacer()

                VStack(spacing: 16) {
                    Text("Détection silencieuse")
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1.0 : 0.0)

                    Text("Chaque nuit, Somia analyse votre HRV, sommeil et fréquence cardiaque. Elle détecte les dérives avant que vous ne les ressentiez.")
                        .font(.system(size: 17))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.somiaBodyText)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.55).delay(0.1), value: appeared)
                }
                .padding(.horizontal, 8)

                Spacer()

                SomiaButton(title: "Continuer") { coordinator.navigate(to: .baseline) }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 52)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.55).delay(0.2), value: appeared)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                appeared = true
            }
        }
    }
}

// MARK: - Pulse hero

private struct PulseHeroView: View {
    var body: some View {
        ZStack {
            PulseRing(delay: 0.0)
            PulseRing(delay: 0.65)
            PulseRing(delay: 1.3)

            // Static inner rings for depth
            Circle()
                .strokeBorder(Color.somiaAccent.opacity(0.18), lineWidth: 1.5)
                .frame(width: 100, height: 100)

            Circle()
                .strokeBorder(Color.somiaAccent.opacity(0.35), lineWidth: 1.5)
                .frame(width: 70, height: 70)

            // Core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.somiaAccent, Color.somiaAccent.opacity(0.25)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 28
                    )
                )
                .frame(width: 52, height: 52)

            // Heartbeat icon
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.black.opacity(0.75))
        }
    }
}

private struct PulseRing: View {
    let delay: Double
    @State private var pulsing = false

    var body: some View {
        Circle()
            .strokeBorder(Color.somiaAccent.opacity(pulsing ? 0 : 0.55), lineWidth: 2)
            .scaleEffect(pulsing ? 2.0 : 1.0)
            .frame(width: 52, height: 52)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.0)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    pulsing = true
                }
            }
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        DriftDetectionScreen()
            .environment(OnboardingCoordinator())
    }
}
