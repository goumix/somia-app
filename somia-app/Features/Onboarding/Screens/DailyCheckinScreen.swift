import SwiftUI

struct DailyCheckinScreen: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.somiaBackground.ignoresSafeArea()

            RadialGradient(
                colors: [Color.somiaAccent.opacity(0.08), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )
            .frame(width: 400, height: 400)
            .offset(y: -60)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                PhoneMockupView()
                    .frame(width: 190, height: 310)
                    .opacity(appeared ? 1.0 : 0.0)
                    .scaleEffect(appeared ? 1.0 : 0.88)

                Spacer()

                VStack(spacing: 16) {
                    Text("2 minutes le matin")
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1.0 : 0.0)

                    Text("Un score de dérive, un insight, une ou deux questions. L'app se ferme. C'est tout.")
                        .font(.system(size: 17))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.somiaBodyText)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.55).delay(0.1), value: appeared)
                }
                .padding(.horizontal, 8)

                Spacer()

                OnboardingCTAButton(title: "Continuer", action: { coordinator.navigate(to: .permissions) })
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

// MARK: - Phone mockup

private struct PhoneMockupView: View {
    @State private var contentVisible = false

    var body: some View {
        ZStack {
            // Phone body
            RoundedRectangle(cornerRadius: 34)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 34)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )

            // Screen contents
            VStack(spacing: 0) {
                // Dynamic island
                Capsule()
                    .fill(Color.black)
                    .frame(width: 72, height: 20)
                    .padding(.top, 14)

                Spacer()

                // Score ring
                ZStack {
                    Circle()
                        .fill(Color.somiaAccent.opacity(0.08))
                        .frame(width: 76, height: 76)

                    Circle()
                        .trim(from: 0, to: contentVisible ? 0.22 : 0)
                        .stroke(Color.somiaAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 1) {
                        Text("2")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text("dérive")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.somiaAccent)
                    }
                }
                .opacity(contentVisible ? 1.0 : 0.0)
                .scaleEffect(contentVisible ? 1.0 : 0.7)

                Spacer().frame(height: 14)

                // Insight chip
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.min.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.somiaAccent)
                    Text("Récupération légèrement réduite")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.somiaCard)
                )
                .opacity(contentVisible ? 1.0 : 0.0)

                Spacer().frame(height: 10)

                // Question bubble
                HStack {
                    Text("Comment avez-vous dormi ?")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(Color(red: 0.20, green: 0.20, blue: 0.22))
                        )
                    Spacer()
                }
                .padding(.horizontal, 14)
                .opacity(contentVisible ? 1.0 : 0.0)

                Spacer()

                // Home indicator
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 56, height: 4)
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.35)) {
                contentVisible = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        DailyCheckinScreen()
            .environment(OnboardingCoordinator())
    }
}
