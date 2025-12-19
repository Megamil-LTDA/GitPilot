//
//  SettingsView.swift
//  GitPilot
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(loc.string("settings.general"), systemImage: "gear")
                }
            
            DataSettingsView()
                .tabItem {
                    Label(loc.string("settings.data"), systemImage: "square.and.arrow.up.on.square")
                }
        }
        .padding()
    }
}
