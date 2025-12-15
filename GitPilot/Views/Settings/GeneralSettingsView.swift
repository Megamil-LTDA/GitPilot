//
//  GeneralSettingsView.swift
//  GitPilot
//
//  Created with ❤️ for the open-source community
//  Licensed under MIT License
//

import SwiftUI
import ServiceManagement

/// General settings tab
struct GeneralSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    @State private var notificationsPermissionGranted = false
    
    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Enable native notifications", isOn: $settingsManager.settings.nativeNotificationsEnabled)
                
                if settingsManager.settings.nativeNotificationsEnabled {
                    Toggle("Notify on success", isOn: $settingsManager.settings.notifyOnSuccess)
                    Toggle("Notify on failure", isOn: $settingsManager.settings.notifyOnFailure)
                    
                    if !notificationsPermissionGranted {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            
                            Text("Notification permission required")
                                .font(.caption)
                            
                            Spacer()
                            
                            Button("Request Permission") {
                                requestNotificationPermission()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            
            Section("App Behavior") {
                Toggle("Launch at login", isOn: $settingsManager.settings.launchAtLogin)
                    .onChange(of: settingsManager.settings.launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
                
                Toggle("Show in Dock", isOn: $settingsManager.settings.showInDock)
                    .onChange(of: settingsManager.settings.showInDock) { _, newValue in
                        updateDockVisibility(newValue)
                    }
                    .help("Showing in Dock allows you to see the app in the Dock and Command-Tab switcher")
            }
            
            Section {
                HStack {
                    Text("Check for updates")
                    Spacer()
                    Button("Check Now") {
                        // TODO: Implement update checking
                    }
                    .disabled(true)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            checkNotificationPermission()
        }
    }
    
    // MARK: - Notifications
    
    private func checkNotificationPermission() {
        Task {
            notificationsPermissionGranted = await NotificationService.shared.isAuthorized()
        }
    }
    
    private func requestNotificationPermission() {
        Task {
            notificationsPermissionGranted = await NotificationService.shared.requestPermission()
        }
    }
    
    // MARK: - Launch at Login
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
    
    // MARK: - Dock Visibility
    
    private func updateDockVisibility(_ showInDock: Bool) {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

#Preview {
    GeneralSettingsView()
        .frame(width: 450, height: 300)
}
