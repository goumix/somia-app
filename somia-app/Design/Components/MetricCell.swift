import SwiftUI

struct MetricCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: SomiaSpacing.xs) {
            Text(label)
                .font(.somiaCaption)
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.somiaTitle)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SomiaSpacing.md)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: SomiaRadius.md))
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        HStack(spacing: SomiaSpacing.sm) {
            MetricCell(label: "HRV au repos", value: "42 ms")
            MetricCell(label: "FC au repos",  value: "58 bpm")
        }
        .padding(SomiaSpacing.md)
    }
}
