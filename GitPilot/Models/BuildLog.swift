//
//  BuildLog.swift
//  GitPilot
//
//  Created with ❤️ for the open-source community
//  Licensed under MIT License
//

import Foundation
import SwiftData

@Model
final class BuildLog {
    var id: UUID
    var repositoryId: UUID
    var repositoryName: String
    var triggerName: String
    var commitHash: String
    var commitMessage: String
    var command: String
    var output: String
    var exitCode: Int?
    var startedAt: Date
    var finishedAt: Date?
    var status: BuildStatus
    
    init(
        repositoryId: UUID,
        repositoryName: String,
        triggerName: String,
        commitHash: String,
        commitMessage: String,
        command: String
    ) {
        self.id = UUID()
        self.repositoryId = repositoryId
        self.repositoryName = repositoryName
        self.triggerName = triggerName
        self.commitHash = commitHash
        self.commitMessage = commitMessage
        self.command = command
        self.output = ""
        self.startedAt = Date()
        self.status = .running
    }
    
    /// Complete the build with result
    func complete(exitCode: Int, output: String) {
        self.finishedAt = Date()
        self.exitCode = exitCode
        self.output = output
        self.status = exitCode == 0 ? .success : .failed
    }
    
    /// Mark as cancelled
    func cancel() {
        self.finishedAt = Date()
        self.status = .cancelled
    }
}

enum BuildStatus: String, Codable {
    case pending
    case running
    case success
    case failed
    case cancelled
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .running: return "Running"
        case .success: return "Success"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .running: return "play.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "gray"
        case .running: return "blue"
        case .success: return "green"
        case .failed: return "red"
        case .cancelled: return "orange"
        }
    }
}

// MARK: - Convenience
extension BuildLog {
    var duration: TimeInterval? {
        guard let finished = finishedAt else { return nil }
        return finished.timeIntervalSince(startedAt)
    }
    
    var formattedDuration: String {
        guard let duration = duration else { return "Running..." }
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    var shortCommitHash: String {
        String(commitHash.prefix(7))
    }
    
    var startedAtFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: startedAt, relativeTo: Date())
    }
}
