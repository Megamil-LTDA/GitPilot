//
//  TriggerRuleFormView.swift
//  GitPilot
//

import SwiftUI

struct TriggerRuleFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var loc = LocalizationManager.shared
    
    let trigger: TriggerRule?
    let onSave: (TriggerRule) -> Void
    
    @State private var name = ""
    @State private var commitFlag = ""
    @State private var command = ""
    @State private var workingDirectory = ""
    @State private var priority = 0
    @State private var isEnabled = true
    
    private var isEditing: Bool { trigger != nil }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? loc.string("trigger.edit") : loc.string("trigger.add")).font(.headline)
                Spacer()
                Button(loc.string("action.cancel")) { dismiss() }.keyboardShortcut(.escape)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox(loc.string("group.info")) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(loc.string("trigger.name"), text: $name)
                                .textFieldStyle(.roundedBorder)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc.string("trigger.flag")).font(.caption).foregroundStyle(.secondary)
                                TextField(loc.string("trigger.flagPlaceholder"), text: $commitFlag)
                                    .textFieldStyle(.roundedBorder)
                                Text("💡 Use vírgula para múltiplas flags: --prod, --deploy")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc.string("trigger.command")).font(.caption).foregroundStyle(.secondary)
                                TextEditor(text: $command)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minHeight: 100, maxHeight: 200)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    .disableAutocorrection(true)
                                    .textContentType(.none)
                                Text("💡 Use \\n para múltiplos comandos ou scripts complexos")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc.string("trigger.workDir")).font(.caption).foregroundStyle(.secondary)
                                HStack {
                                    TextField(loc.string("trigger.workDirPlaceholder"), text: $workingDirectory)
                                        .textFieldStyle(.roundedBorder)
                                    Button {
                                        selectWorkingDirectory()
                                    } label: {
                                        Image(systemName: "folder")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    
                    GroupBox(loc.string("common.preferences")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker(loc.string("trigger.priority"), selection: $priority) {
                                ForEach(0..<10, id: \.self) { p in
                                    Text("\(p)").tag(p)
                                }
                            }
                            .pickerStyle(.menu)
                            
                            Text(loc.string("trigger.priorityHelp"))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            
                            Toggle(loc.string("repo.enabled"), isOn: $isEnabled)
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button(loc.string("action.cancel")) { dismiss() }
                Button(isEditing ? loc.string("action.save") : loc.string("action.add")) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || command.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 450, minHeight: 450)
        .onAppear { loadData() }
    }
    
    private func loadData() {
        guard let t = trigger else { return }
        name = t.name
        commitFlag = t.commitFlag ?? ""
        command = t.command
        workingDirectory = t.workingDirectory ?? ""
        priority = t.priority
        isEnabled = t.isEnabled
    }
    
    private func save() {
        let t = trigger ?? TriggerRule(name: "", command: "")
        t.name = name
        t.commitFlag = commitFlag.isEmpty ? nil : commitFlag
        // Sanitize curly quotes to straight quotes to avoid shell errors
        t.command = command
            .replacingOccurrences(of: "\u{201C}", with: "\"")  // Left double curly quote
            .replacingOccurrences(of: "\u{201D}", with: "\"")  // Right double curly quote
            .replacingOccurrences(of: "\u{2018}", with: "'")   // Left single curly quote
            .replacingOccurrences(of: "\u{2019}", with: "'")   // Right single curly quote
        t.workingDirectory = workingDirectory.isEmpty ? nil : workingDirectory
        t.priority = priority
        t.isEnabled = isEnabled
        onSave(t)
        dismiss()
    }
    
    private func selectWorkingDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Selecione o diretório de trabalho para o comando"
        
        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }
}
