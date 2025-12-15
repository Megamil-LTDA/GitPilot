//
//  AppSettings.swift
//  GitPilot
//
//  Created with ❤️ for the open-source community
//  Licensed under MIT License
//

import Foundation

/// Application settings stored in UserDefaults
struct AppSettings: Codable {
    // Telegram Integration
    var telegramBotToken: String?
    var telegramChatId: String?
    var telegramNotificationsEnabled: Bool
    
    // Teams/Power Automate Integration
    var teamsWebhookUrl: String?
    var teamsNotificationsEnabled: Bool
    
    // Notifications
    var nativeNotificationsEnabled: Bool
    var notifyOnSuccess: Bool
    var notifyOnFailure: Bool
    
    // App Behavior
    var launchAtLogin: Bool
    var showInDock: Bool
    
    // Defaults
    static let `default` = AppSettings(
        telegramBotToken: nil,
        telegramChatId: nil,
        telegramNotificationsEnabled: false,
        teamsWebhookUrl: nil,
        teamsNotificationsEnabled: false,
        nativeNotificationsEnabled: true,
        notifyOnSuccess: true,
        notifyOnFailure: true,
        launchAtLogin: false,
        showInDock: false
    )
}

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "GitPilotSettings"
    
    @Published var settings: AppSettings {
        didSet {
            save()
        }
    }
    
    private init() {
        self.settings = SettingsManager.load()
    }
    
    private static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "GitPilotSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }
    
    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: settingsKey)
    }
    
    // Convenience accessors
    var telegramConfigured: Bool {
        guard let token = settings.telegramBotToken, !token.isEmpty,
              let chatId = settings.telegramChatId, !chatId.isEmpty else {
            return false
        }
        return true
    }
    
    var teamsConfigured: Bool {
        guard let url = settings.teamsWebhookUrl, !url.isEmpty else {
            return false
        }
        return true
    }
}

// MARK: - White Label Configuration
struct WhiteLabelConfig {
    static let appName = "GitPilot"
    static let appVersion = "1.0.0"
    static let appDescription = "Git Monitor & Build Runner"
    static let githubUrl = "https://github.com/yourusername/GitPilot"
    static let supportEmail = "support@example.com"
}
