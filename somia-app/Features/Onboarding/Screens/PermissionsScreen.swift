import SwiftUI
import HealthKit

struct PermissionsScreen: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(\.healthKit) private var healthKit
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.somiaBackground.ignoresSafeArea()

            // Accent glow
            RadialGradient(
                colors: [Color.somiaAccent.opacity(0.15), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 220
            )
            .frame(width: 440, height: 440)
            .offset(y: -90)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // Icon with glow
                ZStack {
                    Circle()
                        .fill(Color.somiaAccent.opacity(0.12))
                        .frame(width: 130, height: 130)
                        .blur(radius: 24)

                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 88))
                        .foregroundStyle(Color.somiaAccent)
                }
                .scaleEffect(appeared ? 1.0 : 0.8)
                .opacity(appeared ? 1.0 : 0.0)

                Spacer()

                VStack(spacing: 20) {
                    Text("Accès à vos\ndonnées de santé")
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1.0 : 0.0)

                    Text("Somia lit HRV, fréquence cardiaque, sommeil et SpO2 depuis Apple Santé. Vos données ne quittent jamais votre iPhone.")
                        .font(.system(size: 17))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.somiaBodyText)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.55).delay(0.1), value: appeared)

                    // Privacy badge
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.somiaAccent)
                        Text("Lecture seule · Aucun partage · Stockage local")
                            .font(.system(size: 13))
                            .foregroundColor(.somiaBodyText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.somiaCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.somiaCardBorder, lineWidth: 1)
                            )
                    )
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.55).delay(0.15), value: appeared)
                }
                .padding(.horizontal, 8)

                Spacer()

                OnboardingCTAButton(title: "Autoriser l'accès", action: {
                    Task {
                        await healthKit.requestAuthorization()
                        coordinator.navigate(to: .userName)
                    }
                })
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
                .opacity(appeared ? 1.0 : 0.0)
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

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        PermissionsScreen()
            .environment(OnboardingCoordinator())
    }
}
