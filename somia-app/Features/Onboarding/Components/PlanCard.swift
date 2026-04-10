import SwiftUI

enum PlanType {
    case annual, monthly

    var title: String {
        switch self {
        case .annual:  return "Annuel"
        case .monthly: return "Mensuel"
        }
    }
}

struct PlanCard: View {
    let plan: PlanType
    let price: String
    let trialText: String
    let badge: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.somiaBackground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.somiaAccent)
                                .clipShape(Capsule())
                        }
                    }

                    Text(trialText)
                        .font(.system(size: 13))
                        .foregroundColor(.somiaBodyText)
                }

                Spacer()

                Text(price)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.somiaAccent : Color.somiaBodyText.opacity(0.4),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(Color.somiaAccent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.somiaCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? Color.somiaAccent : Color.somiaCardBorder,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        VStack(spacing: 12) {
            PlanCard(
                plan: .annual,
                price: "49,99 €/an",
                trialText: "Essai gratuit 7 jours",
                badge: "Économisez 60%",
                isSelected: true,
                onTap: {}
            )
            PlanCard(
                plan: .monthly,
                price: "4,99 €/mois",
                trialText: "Essai gratuit 7 jours",
                badge: nil,
                isSelected: false,
                onTap: {}
            )
        }
        .padding(.horizontal, 24)
    }
}
