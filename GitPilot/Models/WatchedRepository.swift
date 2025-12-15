//
//  WatchedRepository.swift
//  GitPilot
//
//  Created with ❤️ for the open-source community
//  Licensed under MIT License
//

import Foundation
import SwiftData

/// Model representing a Git repository to be monitored
@Model
final class WatchedRepository {
    var id: UUID
    var name: String
    var localPath: String
    var remoteName: String
    var branch: String
    var checkIntervalSeconds: Int
    var isEnabled: Bool
    var lastCommitHash: String?
    var lastCommitMessage: String?
    var lastCheckedAt: Date?
    var lastError: String?
    var createdAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade)
    var triggers: [TriggerRule] = []
    
    // Notification group relationship
    var notificationGroup: NotificationGroup?
    
    // Transient properties (not persisted)
    @Transient var isChecking: Bool = false
    @Transient var currentStatus: RepositoryStatus = .idle
    
    init(
        name: String,
        localPath: String,
        remoteName: String = "origin",
        branch: String = "main",
        checkIntervalSeconds: Int = 300,
        isEnabled: Bool = true,
        notificationGroup: NotificationGroup? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.localPath = localPath
        self.remoteName = remoteName
        self.branch = branch
        self.checkIntervalSeconds = checkIntervalSeconds
        self.isEnabled = isEnabled
        self.notificationGroup = notificationGroup
        self.createdAt = Date()
    }
    
    // MARK: - Computed Properties
    
    var formattedCheckInterval: String {
        let minutes = checkIntervalSeconds / 60
        if minutes >= 60 {
            return "\(minutes / 60)h"
        }
        return "\(minutes) min"
    }
    
    var shortLastCommitHash: String {
        guard let hash = lastCommitHash else { return "-" }
        return String(hash.prefix(7))
    }
    
    var lastCheckedAtFormatted: String {
        guard let date = lastCheckedAt else { return "Nunca" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Repository Status
enum RepositoryStatus: String, CaseIterable {
    case idle
    case checking
    case building
    case success
    case failed
    case error
    
    var description: String {
        switch self {
        case .idle: return "Aguardando"
        case .checking: return "Verificando"
        case .building: return "Buildando"
        case .success: return "Sucesso"
        case .failed: return "Falhou"
        case .error: return "Erro"
        }
    }
}
