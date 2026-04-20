import SwiftUI

struct CoherenceCardiaqueView: View {
    var body: some View {
        Text("Cohérence cardiaque — à venir")
            .navigationTitle("Cohérence cardiaque")
            .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack { CoherenceCardiaqueView() }
}
