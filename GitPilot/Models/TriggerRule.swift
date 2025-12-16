//
//  TriggerRule.swift
//  GitPilot
//
//  Created with ❤️ for the open-source community
//  Licensed under MIT License
//

import Foundation
import SwiftData

@Model
final class TriggerRule {
    var id: UUID
    var name: String
    var commitFlag: String?         // e.g., "--prod", "--dev", or nil for any commit
    var command: String             // Shell command to execute
    var workingDirectory: String?   // Override working directory (uses repo path if nil)
    var isEnabled: Bool
    var priority: Int               // Higher priority rules are checked first
    var createdAt: Date
    
    // Parent relationship
    var repository: WatchedRepository?
    
    init(
        name: String,
        command: String,
        commitFlag: String? = nil,
        workingDirectory: String? = nil,
        isEnabled: Bool = true,
        priority: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.command = command
        self.commitFlag = commitFlag
        self.workingDirectory = workingDirectory
        self.isEnabled = isEnabled
        self.priority = priority
        self.createdAt = Date()
    }
    
    /// Check if this rule matches the given commit message
    func matches(commitMessage: String) -> Bool {
        guard isEnabled else { return false }
        
        // If no flag specified, matches any commit
        guard let flag = commitFlag, !flag.isEmpty else {
            return true
        }
        
        // Support multiple flags separated by comma (OR logic)
        let flags = flag.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Check if commit message contains ANY of the flags
        return flags.contains { commitMessage.localizedCaseInsensitiveContains($0) }
    }
}

// MARK: - Convenience
extension TriggerRule {
    var displayFlag: String {
        commitFlag ?? "(any commit)"
    }
    
    var effectiveWorkingDirectory: String? {
        workingDirectory ?? repository?.localPath
    }
}
