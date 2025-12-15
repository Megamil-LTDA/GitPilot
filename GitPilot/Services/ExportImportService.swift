//
//  ExportImportService.swift
//  GitPilot
//

import Foundation
import SwiftData

// MARK: - Export/Import Models

struct ExportData: Codable {
    let version: String
    let exportedAt: Date
    let groups: [GroupExport]
    let repositories: [RepositoryExport]
    
    init(groups: [NotificationGroup], repositories: [WatchedRepository]) {
        self.version = "1.0"
        self.exportedAt = Date()
        self.groups = groups.map { GroupExport(from: $0) }
        self.repositories = repositories.map { RepositoryExport(from: $0) }
    }
}

struct GroupExport: Codable {
    let id: String
    let name: String
    let color: String
    let telegramBotToken: String?
    let telegramChatId: String?
    let telegramEnabled: Bool
    let teamsWebhookUrl: String?
    let teamsEnabled: Bool
    let notifyOnSuccess: Bool
    let notifyOnFailure: Bool
    
    init(from group: NotificationGroup) {
        self.id = group.id.uuidString
        self.name = group.name
        self.color = group.color
        self.telegramBotToken = group.telegramBotToken
        self.telegramChatId = group.telegramChatId
        self.telegramEnabled = group.telegramEnabled
        self.teamsWebhookUrl = group.teamsWebhookUrl
        self.teamsEnabled = group.teamsEnabled
        self.notifyOnSuccess = group.notifyOnSuccess
        self.notifyOnFailure = group.notifyOnFailure
    }
}

struct RepositoryExport: Codable {
    let name: String
    let localPath: String
    let remoteName: String
    let branch: String
    let checkIntervalSeconds: Int
    let isEnabled: Bool
    let notificationGroupId: String?
    let triggers: [TriggerExport]
    
    init(from repo: WatchedRepository) {
        self.name = repo.name
        self.localPath = repo.localPath
        self.remoteName = repo.remoteName
        self.branch = repo.branch
        self.checkIntervalSeconds = repo.checkIntervalSeconds
        self.isEnabled = repo.isEnabled
        self.notificationGroupId = repo.notificationGroup?.id.uuidString
        self.triggers = repo.triggers.map { TriggerExport(from: $0) }
    }
}

struct TriggerExport: Codable {
    let name: String
    let commitFlag: String?
    let command: String
    let workingDirectory: String?
    let priority: Int
    let isEnabled: Bool
    
    init(from trigger: TriggerRule) {
        self.name = trigger.name
        self.commitFlag = trigger.commitFlag
        self.command = trigger.command
        self.workingDirectory = trigger.workingDirectory
        self.priority = trigger.priority
        self.isEnabled = trigger.isEnabled
    }
}

// MARK: - ExportImportService

class ExportImportService {
    static let shared = ExportImportService()
    private init() {}
    
    func exportData(groups: [NotificationGroup], repositories: [WatchedRepository]) -> Data? {
        let exportData = ExportData(groups: groups, repositories: repositories)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            return try encoder.encode(exportData)
        } catch {
            print("❌ Export error: \(error)")
            return nil
        }
    }
    
    func importData(from data: Data, into context: ModelContext) -> Result<ImportResult, Error> {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let importData = try decoder.decode(ExportData.self, from: data)
            var result = ImportResult()
            
            var groupMapping: [String: NotificationGroup] = [:]
            for ge in importData.groups {
                let g = NotificationGroup(
                    name: ge.name,
                    color: ge.color,
                    telegramBotToken: ge.telegramBotToken,
                    telegramChatId: ge.telegramChatId,
                    telegramEnabled: ge.telegramEnabled,
                    teamsWebhookUrl: ge.teamsWebhookUrl,
                    teamsEnabled: ge.teamsEnabled,
                    notifyOnSuccess: ge.notifyOnSuccess,
                    notifyOnFailure: ge.notifyOnFailure
                )
                context.insert(g)
                groupMapping[ge.id] = g
                result.groupsImported += 1
            }
            
            for re in importData.repositories {
                let group = re.notificationGroupId.flatMap { groupMapping[$0] }
                let repo = WatchedRepository(
                    name: re.name,
                    localPath: re.localPath,
                    remoteName: re.remoteName,
                    branch: re.branch,
                    checkIntervalSeconds: re.checkIntervalSeconds,
                    isEnabled: re.isEnabled,
                    notificationGroup: group
                )
                
                for te in re.triggers {
                    let trigger = TriggerRule(
                        name: te.name,
                        command: te.command,
                        commitFlag: te.commitFlag,
                        workingDirectory: te.workingDirectory,
                        isEnabled: te.isEnabled,
                        priority: te.priority
                    )
                    trigger.repository = repo
                    repo.triggers.append(trigger)
                    result.triggersImported += 1
                }
                
                context.insert(repo)
                result.repositoriesImported += 1
            }
            
            try context.save()
            return .success(result)
        } catch {
            return .failure(error)
        }
    }
}

struct ImportResult {
    var groupsImported = 0
    var repositoriesImported = 0
    var triggersImported = 0
    
    var summary: String {
        "\(groupsImported) grupos, \(repositoriesImported) repositórios, \(triggersImported) triggers"
    }
}
