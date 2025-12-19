//
//  GitPilotApp.swift
//  GitPilot
//
//  Copyright (c) 2026 Megamil
//  Contact: eduardo@megamil.com.br
//
//  Licensed under the MIT License
//

import SwiftUI
import SwiftData

@main
struct GitPilotApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var gitMonitor = GitMonitorService.shared
    
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WatchedRepository.self,
            TriggerRule.self,
            BuildLog.self,
            NotificationGroup.self,
            CheckLog.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu()
                .environmentObject(appState)
                .environmentObject(gitMonitor)
                .modelContainer(sharedModelContainer)
        } label: {
            StatusItemView(status: appState.globalStatus)
        }
        
        Window("GitPilot", id: "main") {
            MainWindowView()
                .environmentObject(appState)
                .environmentObject(gitMonitor)
                .modelContainer(sharedModelContainer)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        Settings {
            SettingsView()
                .frame(width: 500, height: 450)
                .environmentObject(appState)
                .modelContainer(sharedModelContainer)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
    }
}

struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gitMonitor: GitMonitorService
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        Button(loc.string("app.open")) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o")
        
        Divider()
        
        Text("Status: \(loc.string("status.\(appState.globalStatus.rawValue)"))")
            .foregroundStyle(.secondary)
        
        Divider()
        
        Button(appState.isPaused ? loc.string("action.resume") : loc.string("action.pause")) {
            appState.isPaused.toggle()
            if appState.isPaused { gitMonitor.stopMonitoring(); appState.globalStatus = .paused }
            else { appState.globalStatus = .idle }
        }
        
        Divider()
        
        SettingsLink { Text(loc.string("app.settings") + "...") }.keyboardShortcut(",")
        
        Divider()
        
        Button(loc.string("app.quit")) { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }
}
