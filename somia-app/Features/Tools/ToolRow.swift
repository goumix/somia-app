import SwiftUI

struct ToolRow: View {
    let tool: Tool
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: SomiaSpacing.md) {
                    Image(systemName: tool.systemImage)
                        .font(isExpanded ? .title2 : .body)
                        .foregroundStyle(isExpanded ? Color.somiaAccent : Color.somiaBodyText)
                        .frame(width: 32, height: 32)
                        .animation(.easeInOut(duration: 0.25), value: isExpanded)

                    VStack(alignment: .leading, spacing: SomiaSpacing.xs) {
                        Text(tool.title)
                            .font(.somiaHeadline)
                            .foregroundStyle(isExpanded ? .white : Color.somiaBodyText)
                        if isExpanded {
                            Text(tool.subtitle)
                                .font(.somiaBody)
                                .foregroundStyle(Color.somiaBodyText)
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: isExpanded)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.somiaCaption)
                        .foregroundStyle(Color.somiaBodyText)
                }
                .padding(SomiaSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .background(Color.somiaCardBorder)
                    .padding(.horizontal, SomiaSpacing.md)

                ToolExpandedContent(tool: tool)
                    .padding(SomiaSpacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.somiaCard)
        .clipShape(RoundedRectangle(cornerRadius: SomiaRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: SomiaRadius.md)
                .stroke(Color.somiaCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.somiaBackground.ignoresSafeArea()
        VStack(spacing: SomiaSpacing.sm) {
            ToolRow(tool: .cardiacCoherence, isExpanded: true,  onTap: {})
            ToolRow(tool: .dataExport,       isExpanded: false, onTap: {})
            ToolRow(tool: .glucoseTracking,   isExpanded: false, onTap: {})
        }
        .padding(SomiaSpacing.md)
    }
}
