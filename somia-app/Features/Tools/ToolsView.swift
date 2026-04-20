import SwiftUI

struct ToolsView: View {
    @State private var selectedTool: Tool? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.somiaBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: SomiaSpacing.lg) {
                        headerSection
                        VStack(spacing: SomiaSpacing.sm) {
                            ForEach(Tool.allCases) { tool in
                                ToolRow(
                                    tool: tool,
                                    isExpanded: selectedTool == tool,
                                    onTap: {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            selectedTool = selectedTool == tool ? nil : tool
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(SomiaSpacing.md)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: SomiaSpacing.xs) {
            Text("OUTILS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.somiaBodyText)
                .tracking(1.5)
            Text("Explorez")
                .font(.somiaLargeTitle)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ToolsView()
}
