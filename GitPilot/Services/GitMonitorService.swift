//
//  GitMonitorService.swift
//  GitPilot
//
//  Copyright (c) 2024 Megamil
//  Contact: eduardo@megamil.com.br
//

import Foundation
import SwiftData
import Combine

@MainActor
class GitMonitorService: ObservableObject {
    static let shared = GitMonitorService()
    
    @Published var isRunning = false
    @Published var isBuilding = false // Global build lock
    @Published var activeTimers: [UUID: Timer] = [:]
    @Published var lastCheckTimes: [UUID: Date] = [:]
    @Published var lastCheckResults: [UUID: String] = [:]
    @Published var checkCount = 0
    
    // Live build tracking for real-time output
    @Published var currentBuildLog: BuildLog?
    @Published var liveOutput: String = ""
    
    private let gitService = GitService.shared
    private let commandRunner = CommandRunnerService.shared
    private let notificationService = NotificationService.shared
    
    private var modelContext: ModelContext?
    
    // Track error state per repository for anti-spam notifications
    // true = error was notified, false = recovered/never had error
    private var errorNotifiedState: [UUID: Bool] = [:]
    
    // MARK: - Pending Triggers System
    
    /// Structure to hold pending trigger information
    struct PendingTrigger {
        let repository: WatchedRepository
        let trigger: TriggerRule
        let commitHash: String
        let commitMessage: String
        let checkLog: CheckLog
        let notificationId: String
        var timeoutTimer: Timer?
    }
    
    /// Pending triggers waiting for user confirmation
    private var pendingTriggers: [String: PendingTrigger] = [:]
    
    /// Timeout duration for auto-execution (30 seconds)
    private let confirmationTimeout: TimeInterval = 30
    
    private init() { print("🚀 GitMonitorService init") }
    
    func setModelContext(_ context: ModelContext) { self.modelContext = context; print("📦 Context set") }
    
    func startMonitoring(repositories: [WatchedRepository]) {
        guard !AppState.shared.isPaused else { print("⏸️ Paused"); return }
        isRunning = true; print("🟢 Starting \(repositories.count) repos")
        
        // Request notification permission on start
        Task { await notificationService.requestPermission() }
        
        for repo in repositories where repo.isEnabled { startTimer(for: repo) }
    }
    
    func stopMonitoring() {
        isRunning = false; print("🔴 Stopping all")
        for timer in activeTimers.values { timer.invalidate() }
        activeTimers.removeAll()
    }
    
    func startTimer(for repository: WatchedRepository) {
        activeTimers[repository.id]?.invalidate()
        let interval = TimeInterval(repository.checkIntervalSeconds)
        print("⏱️ Timer for \(repository.name) every \(interval/60)m")
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.checkRepository(repository) }
        }
        RunLoop.main.add(timer, forMode: .common)
        activeTimers[repository.id] = timer
        
        print("🔍 Initial check \(repository.name)")
        Task { await checkRepository(repository) }
    }
    
    func stopTimer(for repository: WatchedRepository) {
        activeTimers[repository.id]?.invalidate()
        activeTimers.removeValue(forKey: repository.id)
    }
    
    /// Cancel the current running build
    func cancelCurrentBuild() {
        guard isBuilding else { return }
        
        print("🛑 Cancelling current build...")
        
        Task {
            await commandRunner.cancelAll()
        }
        
        // Mark build as cancelled
        if let buildLog = currentBuildLog {
            buildLog.complete(exitCode: -999, output: (buildLog.output ?? "") + "\n\n🛑 Build cancelado pelo usuário")
        }
        
        isBuilding = false
        currentBuildLog = nil
        liveOutput = ""
        AppState.shared.globalStatus = .idle
        
        print("✅ Build cancelled")
    }
    
    func checkRepository(_ repository: WatchedRepository) async {
        guard repository.isEnabled else { print("⚠️ \(repository.name) disabled"); return }
        guard let context = modelContext else { print("❌ No context"); return }
        
        // Concurrency Guard
        if isBuilding {
            print("⏳ Build in progress. Skipping check for \(repository.name)")
            return
        }
        
        checkCount += 1; let checkId = checkCount
        let checkType = repository.watchTags ? "tags" : "branch:\(repository.branch)"
        print("🔍 [\(checkId)] Checking \(repository.name) \(checkType)...")
        
        repository.isChecking = true; repository.currentStatus = .checking; AppState.shared.globalStatus = .checking
        lastCheckTimes[repository.id] = Date()
        
        var gitOutput = ""
        
        // Branch: watchTags determines if we check for new tags or new commits
        if repository.watchTags {
            await checkRepositoryTags(repository, context: context, checkId: checkId, gitOutput: &gitOutput)
        } else {
            await checkRepositoryCommits(repository, context: context, checkId: checkId, gitOutput: &gitOutput)
        }
    }
    
    /// Check repository for new commits (original behavior)
    private func checkRepositoryCommits(_ repository: WatchedRepository, context: ModelContext, checkId: Int, gitOutput: inout String) async {
        do {
            print("🔍 [\(checkId)] Fetching \(repository.remoteName)...")
            try await gitService.fetch(at: repository.localPath, remote: repository.remoteName)
            gitOutput += "git fetch \(repository.remoteName) - OK\n"
            
            let result = try await gitService.hasNewCommits(at: repository.localPath, branch: repository.branch, remote: repository.remoteName, since: repository.lastCommitHash)
            gitOutput += "Verificando branch: \(repository.remoteName)/\(repository.branch)\n"
            gitOutput += "Último hash conhecido: \(repository.lastCommitHash ?? "nenhum")\n"
            gitOutput += "Hash atual: \(result.latestHash)\n"
            
            repository.lastCheckedAt = Date()
            
            if result.hasNew {
                print("✅ [\(checkId)] New: \(result.latestHash.prefix(7)) - \(result.message.prefix(50))")
                lastCheckResults[repository.id] = "Novo: \(result.latestHash.prefix(7))"
                gitOutput += "Resultado: NOVO COMMIT DETECTADO\n"
                gitOutput += "Mensagem: \(result.message)\n"
                
                // ALWAYS do git pull when new commit detected
                print("📥 [\(checkId)] Auto pulling...")
                var pullSuccess = false
                
                // Check if we are already on that commit (local push scenario)
                let localHead = try? await gitService.getLocalCommitHash(at: repository.localPath)
                if localHead == result.latestHash {
                    print("✅ Local already up to date with remote.")
                    gitOutput += "Local já atualizado (Commit próprio)\n"
                    pullSuccess = true
                } else {
                    do {
                        try await gitService.pull(at: repository.localPath, remote: repository.remoteName, branch: repository.branch)
                        gitOutput += "git pull - OK\n"
                        pullSuccess = true
                    } catch {
                        gitOutput += "git pull - ERRO: \(error.localizedDescription)\n"
                    }
                }
                
                // Log check with new commit
                let checkLog = CheckLog(
                    repositoryName: repository.name,
                    repositoryId: repository.id,
                    branch: repository.branch,
                    remote: repository.remoteName,
                    result: .newCommit,
                    commitHash: result.latestHash,
                    commitMessage: result.message,
                    gitOutput: gitOutput
                )
                context.insert(checkLog)
                
                if pullSuccess {
                    repository.lastCommitHash = result.latestHash; repository.lastCommitMessage = result.message
                    await processTriggers(for: repository, commitHash: result.latestHash, commitMessage: result.message, checkLog: checkLog)
                } else {
                    print("❌ Pull failed for detected commit. Not updating hash to allow retry.")
                    // Do not process triggers if we couldn't update source code
                }
            } else {
                print("ℹ️ [\(checkId)] No new commits")
                lastCheckResults[repository.id] = "Sem commits novos"
                gitOutput += "Resultado: Nenhuma alteração\n"
                
                // Log check with no changes
                let checkLog = CheckLog(
                    repositoryName: repository.name,
                    repositoryId: repository.id,
                    branch: repository.branch,
                    remote: repository.remoteName,
                    result: .noChanges,
                    commitHash: result.latestHash,
                    gitOutput: gitOutput
                )
                context.insert(checkLog)
                
                repository.currentStatus = .idle; AppState.shared.globalStatus = .idle
            }
            
            // Check if we were in error state and now recovered
            if errorNotifiedState[repository.id] == true {
                errorNotifiedState[repository.id] = false
                // Send recovery notification via Telegram
                await sendTelegramRecoveryNotification(for: repository)
            }
            
            repository.lastError = nil
            try? context.save()
            
        } catch {
            print("❌ [\(checkId)] Error: \(error.localizedDescription)")
            lastCheckResults[repository.id] = "Erro: \(error.localizedDescription)"
            gitOutput += "ERRO: \(error.localizedDescription)\n"
            
            // Log check with error
            let checkLog = CheckLog(
                repositoryName: repository.name,
                repositoryId: repository.id,
                branch: repository.branch,
                remote: repository.remoteName,
                result: .error,
                errorMessage: error.localizedDescription,
                gitOutput: gitOutput
            )
            context.insert(checkLog)
            try? context.save()
            
            repository.currentStatus = .error; repository.lastError = error.localizedDescription
            AppState.shared.lastError = error.localizedDescription; AppState.shared.globalStatus = .error
            
            // Anti-spam: only notify on first error
            if errorNotifiedState[repository.id] != true {
                errorNotifiedState[repository.id] = true
                await sendTelegramErrorNotification(for: repository, error: error.localizedDescription)
            }
        }
        repository.isChecking = false
    }
    
    /// Check repository for new tags
    private func checkRepositoryTags(_ repository: WatchedRepository, context: ModelContext, checkId: Int, gitOutput: inout String) async {
        do {
            print("🏷️ [\(checkId)] Fetching tags from \(repository.remoteName)...")
            let result = try await gitService.hasNewTags(at: repository.localPath, remote: repository.remoteName, since: repository.lastKnownTag)
            gitOutput += "git fetch --tags \(repository.remoteName) - OK\n"
            gitOutput += "Última tag conhecida: \(repository.lastKnownTag ?? "nenhuma")\n"
            gitOutput += "Tag atual: \(result.latestTag ?? "nenhuma")\n"
            
            repository.lastCheckedAt = Date()
            
            if result.hasNew {
                let tagName = result.tagName
                print("🏷️ [\(checkId)] New tag detected: \(tagName)")
                lastCheckResults[repository.id] = "Nova tag: \(tagName)"
                gitOutput += "Resultado: NOVA TAG DETECTADA\n"
                gitOutput += "Tag: \(tagName)\n"
                
                // Log check with new tag
                let checkLog = CheckLog(
                    repositoryName: repository.name,
                    repositoryId: repository.id,
                    branch: "tags",
                    remote: repository.remoteName,
                    result: .newCommit,
                    commitHash: tagName,
                    commitMessage: "Tag: \(tagName)",
                    gitOutput: gitOutput
                )
                context.insert(checkLog)
                
                // Update last known tag
                repository.lastKnownTag = result.latestTag
                
                // Process triggers using tag name as "commit message" for matching
                await processTriggers(for: repository, commitHash: tagName, commitMessage: tagName, checkLog: checkLog)
            } else {
                print("ℹ️ [\(checkId)] No new tags")
                lastCheckResults[repository.id] = "Sem tags novas"
                gitOutput += "Resultado: Nenhuma tag nova\n"
                
                // Log check with no changes
                let checkLog = CheckLog(
                    repositoryName: repository.name,
                    repositoryId: repository.id,
                    branch: "tags",
                    remote: repository.remoteName,
                    result: .noChanges,
                    commitHash: result.latestTag ?? "",
                    gitOutput: gitOutput
                )
                context.insert(checkLog)
                
                repository.currentStatus = .idle; AppState.shared.globalStatus = .idle
            }
            
            // Check if we were in error state and now recovered
            if errorNotifiedState[repository.id] == true {
                errorNotifiedState[repository.id] = false
                await sendTelegramRecoveryNotification(for: repository)
            }
            
            repository.lastError = nil
            try? context.save()
            
        } catch {
            print("❌ [\(checkId)] Tag check error: \(error.localizedDescription)")
            lastCheckResults[repository.id] = "Erro: \(error.localizedDescription)"
            gitOutput += "ERRO: \(error.localizedDescription)\n"
            
            let checkLog = CheckLog(
                repositoryName: repository.name,
                repositoryId: repository.id,
                branch: "tags",
                remote: repository.remoteName,
                result: .error,
                errorMessage: error.localizedDescription,
                gitOutput: gitOutput
            )
            context.insert(checkLog)
            try? context.save()
            
            repository.currentStatus = .error; repository.lastError = error.localizedDescription
            AppState.shared.lastError = error.localizedDescription; AppState.shared.globalStatus = .error
            
            // Anti-spam: only notify on first error
            if errorNotifiedState[repository.id] != true {
                errorNotifiedState[repository.id] = true
                await sendTelegramErrorNotification(for: repository, error: error.localizedDescription)
            }
        }
        repository.isChecking = false
    }
    
    private func processTriggers(for repository: WatchedRepository, commitHash: String, commitMessage: String, checkLog: CheckLog) async {
        let enabledTriggers = repository.triggers.filter { $0.isEnabled }.sorted { $0.priority > $1.priority }
        print("🔧 Processing \(enabledTriggers.count) triggers")
        
        guard let matchingTrigger = enabledTriggers.first(where: { $0.matches(commitMessage: commitMessage) }) else {
            print("⚠️ No matching trigger for: \(commitMessage)")
            repository.currentStatus = .idle; AppState.shared.globalStatus = .idle
            
            // Send notification for new commit without trigger
            await notificationService.send(
                title: "📥 Novo Commit",
                body: "\(commitMessage.prefix(100))",
                subtitle: repository.name
            )
            
            // Send Telegram notification for new commit (no trigger)
            await sendTelegramNewCommitNotification(for: repository, commitHash: commitHash, commitMessage: commitMessage)
            return
        }
        
        // Update check log to triggered
        checkLog.result = .triggered
        
        print("✅ Matched: \(matchingTrigger.name)")
        
        // Request confirmation via notification before executing
        await requestTriggerConfirmation(
            repository: repository,
            trigger: matchingTrigger,
            commitHash: commitHash,
            commitMessage: commitMessage,
            checkLog: checkLog
        )
    }
    
    // MARK: - Trigger Confirmation System
    
    /// Request user confirmation before executing a trigger
    private func requestTriggerConfirmation(
        repository: WatchedRepository,
        trigger: TriggerRule,
        commitHash: String,
        commitMessage: String,
        checkLog: CheckLog
    ) async {
        // Create callback that will handle the user response
        let callback: (Bool) -> Void = { [weak self] shouldExecute in
            // We'll get the notificationId from the pending triggers lookup
            Task { @MainActor in
                guard let self = self else { return }
                
                // Find the pending trigger by matching repository and trigger
                if let entry = self.pendingTriggers.first(where: { 
                    $0.value.repository.id == repository.id && 
                    $0.value.trigger.name == trigger.name &&
                    $0.value.commitHash == commitHash
                }) {
                    if shouldExecute {
                        await self.confirmPendingTrigger(notificationId: entry.key)
                    } else {
                        await self.rejectPendingTrigger(notificationId: entry.key)
                    }
                }
            }
        }
        
        let notificationId = await notificationService.sendTriggerConfirmation(
            repositoryName: repository.name,
            triggerName: trigger.name,
            commitMessage: commitMessage,
            callback: callback
        )
        
        // Store pending trigger
        var pending = PendingTrigger(
            repository: repository,
            trigger: trigger,
            commitHash: commitHash,
            commitMessage: commitMessage,
            checkLog: checkLog,
            notificationId: notificationId
        )
        
        // Start timeout timer
        let timer = Timer.scheduledTimer(withTimeInterval: confirmationTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.handleTriggerTimeout(notificationId: notificationId)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pending.timeoutTimer = timer
        
        pendingTriggers[notificationId] = pending
        
        print("⏳ Trigger pending confirmation: \(trigger.name) for \(repository.name) (timeout: \(confirmationTimeout)s)")
    }
    
    /// Confirm and execute a pending trigger
    private func confirmPendingTrigger(notificationId: String) async {
        guard let pending = pendingTriggers.removeValue(forKey: notificationId) else {
            print("⚠️ No pending trigger found for: \(notificationId)")
            return
        }
        
        // Cancel timeout timer
        pending.timeoutTimer?.invalidate()
        
        print("✅ Trigger confirmed: \(pending.trigger.name) for \(pending.repository.name)")
        
        // Send trigger start notifications (Telegram + Teams)
        await sendTriggerStartNotifications(
            for: pending.repository,
            commitHash: pending.commitHash,
            commitMessage: pending.commitMessage,
            triggerName: pending.trigger.name
        )
        
        // Execute the trigger
        await executeTrigger(
            pending.trigger,
            for: pending.repository,
            commitHash: pending.commitHash,
            commitMessage: pending.commitMessage
        )
    }
    
    /// Reject a pending trigger - skip execution but update hash
    private func rejectPendingTrigger(notificationId: String) async {
        guard let pending = pendingTriggers.removeValue(forKey: notificationId) else {
            print("⚠️ No pending trigger found for rejection: \(notificationId)")
            return
        }
        
        // Cancel timeout timer
        pending.timeoutTimer?.invalidate()
        
        print("🚫 Trigger rejected: \(pending.trigger.name) for \(pending.repository.name)")
        
        // Update repository status
        pending.repository.currentStatus = .idle
        AppState.shared.globalStatus = .idle
        
        // Update check log
        pending.checkLog.result = .noChanges
        pending.checkLog.gitOutput = (pending.checkLog.gitOutput ?? "") + "\n🚫 Trigger rejeitado pelo usuário"
        
        // Save context
        try? modelContext?.save()
        
        // Send notification about rejection
        let loc = LocalizationManager.shared
        await notificationService.send(
            title: "🚫 \(loc.string("notification.triggerRejected"))",
            body: pending.trigger.name,
            subtitle: pending.repository.name
        )
    }
    
    /// Handle timeout - auto-execute the trigger
    private func handleTriggerTimeout(notificationId: String) async {
        guard let pending = pendingTriggers.removeValue(forKey: notificationId) else {
            print("⚠️ No pending trigger found for timeout: \(notificationId)")
            return
        }
        
        print("⏰ Trigger timeout - auto-executing: \(pending.trigger.name) for \(pending.repository.name)")
        
        // Remove notification from screen
        await notificationService.handleTimeout(notificationId: notificationId)
        
        // Send trigger start notifications (Telegram + Teams)
        await sendTriggerStartNotifications(
            for: pending.repository,
            commitHash: pending.commitHash,
            commitMessage: pending.commitMessage,
            triggerName: pending.trigger.name
        )
        
        // Execute the trigger
        await executeTrigger(
            pending.trigger,
            for: pending.repository,
            commitHash: pending.commitHash,
            commitMessage: pending.commitMessage
        )
    }
    
    func executeTrigger(_ trigger: TriggerRule, for repository: WatchedRepository, commitHash: String, commitMessage: String) async -> BuildLog? {
        guard let context = modelContext else { print("❌ No context"); return nil }
        
        // Concurrency Guard
        guard !isBuilding else {
            print("⚠️ Build already in progress. Queueing or ignoring trigger for \(repository.name)")
            // Future improvement: Implement a build queue. For now, we skip to avoid conflicts.
            return nil
        }
        
        print("🏃 Executing: \(trigger.name)")
        isBuilding = true
        repository.currentStatus = .building; AppState.shared.globalStatus = .building
        
        // Process template variables in command
        var processedCommand = trigger.command
        processedCommand = await replaceTemplateVariables(
            in: processedCommand,
            repository: repository,
            commitHash: commitHash,
            commitMessage: commitMessage
        )
        
        let buildLog = BuildLog(
            repositoryId: repository.id,
            repositoryName: repository.name,
            triggerName: trigger.name,
            commitHash: commitHash,
            commitMessage: commitMessage,
            command: processedCommand
        )
        context.insert(buildLog)
        
        // Set as current log for UI
        DispatchQueue.main.async { [weak self] in
            self?.currentBuildLog = buildLog
        }
        
        self.liveOutput = ""
        
        let workingDir = trigger.effectiveWorkingDirectory ?? repository.localPath
        
        // Throttle UI updates to avoid overwhelming the main thread
        var lastUIUpdate = Date()
        let minUpdateInterval: TimeInterval = 0.1 // 100ms between updates
        var pendingOutput = ""
        
        do {
            // Use streaming output callback with throttling
            let result = try await commandRunner.run(command: processedCommand, at: workingDir) { [weak self] newOutput in
                pendingOutput += newOutput
                
                // Throttle updates to main thread
                let now = Date()
                if now.timeIntervalSince(lastUIUpdate) >= minUpdateInterval {
                    let outputToAdd = pendingOutput
                    pendingOutput = ""
                    lastUIUpdate = now
                    
                    Task { @MainActor in
                        self?.liveOutput += outputToAdd
                        // Don't update buildLog.output during streaming - it causes too much overhead
                        // The final output will be set when build completes
                    }
                }
            }
            
            // Flush any remaining pending output
            if !pendingOutput.isEmpty {
                await MainActor.run {
                    self.liveOutput += pendingOutput
                }
            }
            
            buildLog.complete(exitCode: result.exitCode, output: result.output)
            repository.currentStatus = result.exitCode == 0 ? .success : .failed
            AppState.shared.globalStatus = result.exitCode == 0 ? .idle : .error
            print(result.exitCode == 0 ? "✅ Build OK" : "❌ Build failed \(result.exitCode)")
            await sendNotifications(for: buildLog, repository: repository, success: result.exitCode == 0)
        } catch {
            print("❌ Exec error: \(error.localizedDescription)")
            buildLog.complete(exitCode: -1, output: error.localizedDescription)
            repository.currentStatus = .failed; AppState.shared.globalStatus = .error
            await sendNotifications(for: buildLog, repository: repository, success: false)
        }
        
        try? context.save()
        
        isBuilding = false // Release lock
        
        // Keep currentBuildLog set for a moment before clearing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            if self?.currentBuildLog?.id == buildLog.id {
                self?.currentBuildLog = nil
            }
        }
        
        return buildLog
    }
    
    // Public method for retry functionality - returns new BuildLog for auto-open
    @discardableResult
    func retryBuild(buildLog: BuildLog, repositories: [WatchedRepository]) async -> BuildLog? {
        guard let repo = repositories.first(where: { $0.id == buildLog.repositoryId }) else {
            print("❌ Repository not found for retry")
            return nil
        }
        guard let trigger = repo.triggers.first(where: { $0.name == buildLog.triggerName }) else {
            print("❌ Trigger not found for retry")
            return nil
        }
        
        print("🔄 Retrying build: \(buildLog.triggerName) for \(repo.name)")
        return await executeTrigger(trigger, for: repo, commitHash: buildLog.commitHash, commitMessage: buildLog.commitMessage)
    }
    
    private func sendNotifications(for buildLog: BuildLog, repository: WatchedRepository, success: Bool) async {
        guard let group = repository.notificationGroup else {
            print("📭 No notification group for \(repository.name)")
            let settings = SettingsManager.shared.settings
            if (success && settings.notifyOnSuccess) || (!success && settings.notifyOnFailure) {
                if settings.nativeNotificationsEnabled {
                    await notificationService.sendBuildNotification(repositoryName: repository.name, triggerName: buildLog.triggerName, success: success, duration: buildLog.formattedDuration)
                }
            }
            return
        }
        
        let shouldNotify = success ? group.notifyOnSuccess : group.notifyOnFailure
        guard shouldNotify else { print("🔕 Notifications disabled"); return }
        
        print("📨 Sending notifications via group: \(group.name)")
        
        let settings = SettingsManager.shared.settings
        if settings.nativeNotificationsEnabled {
            await notificationService.sendBuildNotification(repositoryName: repository.name, triggerName: buildLog.triggerName, success: success, duration: buildLog.formattedDuration)
        }
        
        // Telegram notification with type checking
        if group.telegramEnabled && group.telegramConfigured {
            let shouldSendTelegram = success ? group.telegramNotifySuccess : group.telegramNotifyFailure
            if shouldSendTelegram {
                await TelegramService.shared.sendBuildNotification(token: group.telegramBotToken!, chatId: group.telegramChatId!, repositoryName: repository.name, branch: repository.branch, commitHash: buildLog.shortCommitHash, commitMessage: buildLog.commitMessage, triggerName: buildLog.triggerName, duration: buildLog.formattedDuration, success: success)
            } else {
                print("🔕 Telegram build notification disabled for \(success ? "success" : "failure")")
            }
        }
        
        // Teams notification with type checking
        if group.teamsEnabled && group.teamsConfigured {
            let shouldSendTeams = success ? group.teamsNotifySuccess : group.teamsNotifyFailure
            if shouldSendTeams {
                await TeamsService.shared.sendBuildNotification(webhookUrl: group.teamsWebhookUrl!, repositoryName: repository.name, branch: repository.branch, commitHash: buildLog.shortCommitHash, commitMessage: buildLog.commitMessage, triggerName: buildLog.triggerName, duration: buildLog.formattedDuration, success: success)
            } else {
                print("🔕 Teams build notification disabled for \(success ? "success" : "failure")")
            }
        }
    }
    
    func checkAllNow(repositories: [WatchedRepository]) async {
        print("🔄 Check all \(repositories.count)")
        for repo in repositories where repo.isEnabled { await checkRepository(repo) }
    
    // Force build for repository (ignoring commit check)
    }

    
    // Manual pull with Real-time Log
    func pullRepository(_ repository: WatchedRepository) async -> CheckLog? {
        print("⬇️ Pulling repository manually: \(repository.name)")
        repository.currentStatus = .checking
        repository.isChecking = true
        
        guard let context = modelContext else { return nil }
        
        let checkLog = CheckLog(
            repositoryName: repository.name,
            repositoryId: repository.id,
            branch: repository.branch,
            remote: repository.remoteName,
            result: .triggered,
            gitOutput: "Iniciando Git Pull manual...\n"
        )
        context.insert(checkLog)
        
        // Optimize: Check if local is already up to date not needed here, user forced it.
        // But maybe good to log.
        
        var pullSuccess = false
        do {
             // We use commandRunner to get streaming output if possible? 
             // GitService uses Shell.run which is simple string.
             // CommandRunner is Actor.
             // Let's use commandRunner for streaming if possible, but triggers use it.
             // For consistency with existing logic, let's use gitService but we might not get live stream unless we use commandRunner.
             // Let's use commandRunner manual usage.
             
             let cmd = "git pull \(repository.remoteName) \(repository.branch)"
             checkLog.gitOutput! += "$ \(cmd)\n"
             
             let result = try await commandRunner.run(command: cmd, at: repository.localPath) { output in
                 Task { @MainActor in
                     checkLog.gitOutput! += output
                 }
             }
             
             checkLog.gitOutput! += "\nSaída final: \(result.output)"
             
            if result.exitCode == 0 {
                repository.currentStatus = .idle
                pullSuccess = true
                checkLog.result = .newCommit // Or some success status? .triggered is fine or reuse existing.
                checkLog.errorMessage = nil
            } else {
                repository.currentStatus = .error
                repository.lastError = "Pull failed: \(result.output)"
                checkLog.result = .error
                checkLog.errorMessage = result.output
            }
        } catch {
            print("❌ Pull error: \(error)")
            repository.currentStatus = .error
            repository.lastError = error.localizedDescription
            checkLog.result = .error
            checkLog.errorMessage = error.localizedDescription
            checkLog.gitOutput! += "\nErro: \(error.localizedDescription)"
        }
        
        repository.isChecking = false
        try? context.save()
        return checkLog
    }
    
func forceBuild(for repository: WatchedRepository) async {
        guard let context = modelContext else { return }
        
        if isBuilding {
            print("⚠️ Build already in progress. Ignoring force build.")
            return
        }
        
        print("🔨 Forcing build for \(repository.name)")
        
        repository.currentStatus = .checking
        repository.isChecking = true
        
        do {
            let gitCmd = "git log -1 --format=\"%H|%s\""
            let result = try await commandRunner.run(command: gitCmd, at: repository.localPath)
            
            if result.exitCode == 0 {
                let parts = result.output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "|", maxSplits: 1).map(String.init)
                if parts.count >= 2 {
                    let hash = parts[0]
                    let message = parts[1]
                    
                    let enabledTriggers = repository.triggers.filter { $0.isEnabled }.sorted { $0.priority > $1.priority }
                    
                    // Match trigger
                    if let matchingTrigger = enabledTriggers.first(where: { $0.matches(commitMessage: message) }) {
                         await executeTrigger(matchingTrigger, for: repository, commitHash: hash, commitMessage: message)
                    } else if let firstTrigger = enabledTriggers.first {
                         // Fallback
                         await executeTrigger(firstTrigger, for: repository, commitHash: hash, commitMessage: message)
                    } else {
                        print("⚠️ No triggers found and forced build requires at least one enabled trigger.")
                        // If no triggers, maybe we should warn the user?
                        // For now just log.
                        repository.currentStatus = .idle
                    }
                }
            } else {
                print("❌ Git log failed: \(result.output)")
            }
        } catch {
            print("❌ Force build error: \(error)")
        }
        
        // Reset status if it's still checking (meaning execution didn't take over)
        if repository.currentStatus == .checking {
            repository.currentStatus = .idle
            repository.isChecking = false
        }
    }
    
    // MARK: - Telegram Notification Helpers
    
    /// Send new commit notification via Telegram (only Telegram)
    private func sendTelegramNewCommitNotification(for repository: WatchedRepository, commitHash: String, commitMessage: String) async {
        guard let group = repository.notificationGroup,
              group.telegramEnabled,
              group.telegramConfigured,
              let token = group.telegramBotToken,
              let chatId = group.telegramChatId else {
            print("📭 No Telegram configured for new commit notification")
            return
        }
        
        // Check if new commit notifications are enabled
        guard group.telegramNotifyNewCommit else {
            print("🔕 Telegram new commit notification disabled")
            return
        }
        
        await TelegramService.shared.sendNewCommitNotification(
            token: token,
            chatId: chatId,
            repositoryName: repository.name,
            branch: repository.branch,
            commitHash: String(commitHash.prefix(7)),
            commitMessage: commitMessage
        )
    }
    
    /// Send trigger start notification via Telegram and Teams
    private func sendTriggerStartNotifications(for repository: WatchedRepository, commitHash: String, commitMessage: String, triggerName: String) async {
        guard let group = repository.notificationGroup else {
            print("📭 No notification group for trigger start")
            return
        }
        
        // Fetch commit author and date
        var commitAuthor = "Desconhecido"
        var commitDate = ""
        do {
            commitAuthor = try await GitService.shared.getCommitAuthor(at: repository.localPath, hash: commitHash)
            commitDate = try await GitService.shared.getCommitDate(at: repository.localPath, hash: commitHash)
        } catch {
            print("⚠️ Could not fetch commit author/date: \(error)")
        }
        
        // Telegram notification with type checking
        if group.telegramEnabled && group.telegramConfigured,
           let token = group.telegramBotToken,
           let chatId = group.telegramChatId,
           group.telegramNotifyTriggerStart {
            await TelegramService.shared.sendTriggerStartNotification(
                token: token,
                chatId: chatId,
                repositoryName: repository.name,
                branch: repository.branch,
                commitHash: String(commitHash.prefix(7)),
                commitMessage: commitMessage,
                commitAuthor: commitAuthor,
                commitDate: commitDate,
                triggerName: triggerName
            )
        } else if group.telegramEnabled && group.telegramConfigured && !group.telegramNotifyTriggerStart {
            print("🔕 Telegram trigger start notification disabled")
        }
        
        // Teams notification with type checking
        if group.teamsEnabled && group.teamsConfigured,
           let webhookUrl = group.teamsWebhookUrl,
           group.teamsNotifyTriggerStart {
            await TeamsService.shared.sendTriggerStartNotification(
                webhookUrl: webhookUrl,
                repositoryName: repository.name,
                branch: repository.branch,
                commitHash: String(commitHash.prefix(7)),
                commitMessage: commitMessage,
                commitAuthor: commitAuthor,
                commitDate: commitDate,
                triggerName: triggerName
            )
        } else if group.teamsEnabled && group.teamsConfigured && !group.teamsNotifyTriggerStart {
            print("🔕 Teams trigger start notification disabled")
        }
    }
    
    /// Send error notification via Telegram (only first error - anti-spam)
    private func sendTelegramErrorNotification(for repository: WatchedRepository, error: String) async {
        guard let group = repository.notificationGroup,
              group.telegramEnabled,
              group.telegramConfigured,
              let token = group.telegramBotToken,
              let chatId = group.telegramChatId else {
            print("📭 No Telegram configured for error notification")
            return
        }
        
        // Check if error notifications are enabled
        guard group.telegramNotifyError else {
            print("🔕 Telegram error notification disabled")
            return
        }
        
        await TelegramService.shared.sendCheckErrorNotification(
            token: token,
            chatId: chatId,
            repositoryName: repository.name,
            errorMessage: error
        )
    }
    
    /// Send recovery notification via Telegram (only after error)
    private func sendTelegramRecoveryNotification(for repository: WatchedRepository) async {
        guard let group = repository.notificationGroup,
              group.telegramEnabled,
              group.telegramConfigured,
              let token = group.telegramBotToken,
              let chatId = group.telegramChatId else {
            print("📭 No Telegram configured for recovery notification")
            return
        }
        
        // Check if error notifications are enabled (recovery is part of error lifecycle)
        guard group.telegramNotifyError else {
            print("🔕 Telegram recovery notification disabled")
            return
        }
        
        await TelegramService.shared.sendRepositoryRecoveredNotification(
            token: token,
            chatId: chatId,
            repositoryName: repository.name
        )
    }
    
    // MARK: - Template Variable Replacement
    
    /// Replace template variables in command string
    /// Supported variables:
    /// - {{commits}} - Recent commits (multi-line format)
    /// - {{commits_oneline}} - Recent commits (single line, pipe-separated)
    /// - {{commits_teams}} - Recent commits with HTML br line breaks for Teams
    /// - {{commit_hash}} - Current commit hash (short)
    /// - {{commit_hash_full}} - Current commit hash (full)
    /// - {{commit_message}} - Current commit message  
    /// - {{branch}} - Current branch name
    /// - {{repo_name}} - Repository name
    /// - {{repo_path}} - Repository path
    /// - {{date}} - Current date (YYYY-MM-DD)
    /// - {{datetime}} - Current date and time
    private func replaceTemplateVariables(
        in command: String,
        repository: WatchedRepository,
        commitHash: String,
        commitMessage: String
    ) async -> String {
        var result = command
        
        // Quick check if there are any variables to replace
        guard result.contains("{{") else { return result }
        
        // Get commits if needed
        let needsCommits = result.contains("{{commits}}") || result.contains("{{commits_oneline}}") || result.contains("{{commits_teams}}")
        var commitsMultiline = ""
        var commitsOneline = ""
        var commitsTeams = ""
        
        if needsCommits {
            do {
                commitsMultiline = try await gitService.getRecentCommits(at: repository.localPath, count: 5)
                commitsOneline = try await gitService.getRecentCommitsOneLine(at: repository.localPath, count: 5)
                commitsTeams = try await gitService.getRecentCommitsTeams(at: repository.localPath, count: 5)
            } catch {
                print("⚠️ Failed to get commits for template: \(error)")
            }
        }
        
        // Date formatters
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // Perform replacements
        let shortHash = String(commitHash.prefix(7))
        
        result = result.replacingOccurrences(of: "{{commits}}", with: commitsMultiline)
        result = result.replacingOccurrences(of: "{{commits_oneline}}", with: commitsOneline)
        result = result.replacingOccurrences(of: "{{commits_teams}}", with: commitsTeams)
        result = result.replacingOccurrences(of: "{{commit_hash}}", with: shortHash)
        result = result.replacingOccurrences(of: "{{commit_hash_full}}", with: commitHash)
        result = result.replacingOccurrences(of: "{{commit_message}}", with: commitMessage)
        result = result.replacingOccurrences(of: "{{branch}}", with: repository.branch)
        result = result.replacingOccurrences(of: "{{repo_name}}", with: repository.name)
        result = result.replacingOccurrences(of: "{{repo_path}}", with: repository.localPath)
        result = result.replacingOccurrences(of: "{{date}}", with: dateFormatter.string(from: Date()))
        result = result.replacingOccurrences(of: "{{datetime}}", with: dateTimeFormatter.string(from: Date()))
        
        return result
    }
}
