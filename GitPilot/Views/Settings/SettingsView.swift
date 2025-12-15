//
//  SettingsView.swift
//  GitPilot
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("Geral", systemImage: "gear")
                }
            
            DataSettingsView()
                .tabItem {
                    Label("Dados", systemImage: "square.and.arrow.up.on.square")
                }
        }
        .padding()
    }
}
