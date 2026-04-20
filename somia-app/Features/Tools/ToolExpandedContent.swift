import SwiftUI

struct ToolExpandedContent: View {
    let tool: Tool

    var body: some View {
        switch tool {
        case .cardiacCoherence:
            cardiacCoherenceContent
        case .dataExport:
            dataExportContent
        case .glucoseTracking:
            glucoseTrackingContent
        }
    }

    // MARK: - Cardiac Coherence

    private var cardiacCoherenceContent: some View {
        VStack(alignment: .leading, spacing: SomiaSpacing.md) {
            ComingSoonBadge()
            Text("Guidez votre respiration pour réduire le stress et améliorer votre variabilité cardiaque.")
                .font(.somiaBody)
                .foregroundStyle(Color.somiaBodyText)
            HStack(spacing: SomiaSpacing.sm) {
                StatBox(label: "Durée", value: "5'")
                StatBox(label: "Impact HRV", value: "+8ms")
                StatBox(label: "Fréquence", value: "×3/sem")
            }
        }
    }

    // MARK: - Data Export

    private var dataExportContent: some View {
        VStack(alignment: .leading, spacing: SomiaSpacing.md) {
            ComingSoonBadge()
            Text("Générez un rapport PDF de vos données physiologiques, lisible par un médecin.")
                .font(.somiaBody)
                .foregroundStyle(Color.somiaBodyText)
            VStack(spacing: SomiaSpacing.sm) {
                ExportRow(label: "Rapport 30 jours", icon: "doc.text")
                ExportRow(label: "Rapport 90 jours", icon: "doc.text")
            }
        }
    }

    // MARK: - Glucose Tracking

    private var glucoseTrackingContent: some View {
        VStack(alignment: .leading, spacing: SomiaSpacing.md) {
            ComingSoonBadge()
            Text("Suivez l'évolution de votre glycémie et son impact sur votre dérive physiologique.")
                .font(.somiaBody)
                .foregroundStyle(Color.somiaBodyText)
            HStack(spacing: SomiaSpacing.sm) {
                StatBox(label: "À jeun", value: "—")
                StatBox(label: "Dans la cible", value: "—%")
                StatBox(label: "Tendance", value: "7j")
            }
            Text("Données lues depuis HealthKit, stockées sur votre appareil.")
                .font(.somiaCaption)
                .foregroundStyle(Color.somiaBodyText)
        }
    }
}

// MARK: - Sub-components

private struct ComingSoonBadge: View {
    var body: some View {
        Text("Bientôt disponible")
            .font(.somiaCaption)
            .foregroundStyle(Color.somiaAccent)
            .padding(.horizontal, SomiaSpacing.sm)
            .padding(.vertical, SomiaSpacing.xs)
            .background(Color.somiaAccent.opacity(0.15))
            .clipShape(Capsule())
    }
}

private struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: SomiaSpacing.xs) {
            Text(value)
                .font(.somiaHeadline)
                .foregroundStyle(.white)
            Text(label)
                .font(.somiaCaption)
                .foregroundStyle(Color.somiaBodyText)
        }
        .frame(maxWidth: .infinity)
        .padding(SomiaSpacing.sm)
        .background(Color.somiaBackground)
        .clipShape(RoundedRectangle(cornerRadius: SomiaRadius.sm))
    }
}

private struct ExportRow: View {
    let label: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.somiaBodyText)
            Text(label)
                .font(.somiaBody)
                .foregroundStyle(.white)
            Spacer()
            Text("lisible par un médecin")
                .font(.somiaCaption)
                .foregroundStyle(Color.somiaBodyText)
        }
        .padding(SomiaSpacing.sm)
        .background(Color.somiaBackground)
        .clipShape(RoundedRectangle(cornerRadius: SomiaRadius.sm))
    }
}

private struct FieldPreview: View {
    let label: String

    var body: some View {
        VStack(spacing: SomiaSpacing.xs) {
            Text(label)
                .font(.somiaCaption)
                .foregroundStyle(Color.somiaBodyText)
            RoundedRectangle(cornerRadius: SomiaRadius.sm)
                .fill(Color.somiaBackground)
                .frame(height: 32)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        VStack(spacing: SomiaSpacing.lg) {
            ToolExpandedContent(tool: .cardiacCoherence)
            Divider()
            ToolExpandedContent(tool: .dataExport)
            Divider()
            ToolExpandedContent(tool: .glucoseTracking)
        }
        .padding(SomiaSpacing.md)
    }
}
