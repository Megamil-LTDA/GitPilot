//
//  GitService.swift
//  GitPilot
//
//  Copyright (c) 2026 Megamil
//  Contact: eduardo@megamil.com.br
//

import Foundation

/// Service for Git operations
actor GitService {
    static let shared = GitService()
    
    private init() {}
    
    // MARK: - Git Operations
    
    /// Fetch updates from remote
    func fetch(at path: String, remote: String = "origin") async throws {
        let result = try await Shell.run("git fetch \(remote)", at: path)
        if result.exitCode != 0 {
            // Include both output and error in the failure message
            throw GitError.fetchFailed(result.combinedOutput)
        }
    }
    
    /// Pull updates from remote
    func pull(at path: String, remote: String = "origin", branch: String) async throws {
        let result = try await Shell.run("git pull \(remote) \(branch)", at: path)
        if result.exitCode != 0 {
            throw GitError.pullFailed(result.combinedOutput)
        }
    }
    
    /// Get the latest commit hash for a branch (remote)
    func getLatestCommitHash(at path: String, branch: String, remote: String = "origin") async throws -> String {
        let result = try await Shell.run("git rev-parse \(remote)/\(branch)", at: path)
        guard result.exitCode == 0 else {
            throw GitError.invalidBranch(branch)
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Get the local HEAD commit hash
    func getLocalCommitHash(at path: String) async throws -> String {
        let result = try await Shell.run("git rev-parse HEAD", at: path)
        if result.exitCode != 0 {
            throw GitError.commandFailed("Could not get local HEAD")
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Get commit message for a specific hash
    func getCommitMessage(at path: String, hash: String) async throws -> String {
        let result = try await Shell.run("git log -1 --format=%B \(hash)", at: path)
        guard result.exitCode == 0 else {
            throw GitError.invalidCommit(hash)
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Get commit author for a specific hash
    func getCommitAuthor(at path: String, hash: String) async throws -> String {
        let result = try await Shell.run("git log -1 --format=%an \(hash)", at: path)
        guard result.exitCode == 0 else {
            throw GitError.invalidCommit(hash)
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if repository path is valid
    func isValidRepository(at path: String) async -> Bool {
        do {
            let result = try await Shell.run("git rev-parse --git-dir", at: path)
            return result.exitCode == 0
        } catch {
            return false
        }
    }
    
    /// Get current branch name
    func getCurrentBranch(at path: String) async throws -> String {
        let result = try await Shell.run("git branch --show-current", at: path)
        guard result.exitCode == 0 else {
            throw GitError.notARepository
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Get list of remote branches
    func getRemoteBranches(at path: String, remote: String = "origin") async throws -> [String] {
        let result = try await Shell.run("git branch -r --list '\(remote)/*'", at: path)
        guard result.exitCode == 0 else {
            throw GitError.fetchFailed("Failed to list branches: \(result.combinedOutput)")
        }
        
        return result.output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.contains("HEAD") }
            .map { $0.replacingOccurrences(of: "\(remote)/", with: "") }
    }
    
    /// Check for new commits since a specific hash
    func hasNewCommits(at path: String, branch: String, remote: String = "origin", since hash: String?) async throws -> (hasNew: Bool, latestHash: String, message: String) {
        // Fetch latest
        try await fetch(at: path, remote: remote)
        
        // Get latest commit
        let latestHash = try await getLatestCommitHash(at: path, branch: branch, remote: remote)
        
        // If no previous hash, this is new
        guard let previousHash = hash else {
            let message = try await getCommitMessage(at: path, hash: latestHash)
            return (true, latestHash, message)
        }
        
        // Compare
        let hasNew = latestHash != previousHash
        let message = hasNew ? try await getCommitMessage(at: path, hash: latestHash) : ""
        
        return (hasNew, latestHash, message)
    }
    
    // MARK: - Tag Operations
    
    /// Fetch tags from remote
    func fetchTags(at path: String, remote: String = "origin") async throws {
        let result = try await Shell.run("git fetch \(remote) --tags", at: path)
        if result.exitCode != 0 {
            throw GitError.fetchFailed(result.combinedOutput)
        }
    }
    
    /// Get the latest tag (sorted by version)
    func getLatestTag(at path: String) async throws -> String? {
        // First try semantic version sorting
        var result = try await Shell.run("git tag --sort=-v:refname | head -n 1", at: path)
        
        if result.exitCode == 0 {
            let tag = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return tag.isEmpty ? nil : tag
        }
        
        // Fallback to date sorting
        result = try await Shell.run("git tag --sort=-creatordate | head -n 1", at: path)
        if result.exitCode == 0 {
            let tag = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return tag.isEmpty ? nil : tag
        }
        
        return nil
    }
    
    /// Check for new tags since the last known tag
    func hasNewTags(at path: String, remote: String = "origin", since lastTag: String?) async throws -> (hasNew: Bool, latestTag: String?, tagName: String) {
        // Fetch latest tags
        try await fetchTags(at: path, remote: remote)
        
        // Get latest tag
        guard let latestTag = try await getLatestTag(at: path) else {
            return (false, nil, "")
        }
        
        // If no previous tag, this is new
        guard let previousTag = lastTag else {
            return (true, latestTag, latestTag)
        }
        
        // Compare
        let hasNew = latestTag != previousTag
        return (hasNew, latestTag, hasNew ? latestTag : "")
    }
}

// MARK: - Errors
enum GitError: LocalizedError {
    case notARepository
    case fetchFailed(String)
    case pullFailed(String)
    case invalidBranch(String)
    case invalidCommit(String)
    case commandFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notARepository:
            return "Path is not a valid Git repository"
        case .fetchFailed(let message):
            return "Git fetch failed: \(message)"
        case .pullFailed(let message):
            return "Git pull failed: \(message)"
        case .invalidBranch(let branch):
            return "Invalid branch: \(branch)"
        case .invalidCommit(let hash):
            return "Invalid commit: \(hash)"
        case .commandFailed(let message):
            return "Git command failed: \(message)"
        }
    }
}
