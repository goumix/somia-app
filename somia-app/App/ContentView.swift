//
//  ContentView.swift
//  somia-app
//
//  Created by Nathéo Brault on 16/03/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Accueil", systemImage: "house.fill")
                }

            ToolsView()
                .tabItem {
                    Label("Outils", systemImage: "wrench.and.screwdriver.fill")
                }
        }
        .tint(Color.somiaAccent)
    }
}

#Preview {
    ContentView()
}
