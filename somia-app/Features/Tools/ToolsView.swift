import SwiftUI

struct ToolsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: CoherenceCardiaqueView()) {
                        ToolCard(
                            icon: "heart.circle",
                            title: "Cohérence cardiaque",
                            subtitle: "Exercice de respiration guidée"
                        ) {}
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    NavigationLink(destination: ExportDonneesView()) {
                        ToolCard(
                            icon: "square.and.arrow.up",
                            title: "Export de données",
                            subtitle: "Exporter vos données de santé"
                        ) {}
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    NavigationLink(destination: PriseInsulineView()) {
                        ToolCard(
                            icon: "syringe",
                            title: "Prise d'insuline",
                            subtitle: "Enregistrer une mesure d'insuline"
                        ) {}
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Outils")
        }
    }
}

#Preview {
    ToolsView()
}
