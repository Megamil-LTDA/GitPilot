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
    @ObservedObject var loc = LocalizationManager.shared
    
    @State private var notificationsPermissionGranted = false
    
    var body: some View {
        Form {
            Section(loc.string("settings.notifications")) {
                Toggle(loc.string("settings.nativeNotifications"), isOn: $settingsManager.settings.nativeNotificationsEnabled)
                
                if settingsManager.settings.nativeNotificationsEnabled {
                    Toggle(loc.string("settings.notifySuccess"), isOn: $settingsManager.settings.notifyOnSuccess)
                    Toggle(loc.string("settings.notifyFailure"), isOn: $settingsManager.settings.notifyOnFailure)
                    
                    if !notificationsPermissionGranted {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            
                            Text(loc.string("settings.permissionRequired"))
                                .font(.caption)
                            
                            Spacer()
                            
                            Button(loc.string("settings.requestPermission")) {
                                requestNotificationPermission()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            
            Section(loc.string("settings.appBehavior")) {
                Toggle(loc.string("settings.launchAtLogin"), isOn: $settingsManager.settings.launchAtLogin)
                    .onChange(of: settingsManager.settings.launchAtLogin) { _, newValue in
                        updateLaunchAtLogin(newValue)
                    }
                
                Toggle(loc.string("settings.showInDock"), isOn: $settingsManager.settings.showInDock)
                    .onChange(of: settingsManager.settings.showInDock) { _, newValue in
                        updateDockVisibility(newValue)
                    }
                    .help(loc.string("settings.showInDockHelp"))
            }
            
            Section {
                HStack {
                    Text(loc.string("settings.checkUpdates"))
                    Spacer()
                    Button(loc.string("action.checkNow")) {
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
