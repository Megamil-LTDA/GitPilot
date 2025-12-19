//
//  MainWindowView.swift
//  GitPilot
//
//  Copyright (c) 2024 Megamil
//  Contact: eduardo@megamil.com.br
//

import SwiftUI
import SwiftData

struct MainWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gitMonitor: GitMonitorService
    @ObservedObject var loc = LocalizationManager.shared
    
    @Query(sort: \WatchedRepository.name) private var repositories: [WatchedRepository]
    @Query(sort: \NotificationGroup.name) private var groups: [NotificationGroup]
    @Query(sort: \BuildLog.startedAt, order: .reverse) private var buildLogs: [BuildLog]
    @Query(sort: \CheckLog.checkedAt, order: .reverse) private var checkLogs: [CheckLog]
    
    @State private var showingAddRepository = false
    @State private var selectedRepository: WatchedRepository?
    @State private var showingAddGroup = false
    @State private var selectedGroup: NotificationGroup?
    @State private var selectedTab = 0
    @State private var hasInitializedMonitoring = false
    
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                Divider()
                navigationList
                Divider()
                statusFooter
                pauseButton
            }
            .frame(minWidth: 200)
        } detail: {
            contentView
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showingAddRepository) { RepositoryFormView(repository: nil, groups: groups) }
        .sheet(item: $selectedRepository) { repo in RepositoryFormView(repository: repo, groups: groups) }
        .sheet(isPresented: $showingAddGroup) { NotificationGroupFormView(group: nil) }
        .sheet(item: $selectedGroup) { grp in NotificationGroupFormView(group: grp) }
        .onAppear {
            gitMonitor.setModelContext(modelContext)
            // Only start monitoring once on initial appear
            if !hasInitializedMonitoring && !appState.isPaused && !repositories.isEmpty {
                hasInitializedMonitoring = true
                gitMonitor.startMonitoring(repositories: repositories)
            }
        }
        .onChange(of: repositories.count) { oldCount, newCount in
            // Only restart if repositories were added (not on import which adds many at once)
            if newCount > oldCount && oldCount > 0 && !appState.isPaused {
                // Delay to avoid double triggers
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    gitMonitor.startMonitoring(repositories: repositories)
                }
            } else if newCount > 0 && oldCount == 0 && !appState.isPaused && !hasInitializedMonitoring {
                hasInitializedMonitoring = true
                gitMonitor.startMonitoring(repositories: repositories)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            // App icon from Assets
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text("GitPilot").font(.headline)
                HStack(spacing: 4) {
                    Circle().fill(appState.globalStatus.color).frame(width: 8, height: 8)
                    Text(loc.string("status.\(appState.globalStatus.rawValue)")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
    }
    
    private var navigationList: some View {
        List(selection: $selectedTab) {
            Section("Monitor") {
                Label("\(loc.string("sidebar.repositories")) (\(repositories.count))", systemImage: "folder").tag(0)
                Label("\(loc.string("sidebar.builds")) (\(buildLogs.count))", systemImage: "hammer").tag(1)
                Label("\(loc.string("sidebar.history")) (\(checkLogs.count))", systemImage: "clock.arrow.circlepath").tag(3)
            }
            Section(loc.string("settings.title")) {
                Label("\(loc.string("sidebar.groups")) (\(groups.count))", systemImage: "bell").tag(2)
                Label(loc.string("settings.title"), systemImage: "gear").tag(4)
            }
        }
        .listStyle(.sidebar)
    }
    
    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(gitMonitor.isRunning ? .green : .red).frame(width: 8, height: 8)
                Text(gitMonitor.isRunning ? loc.string("status.monitoring") : loc.string("status.stopped")).font(.caption)
            }
            Text("\(loc.string("sidebar.timers")): \(gitMonitor.activeTimers.count) | \(loc.string("sidebar.checks")): \(gitMonitor.checkCount)").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var pauseButton: some View {
        Button {
            appState.isPaused.toggle()
            if appState.isPaused { gitMonitor.stopMonitoring(); appState.globalStatus = .paused }
            else { gitMonitor.startMonitoring(repositories: repositories); appState.globalStatus = .idle }
        } label: {
            Label(appState.isPaused ? loc.string("action.resume") : loc.string("action.pause"), systemImage: appState.isPaused ? "play.fill" : "pause.fill").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(appState.isPaused ? .green : .orange)
        .padding()
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case 0: RepositoriesView(repositories: repositories, groups: groups, showingAddRepository: $showingAddRepository, selectedRepository: $selectedRepository)
        case 1: BuildLogsContentView(logs: buildLogs)
        case 2: GroupsView(groups: groups, showingAddGroup: $showingAddGroup, selectedGroup: $selectedGroup)
        case 3: CheckLogsView(logs: checkLogs)
        case 4: SettingsView()
        default: Text(loc.string("sidebar.repositories"))
        }
    }
}

// MARK: - Check Logs View with Filter

struct CheckLogsView: View {
    let logs: [CheckLog]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedLog: CheckLog?
    @State private var filterResult: CheckResult?
    @State private var showingClearConfirmation = false
    @ObservedObject var loc = LocalizationManager.shared
    
    var filteredLogs: [CheckLog] {
        guard let filter = filterResult else { return logs }
        return logs.filter { $0.result == filter }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc.string("check.title")).font(.title2.bold())
                Text("(\(filteredLogs.count))").foregroundStyle(.secondary)
                Spacer()
                
                Picker("Filtro", selection: $filterResult) {
                    Text("Todos").tag(nil as CheckResult?)
                    Divider()
                    Label(loc.string("check.newCommit"), systemImage: "arrow.down.circle").tag(CheckResult.newCommit as CheckResult?)
                    Label(loc.string("check.noChanges"), systemImage: "minus.circle").tag(CheckResult.noChanges as CheckResult?)
                    Label(loc.string("check.triggered"), systemImage: "bolt.circle").tag(CheckResult.triggered as CheckResult?)
                    Label(loc.string("status.error"), systemImage: "exclamationmark.triangle").tag(CheckResult.error as CheckResult?)
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                
                Button { showingClearConfirmation = true } label: { Label("Limpar", systemImage: "trash") }
                    .tint(.red)
                    .disabled(logs.isEmpty)
            }
            .padding()
            Divider()
            
            if filteredLogs.isEmpty {
                EmptyStateView(title: loc.string("check.empty"), systemImage: "clock.arrow.circlepath", description: filterResult != nil ? "Nenhum resultado com este filtro" : loc.string("check.emptyDescription"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredLogs) { log in
                            CheckLogRow(log: log)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedLog = log }
                                .background(Color(NSColor.controlBackgroundColor))
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedLog) { log in
            CheckLogDetailView(log: log, onFollowLog: { newLog in selectedLog = newLog })
        }
        .confirmationDialog("Limpar Histórico", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Limpar Todo o Histórico", role: .destructive) {
                for log in logs { modelContext.delete(log) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta ação irá remover \(logs.count) registros de verificações. Esta ação não pode ser desfeita.")
        }
        .navigationTitle("")
    }
}

struct CheckLogRow: View {
    let log: CheckLog
    @ObservedObject var loc = LocalizationManager.shared
    
    var resultText: String {
        switch log.result {
        case .noChanges: return loc.string("check.noChanges")
        case .newCommit: return loc.string("check.newCommit")
        case .triggered: return loc.string("check.triggered")
        case .error: return loc.string("status.error")
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.result.icon)
                .foregroundStyle(colorFor(log.result))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(log.repositoryName).font(.headline)
                    Text("•").foregroundStyle(.tertiary)
                    Text(log.branch).foregroundStyle(.blue)
                }
                
                HStack {
                    Text(log.formattedDate).font(.caption)
                    Text("•").foregroundStyle(.tertiary)
                    Text(resultText).font(.caption)
                    if let hash = log.commitHash {
                        Text("•").foregroundStyle(.tertiary)
                        Text(String(hash.prefix(7))).font(.system(.caption, design: .monospaced))
                    }
                }
                .foregroundStyle(.secondary)
                
                if let msg = log.commitMessage { Text(msg).font(.caption2).foregroundStyle(.tertiary).lineLimit(1) }
                if let err = log.errorMessage { Text(err).font(.caption2).foregroundStyle(.red).lineLimit(1) }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(height: 70) // Fixed height to prevent resizing
    }
    
    func colorFor(_ result: CheckResult) -> Color {
        switch result {
        case .noChanges: return .gray; case .newCommit: return .blue
        case .triggered: return .green; case .error: return .red
        }
    }
}

// MARK: - Check Log Detail View

struct CheckLogDetailView: View {
    let log: CheckLog
    var onFollowLog: ((CheckLog) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var gitMonitor: GitMonitorService
    @Query private var repositories: [WatchedRepository]
    @ObservedObject var loc = LocalizationManager.shared
    
    var resultText: String {
        switch log.result {
        case .noChanges: return loc.string("check.noChanges")
        case .newCommit: return loc.string("check.newCommit")
        case .triggered: return loc.string("check.triggered")
        case .error: return loc.string("status.error")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: log.result.icon)
                    .foregroundStyle(resultColor)
                    .font(.title2)
                Text(loc.string("check.details")).font(.headline)
                Spacer()
                Button(loc.string("action.close")) { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: loc.string("build.date"), value: log.formattedDate)
                            InfoRow(label: loc.string("common.repository"), value: log.repositoryName)
                            InfoRow(label: loc.string("repo.branch"), value: log.branch)
                            InfoRow(label: loc.string("repo.remote"), value: log.remote)
                            InfoRow(label: loc.string("check.result"), value: resultText, valueColor: resultColor)
                            if let hash = log.commitHash { InfoRow(label: loc.string("build.commit"), value: hash, isMonospaced: true) }
                            if let msg = log.commitMessage { InfoRow(label: loc.string("check.message"), value: msg) }
                            if let err = log.errorMessage { InfoRow(label: loc.string("status.error"), value: err, valueColor: .red) }
                        }
                        .padding(4)
                    } label: { Label(loc.string("group.info"), systemImage: "info.circle") }
                    
                    if let output = log.gitOutput, !output.isEmpty {
                        GroupBox {
                            ScrollView { Text(output).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 200)
                        } label: { Label(loc.string("check.gitOutput"), systemImage: "terminal") }
                    }

                    if log.result == .newCommit || log.result == .error {
                         if let repo = repositories.first(where: { $0.id == log.repositoryId }) {
                             Button {
                                 Task { 
                                     if let newLog = await gitMonitor.pullRepository(repo) { onFollowLog?(newLog) }
                                 }
                             } label: {
                                 Label("Fazer Pull Agora", systemImage: "arrow.down.circle.fill")
                                     .frame(maxWidth: .infinity)
                             }
                             .controlSize(.large)
                             .buttonStyle(.borderedProminent)
                             .padding(.top, 10)
                         } else {
                             Text("Repositório vinculado não encontrado (ID: \(log.repositoryId)).")
                                 .font(.caption)
                                 .foregroundStyle(.red)
                         }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, idealWidth: 550, minHeight: 400, idealHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var resultColor: Color {
        switch log.result {
        case .noChanges: return .gray; case .newCommit: return .blue; case .triggered: return .green; case .error: return .red
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var isMonospaced: Bool = false
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":").foregroundStyle(.secondary).frame(width: 100, alignment: .trailing)
            if isMonospaced { Text(value).font(.system(.body, design: .monospaced)).foregroundStyle(valueColor).textSelection(.enabled) }
            else { Text(value).foregroundStyle(valueColor).textSelection(.enabled) }
            Spacer()
        }
    }
}

// MARK: - Build Logs Content View with Filter and Export

struct BuildLogsContentView: View {
    let logs: [BuildLog]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedLog: BuildLog?
    @State private var filterStatus: BuildStatus?
    @State private var showingClearConfirmation = false
    @ObservedObject var loc = LocalizationManager.shared
    
    var filteredLogs: [BuildLog] {
        guard let filter = filterStatus else { return logs }
        return logs.filter { $0.status == filter }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc.string("build.title")).font(.title2.bold())
                Text("(\(filteredLogs.count))").foregroundStyle(.secondary)
                Spacer()
                
                Picker("Filtro", selection: $filterStatus) {
                    Text("Todos").tag(nil as BuildStatus?)
                    Divider()
                    Label(loc.string("status.success"), systemImage: "checkmark.circle").tag(BuildStatus.success as BuildStatus?)
                    Label(loc.string("status.failed"), systemImage: "xmark.circle").tag(BuildStatus.failed as BuildStatus?)
                    Label("Em execução", systemImage: "clock").tag(BuildStatus.running as BuildStatus?)
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                
                Button { exportLogs() } label: { Label("Exportar", systemImage: "square.and.arrow.up") }
                    .disabled(filteredLogs.isEmpty)
                
                Button { showingClearConfirmation = true } label: { Label("Limpar", systemImage: "trash") }
                    .tint(.red)
                    .disabled(logs.isEmpty)
            }
            .padding()
            Divider()
            
            if filteredLogs.isEmpty {
                EmptyStateView(title: loc.string("build.empty"), systemImage: "hammer", description: filterStatus != nil ? "Nenhum build com este filtro" : loc.string("build.emptyDescription"))
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredLogs) { log in
                            BuildLogRow(log: log)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedLog = log }
                                .background(Color(NSColor.controlBackgroundColor))
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedLog) { log in
            BuildLogDetailView(log: log) { newLog in
                // Re-open with new log after retry
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.selectedLog = newLog
                }
            }
        }
        .confirmationDialog("Limpar Histórico", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Limpar Todos os Builds", role: .destructive) {
                for log in logs { modelContext.delete(log) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta ação irá remover \(logs.count) registros de builds. Esta ação não pode ser desfeita.")
        }
        .navigationTitle("")
    }
    
    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "gitpilot_builds_\(Date().formatted(.dateTime.year().month().day())).txt"
        panel.title = "Exportar Histórico de Builds"
        
        if panel.runModal() == .OK, let url = panel.url {
            var content = "GitPilot - Histórico de Builds\n"
            content += "Exportado em: \(Date().formatted())\n"
            content += "Total: \(filteredLogs.count) builds\n"
            content += String(repeating: "=", count: 80) + "\n\n"
            
            for log in filteredLogs {
                content += "[\(formatDate(log.startedAt))] \(log.status.rawValue.uppercased())\n"
                content += "Repositório: \(log.repositoryName)\n"
                content += "Trigger: \(log.triggerName)\n"
                content += "Commit: \(log.shortCommitHash) - \(log.commitMessage)\n"
                content += "Duração: \(log.formattedDuration)\n"
                content += "Comando: \(log.command)\n"
                if let exitCode = log.exitCode { content += "Exit Code: \(exitCode)\n" }
                if !log.output.isEmpty {
                    content += "\n--- Output ---\n"
                    content += log.output
                    content += "\n--- Fim do Output ---\n"
                }
                content += String(repeating: "-", count: 80) + "\n\n"
            }
            
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Erro ao exportar: \(error)")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct BuildLogRow: View {
    let log: BuildLog
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.status.icon)
                .foregroundStyle(log.status == .success ? .green : log.status == .failed ? .red : .gray)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(log.repositoryName).font(.headline)
                    Text("•").foregroundStyle(.tertiary)
                    Text(log.triggerName).foregroundStyle(.secondary)
                }
                HStack {
                    Text(formatDate(log.startedAt)).font(.caption)
                    Text("•").foregroundStyle(.tertiary)
                    Text(log.shortCommitHash).font(.system(.caption, design: .monospaced))
                    Text("•").foregroundStyle(.tertiary)
                    Text(log.formattedDuration).font(.caption)
                }
                .foregroundStyle(.secondary)
                Text(log.commitMessage).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(height: 70) // Fixed height to prevent resizing
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Repositories View

struct RepositoriesView: View {
    let repositories: [WatchedRepository]
    let groups: [NotificationGroup]
    @Binding var showingAddRepository: Bool
    @Binding var selectedRepository: WatchedRepository?
    @EnvironmentObject var gitMonitor: GitMonitorService
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc.string("repo.title")).font(.title2.bold())
                Spacer()
                Button { Task { await gitMonitor.checkAllNow(repositories: repositories) } } label: { Label(loc.string("action.checkNow"), systemImage: "arrow.clockwise") }.disabled(repositories.isEmpty)
                Button { showingAddRepository = true } label: { Label(loc.string("action.add"), systemImage: "plus") }.buttonStyle(.borderedProminent)
            }
            .padding()
            Divider()
            
            if repositories.isEmpty {
                EmptyStateView(title: loc.string("repo.empty"), systemImage: "folder.badge.questionmark", description: loc.string("repo.emptyDescription"), actionTitle: loc.string("repo.add")) { showingAddRepository = true }
            } else {
                List { ForEach(repositories) { repo in RepositoryCard(repository: repo).contentShape(Rectangle()).onTapGesture { selectedRepository = repo } } }.listStyle(.inset)
            }
        }
        .navigationTitle("")
    }
}

// MARK: - Groups View

struct GroupsView: View {
    let groups: [NotificationGroup]
    @Binding var showingAddGroup: Bool
    @Binding var selectedGroup: NotificationGroup?
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc.string("group.title")).font(.title2.bold())
                Spacer()
                Button { showingAddGroup = true } label: { Label(loc.string("group.add"), systemImage: "plus") }.buttonStyle(.borderedProminent)
            }
            .padding()
            Divider()
            
            if groups.isEmpty {
                EmptyStateView(title: loc.string("group.empty"), systemImage: "bell.slash", description: loc.string("group.emptyDescription"), actionTitle: loc.string("group.add")) { showingAddGroup = true }
            } else {
                List { ForEach(groups) { group in GroupCard(group: group).contentShape(Rectangle()).onTapGesture { selectedGroup = group } } }.listStyle(.inset)
            }
        }
        .navigationTitle("")
    }
}

// MARK: - Group Card

struct GroupCard: View {
    let group: NotificationGroup
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color(hex: group.color) ?? .blue).frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name).font(.headline)
                HStack(spacing: 8) {
                    if group.telegramEnabled { Label("Telegram", systemImage: "paperplane").font(.caption).foregroundStyle(.blue) }
                    if group.teamsEnabled { Label("Teams", systemImage: "person.3").font(.caption).foregroundStyle(.purple) }
                    if !group.telegramEnabled && !group.teamsEnabled { Text(loc.string("group.noIntegrations")).font(.caption).foregroundStyle(.secondary) }
                }
                Text("\(group.repositoryCount) \(loc.string("group.repositories"))").font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Repository Card

struct RepositoryCard: View {
    @Bindable var repository: WatchedRepository
    @EnvironmentObject var gitMonitor: GitMonitorService
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(statusColor.opacity(0.2)).frame(width: 44, height: 44)
                if repository.isChecking {
                    // Use SF Symbol with rotation animation instead of ProgressView to avoid layout crashes
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(statusColor)
                        .rotationEffect(.degrees(repository.isChecking ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: repository.isChecking)
                } else {
                    Image(systemName: statusIcon).foregroundStyle(statusColor)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(repository.name).font(.headline)
                    if let grp = repository.notificationGroup { Circle().fill(Color(hex: grp.color) ?? .blue).frame(width: 8, height: 8); Text(grp.name).font(.caption).foregroundStyle(.secondary) }
                    if !repository.isEnabled { Text(loc.string("common.off")).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Color.secondary.opacity(0.2)).cornerRadius(4) }
                }
                HStack(spacing: 12) {
                    Label(repository.branch, systemImage: "arrow.triangle.branch").foregroundStyle(.blue)
                    Label(repository.formattedCheckInterval, systemImage: "clock")
                    Label("\(repository.triggers.count) \(loc.string("repo.triggers"))", systemImage: "bolt")
                }.font(.caption).foregroundStyle(.secondary)
                if let lastCheck = gitMonitor.lastCheckTimes[repository.id] {
                    HStack { Text("\(loc.string("check.last")): \(lastCheck, style: .relative)"); if let result = gitMonitor.lastCheckResults[repository.id] { Text("• \(result)") } }.font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    duplicateRepository()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                }
                .frame(width: 32, height: 32)
                .buttonStyle(.bordered)
                .help("Duplicar repositório")
                
                Button {
                    Task { await gitMonitor.forceBuild(for: repository) }
                } label: {
                    Image(systemName: "hammer.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14) // Icon size
                }
                .frame(width: 32, height: 32)
                .buttonStyle(.bordered)
                .help(loc.string("action.forceBuild"))
                
                Button {
                    Task { await gitMonitor.checkRepository(repository) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                }
                .frame(width: 32, height: 32)
                .buttonStyle(.bordered)
                .help(loc.string("action.checkNow"))
                
                Button {
                    withAnimation {
                         repository.isEnabled.toggle()
                         if !repository.isEnabled { gitMonitor.stopTimer(for: repository) }
                         else { gitMonitor.startTimer(for: repository) }
                    }
                } label: {
                    Image(systemName: repository.isEnabled ? "pause.fill" : "play.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                }
                .frame(width: 32, height: 32)
                .buttonStyle(.bordered)
                .help(repository.isEnabled ? loc.string("action.pause") : loc.string("action.resume"))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    
    private func duplicateRepository() {
        // Create a new repository with copied values
        let newRepo = WatchedRepository(
            name: "\(repository.name) COPIA",
            localPath: repository.localPath,
            remoteName: repository.remoteName,
            branch: repository.branch,
            checkIntervalSeconds: repository.checkIntervalSeconds
        )
        newRepo.isEnabled = false // Start disabled to allow editing
        newRepo.watchTags = repository.watchTags
        newRepo.lastKnownTag = repository.lastKnownTag
        newRepo.notificationGroup = repository.notificationGroup
        
        // Duplicate triggers
        for trigger in repository.triggers {
            let newTrigger = TriggerRule(
                name: trigger.name,
                command: trigger.command,
                commitFlag: trigger.commitFlag
            )
            newTrigger.workingDirectory = trigger.workingDirectory
            newTrigger.isEnabled = trigger.isEnabled
            newTrigger.priority = trigger.priority
            newRepo.triggers.append(newTrigger)
        }
        
        modelContext.insert(newRepo)
        try? modelContext.save()
        
        print("✅ Repositório duplicado: \(newRepo.name)")
    }
    
    private var statusColor: Color { guard repository.isEnabled else { return .gray }; switch repository.currentStatus { case .idle: return .green; case .checking: return .yellow; case .building: return .blue; case .success: return .green; case .failed, .error: return .red } }
    private var statusIcon: String { switch repository.currentStatus { case .idle: return "checkmark.circle"; case .checking: return "arrow.triangle.2.circlepath"; case .building: return "hammer"; case .success: return "checkmark.circle.fill"; case .failed, .error: return "xmark.circle.fill" } }
}
//
//  EmptyStateView.swift
//  GitPilot
//
//  Copyright (c) 2024 Megamil
//  Contact: eduardo@megamil.com.br
//

import SwiftUI

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let btnTitle = actionTitle, let btnAction = action {
                Button(btnTitle, action: btnAction)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
