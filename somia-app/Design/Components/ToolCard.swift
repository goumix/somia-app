import SwiftUI

struct ToolCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SomiaCard(style: .light) {
                HStack(spacing: SomiaSpacing.md) {
                    iconView
                    labelStack
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(Color.somiaAccent.opacity(0.12))
                .frame(width: 44, height: 44)
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.somiaAccent)
        }
    }

    private var labelStack: some View {
        VStack(alignment: .leading, spacing: SomiaSpacing.xs) {
            Text(title)
                .font(.somiaHeadline)
                .foregroundStyle(Color(.label))
            Text(subtitle)
                .font(.somiaBody)
                .foregroundStyle(Color(.secondaryLabel))
        }
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        VStack(spacing: SomiaSpacing.sm) {
            ToolCard(icon: "heart.circle", title: "Cohérence cardiaque", subtitle: "Exercice de respiration guidée") {}
            ToolCard(icon: "square.and.arrow.up", title: "Export de données", subtitle: "Exporter vos données de santé") {}
            ToolCard(icon: "syringe", title: "Prise d'insuline", subtitle: "Enregistrer une mesure d'insuline") {}
        }
        .padding(SomiaSpacing.md)
    }
}
