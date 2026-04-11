import SwiftUI

struct UserNameScreen: View {
    @Environment(OnboardingCoordinator.self) private var coordinator
    @AppStorage("userName") private var userName: String = "Alex"

    @State private var name: String = ""
    @State private var appeared = false

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ZStack {
            Color.somiaBackground.ignoresSafeArea()

            VStack(spacing: 40) {

                // Header
                VStack(spacing: 16) {
                    Text("Comment vous\nappelez-vous ?")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1.0 : 0.0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.easeOut(duration: 0.55), value: appeared)

                    Text("Votre prénom apparaîtra dans l'app chaque matin.")
                        .font(.system(size: 16))
                        .foregroundColor(Color.somiaBodyText)
                        .multilineTextAlignment(.center)
                        .opacity(appeared ? 1.0 : 0.0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.easeOut(duration: 0.55).delay(0.06), value: appeared)
                }
                .padding(.top, 80)
                .padding(.horizontal, 32)

                // Text field
                TextField("Prénom", text: $name)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.somiaCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.somiaCardBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.55).delay(0.1), value: appeared)

                Spacer()

                // CTA
                OnboardingCTAButton(title: "Continuer") {
                    userName = trimmedName
                    coordinator.completeOnboarding()
                }
                .padding(.horizontal, 24)
                .opacity(trimmedName.isEmpty ? 0.4 : 1.0)
                .disabled(trimmedName.isEmpty)
                .opacity(appeared ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.55).delay(0.16), value: appeared)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        UserNameScreen()
            .environment(OnboardingCoordinator())
    }
}
