import SwiftUI

struct OnboardingCTAButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.somiaAccent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        OnboardingCTAButton(title: "Commencer") {}
            .padding(.horizontal, 24)
    }
}
