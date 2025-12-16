//
//  NotificationGroup.swift
//  GitPilot
//
//  Created with ❤️ for the open-source community
//  Licensed under MIT License
//

import Foundation
import SwiftData

/// Notification group with its own Telegram/Teams configuration
@Model
final class NotificationGroup {
    var id: UUID
    var name: String
    var color: String // hex color for visual identification
    
    // Telegram configuration
    var telegramBotToken: String?
    var telegramChatId: String?
    var telegramEnabled: Bool
    
    // Telegram notification types
    var telegramNotifyNewCommit: Bool = true
    var telegramNotifyTriggerStart: Bool = true
    var telegramNotifySuccess: Bool = true
    var telegramNotifyFailure: Bool = true
    var telegramNotifyError: Bool = true
    
    // Teams/Power Automate configuration  
    var teamsWebhookUrl: String?
    var teamsEnabled: Bool
    
    // Teams notification types
    var teamsNotifyNewCommit: Bool = false
    var teamsNotifyTriggerStart: Bool = true
    var teamsNotifySuccess: Bool = true
    var teamsNotifyFailure: Bool = true
    var teamsNotifyError: Bool = true
    
    // Legacy - kept for backward compatibility
    var notifyOnSuccess: Bool
    var notifyOnFailure: Bool
    
    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \WatchedRepository.notificationGroup)
    var repositories: [WatchedRepository] = []
    
    var createdAt: Date
    
    init(
        name: String,
        color: String = "#007AFF",
        telegramBotToken: String? = nil,
        telegramChatId: String? = nil,
        telegramEnabled: Bool = false,
        teamsWebhookUrl: String? = nil,
        teamsEnabled: Bool = false,
        notifyOnSuccess: Bool = true,
        notifyOnFailure: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.color = color
        self.telegramBotToken = telegramBotToken
        self.telegramChatId = telegramChatId
        self.telegramEnabled = telegramEnabled
        self.teamsWebhookUrl = teamsWebhookUrl
        self.teamsEnabled = teamsEnabled
        self.notifyOnSuccess = notifyOnSuccess
        self.notifyOnFailure = notifyOnFailure
        self.createdAt = Date()
    }
    
    // MARK: - Convenience
    
    var telegramConfigured: Bool {
        guard let token = telegramBotToken, !token.isEmpty,
              let chatId = telegramChatId, !chatId.isEmpty else {
            return false
        }
        return true
    }
    
    var teamsConfigured: Bool {
        guard let url = teamsWebhookUrl, !url.isEmpty else {
            return false
        }
        return true
    }
    
    var repositoryCount: Int {
        repositories.count
    }
}
