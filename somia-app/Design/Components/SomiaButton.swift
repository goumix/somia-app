import SwiftUI

struct SomiaButton: View {
    enum Variant { case primary, secondary, ghost }

    let title: String
    var variant: Variant = .primary
    var isFullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.somiaHeadline)
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.vertical, SomiaSpacing.md)
                .padding(.horizontal, isFullWidth ? 0 : SomiaSpacing.lg)
                .background(background)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(borderColor, lineWidth: borderWidth))
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:   return .black
        case .secondary: return .white
        case .ghost:     return .somiaAccent
        }
    }

    private var background: Color {
        switch variant {
        case .primary:   return .somiaAccent
        case .secondary: return .somiaCard
        case .ghost:     return .clear
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary:   return .clear
        case .secondary: return .somiaCardBorder
        case .ghost:     return .somiaAccent
        }
    }

    private var borderWidth: CGFloat {
        variant == .primary ? 0 : 1
    }
}

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        VStack(spacing: SomiaSpacing.md) {
            SomiaButton(title: "Commencer", variant: .primary) {}
            SomiaButton(title: "Secondaire", variant: .secondary) {}
            SomiaButton(title: "Ghost", variant: .ghost) {}
            SomiaButton(title: "Inline", variant: .ghost, isFullWidth: false) {}
        }
        .padding(.horizontal, SomiaSpacing.md)
    }
}
