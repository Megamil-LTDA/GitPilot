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
import UserNotifications

@main
struct GitPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared
    @StateObject private var gitMonitor = GitMonitorService.shared
    
    static let sharedModelContainer: ModelContainer = {
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
                .modelContainer(Self.sharedModelContainer)
        } label: {
            StatusItemView(status: appState.globalStatus)
        }
        
        Window("GitPilot", id: "main") {
            MainWindowView()
                .environmentObject(appState)
                .environmentObject(gitMonitor)
                .modelContainer(Self.sharedModelContainer)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
        Settings {
            SettingsView()
                .frame(width: 500, height: 450)
                .environmentObject(appState)
                .modelContainer(Self.sharedModelContainer)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
    }
}

// MARK: - App Delegate for Background Startup
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup notification delegate and categories
        UNUserNotificationCenter.current().delegate = self
        Task {
            await NotificationService.shared.setupCategories()
        }
        
        // Auto-start monitoring after app is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.autoStartMonitoring()
        }
    }
    
    private func autoStartMonitoring() {
        Task { @MainActor in
            do {
                let context = ModelContext(GitPilotApp.sharedModelContainer)
                GitMonitorService.shared.setModelContext(context)
                
                let repos = try context.fetch(FetchDescriptor<WatchedRepository>())
                if !repos.isEmpty && !AppState.shared.isPaused {
                    print("🚀 Auto-starting monitoring for \(repos.count) repositories")
                    GitMonitorService.shared.startMonitoring(repositories: repos)
                } else if repos.isEmpty {
                    print("ℹ️ No repositories to monitor")
                } else {
                    print("⏸️ Monitoring is paused")
                }
            } catch {
                print("❌ Failed to auto-start monitoring: \(error)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// Handle notification actions when user clicks a button
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionId = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        
        // Handle trigger confirmation actions
        if let notificationId = userInfo["notificationId"] as? String {
            Task {
                await NotificationService.shared.handleNotificationAction(
                    notificationId: notificationId,
                    actionId: actionId
                )
            }
        }
        
        completionHandler()
    }
    
    /// Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
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
        
        SettingsLink {
            Text(loc.string("app.settings") + "...")
        }
        .keyboardShortcut(",")
        .simultaneousGesture(TapGesture().onEnded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
            }
        })
        
        Divider()
        
        Button(loc.string("app.quit")) { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }
}
