import SwiftUI

struct PriseInsulineView: View {
    var body: some View {
        Text("Prise d'insuline — à venir")
            .navigationTitle("Prise d'insuline")
            .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack { PriseInsulineView() }
}
