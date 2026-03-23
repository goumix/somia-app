//
//  ContentView.swift
//  somia-app
//
//  Created by Nathéo Brault on 16/03/2026.
//

import SwiftUI

// Main app container — NavigationStack with DashboardView as root.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            DashboardView()
        }
        .tint(Color.somiaAccent)
    }
}

#Preview {
    ContentView()
}
