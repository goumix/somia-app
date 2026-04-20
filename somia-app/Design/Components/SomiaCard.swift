import SwiftUI

struct SomiaCard<Content: View>: View {
    enum Style { case dark, light }

    var style: Style = .dark
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(SomiaSpacing.md)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: SomiaRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: SomiaRadius.md)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var backgroundColor: Color {
        switch style {
        case .dark:  return .somiaCard
        case .light: return Color(.secondarySystemBackground)
        }
    }

    private var borderColor: Color {
        switch style {
        case .dark:  return .somiaCardBorder
        case .light: return Color(.separator).opacity(0.4)
        }
    }
}

// MARK: - DriftCardStyle

struct DriftCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(SomiaSpacing.md)
            .background(Color.somiaCard)
            .clipShape(RoundedRectangle(cornerRadius: SomiaRadius.md))
    }
}

extension View {
    func driftCardStyle() -> some View {
        modifier(DriftCardStyle())
    }
}

#Preview {
    VStack(spacing: SomiaSpacing.md) {
        ZStack {
            Color.somiaBackground.ignoresSafeArea()
            SomiaCard(style: .dark) {
                Text("Carte sombre")
                    .foregroundStyle(.white)
                    .font(.somiaBody)
            }
            .padding(SomiaSpacing.md)
        }
        .frame(height: 120)

        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            SomiaCard(style: .light) {
                Text("Carte claire")
                    .foregroundStyle(Color(.label))
                    .font(.somiaBody)
            }
            .padding(SomiaSpacing.md)
        }
        .frame(height: 120)
    }
}
