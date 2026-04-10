import SwiftUI

struct PaywallScreen: View {
    let onContinue: () -> Void
    @State private var selectedPlan: PlanType = .annual
    @State private var appeared = false

    private let features = [
        "Analyse physiologique 30 jours",
        "Score de dérive personnalisé",
        "Corrélations intersignaux",
        "Insights quotidiens contextuels"
    ]

    var body: some View {
        ZStack {
            Color.somiaBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {

                    // Header
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.somiaAccent.opacity(0.18))
                                .frame(width: 110, height: 110)
                                .blur(radius: 22)

                            Image(systemName: "bolt.fill")
                                .font(.system(size: 54))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.somiaAccent, Color.somiaAccent.opacity(0.6)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .scaleEffect(appeared ? 1.0 : 0.75)
                        .opacity(appeared ? 1.0 : 0.0)

                        Text("Débloquer Somia")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(appeared ? 1.0 : 0.0)
                            .offset(y: appeared ? 0 : 10)
                    }
                    .padding(.top, 64)

                    // Plan cards
                    VStack(spacing: 12) {
                        PlanCard(
                            plan: .annual,
                            price: "49,99 €/an",
                            trialText: "Essai gratuit 7 jours",
                            badge: "Économisez 60%",
                            isSelected: selectedPlan == .annual,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPlan = .annual
                                }
                            }
                        )

                        PlanCard(
                            plan: .monthly,
                            price: "4,99 €/mois",
                            trialText: "Essai gratuit 7 jours",
                            badge: nil,
                            isSelected: selectedPlan == .monthly,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedPlan = .monthly
                                }
                            }
                        )
                    }
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1.0 : 0.0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.55).delay(0.1), value: appeared)

                    // Features
                    VStack(spacing: 16) {
                        ForEach(features, id: \.self) { feature in
                            HStack(spacing: 14) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.somiaAccent)

                                Text(feature)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)

                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.55).delay(0.18), value: appeared)

                    // CTA
                    OnboardingCTAButton(title: "Commencer l'essai gratuit", action: onContinue)
                        .padding(.horizontal, 24)
                        .opacity(appeared ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 0.55).delay(0.22), value: appeared)

                    // Footer links
                    HStack(spacing: 4) {
                        Button("Restaurer") {}
                        Text("·").foregroundColor(.somiaBodyText)
                        Button("Conditions") {}
                        Text("·").foregroundColor(.somiaBodyText)
                        Button("Vie privée") {}
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.somiaBodyText)
                    .buttonStyle(.plain)
                    .opacity(appeared ? 1.0 : 0.0)
                    .padding(.bottom, 44)
                }
            }
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
        PaywallScreen(onContinue: {})
    }
}
