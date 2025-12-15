//
//  RepositoryFormView.swift
//  GitPilot
//

import SwiftUI
import SwiftData

struct RepositoryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var loc = LocalizationManager.shared
    
    let repository: WatchedRepository?
    let groups: [NotificationGroup]
    
    @State private var name = ""
    @State private var localPath = ""
    @State private var remoteName = "origin"
    @State private var branch = "main"
    @State private var checkIntervalMinutes = 5
    @State private var isEnabled = true
    @State private var selectedGroupId: UUID?
    
    @State private var triggers: [TriggerRule] = []
    @State private var showingTriggerSheet = false
    @State private var editingTrigger: TriggerRule?
    
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var validationSuccess = false
    @State private var isValidating = false
    
    @State private var isValidPath = false
    @State private var availableBranches: [String] = []
    @State private var showingDeleteConfirmation = false
    @State private var hasLoadedBranches = false
    
    private var isEditing: Bool { repository != nil }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? loc.string("repo.edit") : loc.string("repo.add")).font(.headline)
                Spacer()
                // Removed redundant Cancel button from header
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox(loc.string("common.repository")) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(loc.string("repo.name"), text: $name).textFieldStyle(.roundedBorder)
                            
                            HStack {
                                TextField(loc.string("repo.path"), text: $localPath)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: localPath) { _, _ in validateRepository() }
                                Button(loc.string("action.browse")) { selectFolder() }
                            }
                            
                            // Validation Button moved here (below Path field)
                            if !localPath.isEmpty {
                                HStack {
                                    Button {
                                        validateAccess()
                                    } label: {
                                        if isValidating {
                                             HStack {
                                                 Text(loc.string("status.checking"))
                                                 ProgressView().controlSize(.small)
                                             }
                                        } else {
                                             Label(loc.string("repo.validateAccess"), systemImage: "network")
                                        }
                                    }
                                    .disabled(isValidating)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small) // Make it slightly smaller to fit well
                                    
                                    Spacer()
                                }
                            }

                            if !validationMessage.isEmpty {
                                Label(validationMessage, systemImage: isValidPath ? "checkmark.circle" : "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(isValidPath ? .green : .orange)
                            }
                        }
                    }
                    
                    GroupBox(loc.string("common.git")) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(loc.string("repo.remote")).font(.caption).foregroundStyle(.secondary)
                                    TextField("origin", text: $remoteName).textFieldStyle(.roundedBorder).frame(width: 100)
                                }
                                VStack(alignment: .leading) {
                                    Text(loc.string("repo.branch")).font(.caption).foregroundStyle(.secondary)
                                    if availableBranches.isEmpty {
                                        TextField("main", text: $branch).textFieldStyle(.roundedBorder).frame(width: 150)
                                    } else {
                                        Picker("", selection: $branch) {
                                            ForEach(availableBranches, id: \.self) { b in Text(b).tag(b) }
                                        }.frame(width: 150)
                                    }
                                }
                                Spacer()
                            }
                            
                            Text("\(loc.string("repo.currentBranch")): \(branch)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            
                            Picker(loc.string("repo.interval"), selection: $checkIntervalMinutes) {
                                Text(loc.string("time.1min")).tag(1)
                                Text(loc.string("time.2min")).tag(2)
                                Text(loc.string("time.5min")).tag(5)
                                Text(loc.string("time.10min")).tag(10)
                                Text(loc.string("time.30min")).tag(30)
                                Text(loc.string("time.1hour")).tag(60)
                            }
                            
                            Toggle(loc.string("repo.enabled"), isOn: $isEnabled)
                        }
                    }
                    
                    GroupBox(loc.string("group.notificationGroup")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker(loc.string("sidebar.groups"), selection: $selectedGroupId) {
                                Text(loc.string("group.none")).tag(nil as UUID?)
                                ForEach(groups) { g in
                                    HStack {
                                        Circle().fill(Color(hex: g.color) ?? .blue).frame(width: 10, height: 10)
                                        Text(g.name)
                                    }.tag(g.id as UUID?)
                                }
                            }
                            
                            if groups.isEmpty {
                                Text(loc.string("group.createFirst"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    GroupBox(loc.string("trigger.title")) {
                        VStack(alignment: .leading, spacing: 8) {
                            if triggers.isEmpty {
                                Text(loc.string("trigger.empty")).foregroundStyle(.secondary).italic()
                            } else {
                                ForEach(triggers) { t in
                                    TriggerRowView(trigger: t)
                                        .onTapGesture { editingTrigger = t }
                                }
                            }
                            Button(action: {
                                editingTrigger = nil // New trigger
                                showingTriggerSheet = true
                            }) {
                                Label(loc.string("repo.addTrigger"), systemImage: "plus")
                            }.buttonStyle(.bordered) // Added buttonStyle to match original
                        }
                    }
                    
                    if isEditing {
                        Button(role: .destructive) { showingDeleteConfirmation = true } label: { Label(loc.string("action.delete"), systemImage: "trash") }
                    }
                    
                    // Validation Section moved to top
                }
                .padding()
            }
            
            Divider()
            HStack {
                Spacer()
                Button(loc.string("action.cancel")) { dismiss() }
                Button(isEditing ? loc.string("action.save") : loc.string("action.add")) { save() }.buttonStyle(.borderedProminent).disabled(name.isEmpty || localPath.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 550, minHeight: 650)
        .sheet(isPresented: $showingTriggerSheet) { // Changed from showingAddTrigger
            TriggerRuleFormView(trigger: nil) { newTrigger in
                triggers.append(newTrigger)
            }
        }
        .sheet(item: $editingTrigger) { trigger in // Changed closure parameter name
            TriggerRuleFormView(trigger: trigger) { updatedTrigger in // Changed closure parameter name
                if let index = triggers.firstIndex(where: { $0.id == updatedTrigger.id }) {
                    triggers[index] = updatedTrigger
                } else {
                    triggers.append(updatedTrigger)
                }
            }
        }
        .alert(loc.string("action.delete") + "?", isPresented: $showingDeleteConfirmation) {
            Button(loc.string("action.cancel"), role: .cancel) {}
            Button(loc.string("action.delete"), role: .destructive) { deleteRepository() }
        }
        .onAppear(perform: loadData)
        // Removed overlay to fix visibility issue
        .alert(isPresented: $showingValidationAlert) {
            Alert(
                title: Text(validationSuccess ? loc.string("repo.connectionOK") : loc.string("repo.connectionError")),
                message: Text(validationMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    func validateAccess() {
        let path = NSString(string: localPath).expandingTildeInPath
        let remote = remoteName.isEmpty ? "origin" : remoteName
        
        isValidating = true
        
        Task {
            do {
                // Dry run validation using fetch
                try await GitService.shared.fetch(at: path, remote: remote)
                
                await MainActor.run {
                    validationSuccess = true
                    validationMessage = loc.string("repo.accessConfirmed")
                    showingValidationAlert = true
                    isValidating = false
                }
            } catch {
                await MainActor.run {
                    validationSuccess = false
                    validationMessage = "\(loc.string("repo.accessFailed")):\n\(error.localizedDescription)"
                    showingValidationAlert = true
                    isValidating = false
                }
            }
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            localPath = url.path
            hasLoadedBranches = false
            validateRepository()
        }
    }
    
    private func validateRepository() {
        guard !localPath.isEmpty else { validationMessage = ""; isValidPath = false; return }
        let exp = NSString(string: localPath).expandingTildeInPath
        let git = (exp as NSString).appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: git) {
            validationMessage = loc.string("repo.validPath"); isValidPath = true
            if name.isEmpty { name = URL(fileURLWithPath: exp).lastPathComponent }
            loadBranches()
        } else if FileManager.default.fileExists(atPath: exp) {
            validationMessage = loc.string("repo.invalidPath"); isValidPath = false
        } else {
            validationMessage = loc.string("repo.pathNotFound"); isValidPath = false
        }
    }
    
    private func loadBranches() {
        let savedBranch = branch
        Task {
            do {
                let branches = try await GitService.shared.getRemoteBranches(at: NSString(string: localPath).expandingTildeInPath, remote: remoteName)
                await MainActor.run {
                    availableBranches = branches
                    if !isEditing && !hasLoadedBranches {
                        if branches.contains("main") { branch = "main" }
                        else if branches.contains("master") { branch = "master" }
                        else if let f = branches.first { branch = f }
                    } else {
                        if branches.contains(savedBranch) { branch = savedBranch }
                    }
                    hasLoadedBranches = true
                }
            } catch { print("Load branches error: \(error)") }
        }
    }
    
    private func loadData() {
        guard let r = repository else { return }
        name = r.name; localPath = r.localPath; remoteName = r.remoteName; branch = r.branch
        checkIntervalMinutes = r.checkIntervalSeconds / 60; isEnabled = r.isEnabled
        selectedGroupId = r.notificationGroup?.id; triggers = r.triggers
        hasLoadedBranches = true
        validateRepository()
    }
    
    private func save() {
        let exp = NSString(string: localPath).expandingTildeInPath
        let group = groups.first { $0.id == selectedGroupId }
        
        if let r = repository {
            r.name = name; r.localPath = exp; r.remoteName = remoteName; r.branch = branch
            r.checkIntervalSeconds = checkIntervalMinutes * 60; r.isEnabled = isEnabled; r.notificationGroup = group
            r.triggers.removeAll()
            for t in triggers { t.repository = r; r.triggers.append(t) }
        } else {
            let nr = WatchedRepository(name: name, localPath: exp, remoteName: remoteName, branch: branch, checkIntervalSeconds: checkIntervalMinutes * 60, isEnabled: isEnabled, notificationGroup: group)
            for t in triggers { t.repository = nr; nr.triggers.append(t) }
            modelContext.insert(nr)
        }
        try? modelContext.save(); dismiss()
    }
    
    private func deleteRepository() {
        guard let r = repository else { return }
        modelContext.delete(r); try? modelContext.save(); dismiss()
    }
}

struct TriggerRowView: View {
    let trigger: TriggerRule
    @ObservedObject var loc = LocalizationManager.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(trigger.name).font(.subheadline.bold())
                HStack { Label(trigger.displayFlag, systemImage: "tag"); Text(trigger.command.prefix(30) + "...") }.font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !trigger.isEnabled { Text(loc.string("common.off")).font(.caption2).foregroundStyle(.secondary) }
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(8).background(Color.primary.opacity(0.05)).cornerRadius(6)
    }
}
