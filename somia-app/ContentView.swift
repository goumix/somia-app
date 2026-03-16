//
//  ContentView.swift
//  somia-app
//
//  Created by Nathéo Brault on 16/03/2026.
//

import SwiftUI

// Main app view — affiche l'écran de debug HealthKit pendant le développement.
struct ContentView: View {
    var body: some View {
        HealthDebugView()
    }
}

#Preview {
    ContentView()
}
