//
//  CheckLog.swift
//  GitPilot
//

import Foundation
import SwiftData

/// Log entry for each monitoring check attempt
@Model
final class CheckLog {
    var id: UUID
    var repositoryName: String
    var repositoryId: UUID
    var branch: String
    var remote: String
    var checkedAt: Date
    var result: CheckResult
    var commitHash: String?
    var commitMessage: String?
    var errorMessage: String?
    var gitOutput: String?
    
    init(
        repositoryName: String,
        repositoryId: UUID,
        branch: String,
        remote: String,
        result: CheckResult,
        commitHash: String? = nil,
        commitMessage: String? = nil,
        errorMessage: String? = nil,
        gitOutput: String? = nil
    ) {
        self.id = UUID()
        self.repositoryName = repositoryName
        self.repositoryId = repositoryId
        self.branch = branch
        self.remote = remote
        self.checkedAt = Date()
        self.result = result
        self.commitHash = commitHash
        self.commitMessage = commitMessage
        self.errorMessage = errorMessage
        self.gitOutput = gitOutput
    }
    
    var shortCommitHash: String {
        guard let hash = commitHash else { return "-" }
        return String(hash.prefix(7))
    }
    
    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: checkedAt)
    }
    
    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM HH:mm"
        return f.string(from: checkedAt)
    }
}

enum CheckResult: String, Codable {
    case noChanges = "no_changes"
    case newCommit = "new_commit"
    case triggered = "triggered"
    case error = "error"
    
    var icon: String {
        switch self {
        case .noChanges: return "minus.circle"
        case .newCommit: return "arrow.down.circle"
        case .triggered: return "bolt.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    var color: String {
        switch self {
        case .noChanges: return "gray"
        case .newCommit: return "blue"
        case .triggered: return "green"
        case .error: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .noChanges: return "Sem alterações"
        case .newCommit: return "Commit novo"
        case .triggered: return "Trigger executado"
        case .error: return "Erro"
        }
    }
}
