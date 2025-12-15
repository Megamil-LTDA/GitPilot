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
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc.string("trigger.command")).font(.caption).foregroundStyle(.secondary)
                                TextField(loc.string("trigger.commandPlaceholder"), text: $command)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(loc.string("trigger.workDir")).font(.caption).foregroundStyle(.secondary)
                                TextField(loc.string("trigger.workDirPlaceholder"), text: $workingDirectory)
                                    .textFieldStyle(.roundedBorder)
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
        t.command = command
        t.workingDirectory = workingDirectory.isEmpty ? nil : workingDirectory
        t.priority = priority
        t.isEnabled = isEnabled
        onSave(t)
        dismiss()
    }
}
