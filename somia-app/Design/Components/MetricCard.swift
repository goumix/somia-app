import SwiftUI

struct MetricCard: View {
    let label: String
    let value: String
    let trend: String
    let trendColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.somiaCaption)
                .fontWeight(.medium)
                .foregroundStyle(Color.somiaBodyText)
                .tracking(0.6)

            Spacer().frame(height: SomiaSpacing.sm)

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Text(trend)
                .font(.somiaCaption)
                .fontWeight(.medium)
                .foregroundStyle(trendColor)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(trendColor.opacity(0.13))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .padding(SomiaSpacing.md)
        .background(Color.somiaCard)
        .clipShape(RoundedRectangle(cornerRadius: SomiaRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: SomiaRadius.md)
                .stroke(Color.somiaCardBorder, lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        HStack(spacing: SomiaSpacing.sm) {
            MetricCard(label: "HRV", value: "42 ms", trend: "Stable", trendColor: .somiaBodyText)
            MetricCard(label: "FC repos", value: "58 bpm", trend: "↓ dérive", trendColor: .somiaWarn)
        }
        .padding(SomiaSpacing.md)
    }
}
