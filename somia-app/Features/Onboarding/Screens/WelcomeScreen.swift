import SwiftUI

struct WelcomeScreen: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.somiaBackground.ignoresSafeArea()

            // Radial glow behind illustration
            RadialGradient(
                colors: [Color.somiaAccent.opacity(0.14), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 220
            )
            .frame(width: 440, height: 440)
            .offset(y: -70)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                OrganicIllustration()
                    .frame(width: 280, height: 280)
                    .scaleEffect(appeared ? 1.0 : 0.85)
                    .opacity(appeared ? 1.0 : 0.0)

                Spacer()

                VStack(spacing: 16) {
                    Text("Votre corps parle.\nApprenez à l'écouter.")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1.0 : 0.0)

                    Text("Somia analyse vos signaux physiologiques sur 14 à 30 jours pour détecter ce que vous ne ressentez pas encore.")
                        .font(.system(size: 17))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.somiaBodyText)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.55).delay(0.1), value: appeared)
                }
                .padding(.horizontal, 8)

                Spacer()

                SomiaButton(title: "Commencer") { coordinator.navigate(to: .driftDetection) }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 52)
                    .opacity(appeared ? 1.0 : 0.0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.55).delay(0.2), value: appeared)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
    }
}

// MARK: - Abstract organic illustration

private struct OrganicIllustration: View {
    @State private var rotating = false

    var body: some View {
        ZStack {
            // Outer faint rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .strokeBorder(Color.somiaAccent.opacity(0.06 - Double(i) * 0.015), lineWidth: 1)
                    .frame(width: CGFloat(220 + i * 32), height: CGFloat(220 + i * 32))
            }

            // Main outer ring
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [Color.somiaAccent.opacity(0.5), Color.somiaAccent.opacity(0.05), Color.somiaAccent.opacity(0.4)],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(rotating ? 360 : 0))
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: rotating)

            // Blob 1 – teal-green
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.somiaAccent.opacity(0.45), Color.somiaAccent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 150, height: 130)
                .rotationEffect(.degrees(-22))

            // Blob 2 – cool blue tint
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.18, green: 0.65, blue: 0.88).opacity(0.30), Color.somiaAccent.opacity(0.10)],
                        startPoint: .bottom,
                        endPoint: .topTrailing
                    )
                )
                .frame(width: 110, height: 135)
                .rotationEffect(.degrees(35))
                .offset(x: 18, y: -12)

            // Core glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.somiaAccent.opacity(0.85), Color.somiaAccent.opacity(0.15)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 44
                    )
                )
                .frame(width: 72, height: 72)

            // Inner sparkle dot
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 8, height: 8)
                .offset(x: -14, y: -14)
        }
        .onAppear { rotating = true }
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        WelcomeScreen()
            .environment(OnboardingCoordinator())
    }
}
