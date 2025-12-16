//
//  NotificationGroupFormView.swift
//  GitPilot
//

import SwiftUI
import SwiftData

struct NotificationGroupFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var loc = LocalizationManager.shared
    
    let group: NotificationGroup?
    
    @State private var name = ""
    @State private var color = "#007AFF"
    @State private var telegramEnabled = false
    @State private var telegramBotToken = ""
    @State private var telegramChatId = ""
    @State private var teamsEnabled = false
    @State private var teamsWebhookUrl = ""
    @State private var notifyOnSuccess = true
    @State private var notifyOnFailure = true
    @State private var showingDeleteConfirmation = false
    
    // Test states
    @State private var isTelegramTesting = false
    @State private var telegramTestResult: String?
    @State private var isTeamsTesting = false
    @State private var teamsTestResult: String?
    
    private var isEditing: Bool { group != nil }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            formContent
            Divider()
            footerView
        }
        .frame(minWidth: 450, minHeight: 500)
        .alert(loc.string("action.delete") + "?", isPresented: $showingDeleteConfirmation) {
            Button(loc.string("action.cancel"), role: .cancel) {}
            Button(loc.string("action.delete"), role: .destructive) { deleteGroup() }
        }
        .onAppear { loadData() }
    }
    
    private var headerView: some View {
        HStack {
            Text(isEditing ? loc.string("group.edit") : loc.string("group.new")).font(.headline)
            Spacer()
            Button(loc.string("action.cancel")) { dismiss() }
        }
        .padding()
    }
    
    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                infoSection
                telegramSection
                teamsSection
                preferencesSection
                deleteSection
            }
            .padding()
        }
    }
    
    private var infoSection: some View {
        GroupBox(loc.string("group.info")) {
            VStack(alignment: .leading, spacing: 8) {
                TextField(loc.string("group.name"), text: $name)
                    .textFieldStyle(.roundedBorder)
                
                colorPicker
            }
        }
    }
    
    private var colorPicker: some View {
        let colors = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#5856D6", "#AF52DE"]
        return HStack(spacing: 8) {
            ForEach(colors, id: \.self) { c in
                Circle()
                    .fill(Color(hex: c) ?? .blue)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(color == c ? Color.primary : Color.clear, lineWidth: 2))
                    .onTapGesture { color = c }
            }
        }
    }
    
    private var telegramSection: some View {
        GroupBox("Telegram") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(loc.string("common.enable"), isOn: $telegramEnabled)
                if telegramEnabled {
                    SecureField(loc.string("telegram.botToken"), text: $telegramBotToken)
                        .textFieldStyle(.roundedBorder)
                    TextField(loc.string("telegram.chatId"), text: $telegramChatId)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Button {
                            testTelegram()
                        } label: {
                            if isTelegramTesting {
                                ProgressView().controlSize(.small)
                            } else {
                                Label(loc.string("action.test"), systemImage: "paperplane")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(telegramBotToken.isEmpty || telegramChatId.isEmpty || isTelegramTesting)
                        
                        if let result = telegramTestResult {
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(result.contains("✅") ? .green : .red)
                        }
                    }
                }
            }
        }
    }
    
    private var teamsSection: some View {
        GroupBox("Teams") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(loc.string("common.enable"), isOn: $teamsEnabled)
                if teamsEnabled {
                    TextField(loc.string("teams.webhookUrl"), text: $teamsWebhookUrl)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Button {
                            testTeams()
                        } label: {
                            if isTeamsTesting {
                                ProgressView().controlSize(.small)
                            } else {
                                Label(loc.string("action.test"), systemImage: "paperplane")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(teamsWebhookUrl.isEmpty || isTeamsTesting)
                        
                        if let result = teamsTestResult {
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(result.contains("✅") ? .green : .red)
                        }
                    }
                }
            }
        }
    }
    
    private var preferencesSection: some View {
        GroupBox(loc.string("common.preferences")) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(loc.string("settings.notifySuccess"), isOn: $notifyOnSuccess)
                Toggle(loc.string("settings.notifyFailure"), isOn: $notifyOnFailure)
            }
        }
    }
    
    @ViewBuilder
    private var deleteSection: some View {
        if isEditing {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label(loc.string("action.delete") + " " + loc.string("sidebar.groups"), systemImage: "trash")
            }
        }
    }
    
    private var footerView: some View {
        HStack {
            Spacer()
            Button(loc.string("action.cancel")) { dismiss() }
            Button(isEditing ? loc.string("action.save") : loc.string("action.create")) { save() }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
        }
        .padding()
    }
    
    private func loadData() {
        guard let g = group else { return }
        name = g.name
        color = g.color
        telegramEnabled = g.telegramEnabled
        telegramBotToken = g.telegramBotToken ?? ""
        telegramChatId = g.telegramChatId ?? ""
        teamsEnabled = g.teamsEnabled
        teamsWebhookUrl = g.teamsWebhookUrl ?? ""
        notifyOnSuccess = g.notifyOnSuccess
        notifyOnFailure = g.notifyOnFailure
    }
    
    private func save() {
        if let g = group {
            g.name = name; g.color = color
            g.telegramEnabled = telegramEnabled
            g.telegramBotToken = telegramEnabled ? telegramBotToken : nil
            g.telegramChatId = telegramEnabled ? telegramChatId : nil
            g.teamsEnabled = teamsEnabled
            g.teamsWebhookUrl = teamsEnabled ? teamsWebhookUrl : nil
            g.notifyOnSuccess = notifyOnSuccess
            g.notifyOnFailure = notifyOnFailure
        } else {
            let ng = NotificationGroup(
                name: name, color: color,
                telegramBotToken: telegramEnabled ? telegramBotToken : nil,
                telegramChatId: telegramEnabled ? telegramChatId : nil,
                telegramEnabled: telegramEnabled,
                teamsWebhookUrl: teamsEnabled ? teamsWebhookUrl : nil,
                teamsEnabled: teamsEnabled,
                notifyOnSuccess: notifyOnSuccess,
                notifyOnFailure: notifyOnFailure
            )
            modelContext.insert(ng)
        }
        try? modelContext.save(); dismiss()
    }
    
    private func deleteGroup() {
        guard let g = group else { return }
        modelContext.delete(g); try? modelContext.save(); dismiss()
    }
    
    // MARK: - Test Functions
    
    private func testTelegram() {
        isTelegramTesting = true
        telegramTestResult = nil
        
        Task {
            let result = await TelegramService.shared.testConnection(
                token: telegramBotToken,
                chatId: telegramChatId
            )
            
            await MainActor.run {
                isTelegramTesting = false
                switch result {
                case .success:
                    telegramTestResult = "✅ Enviado!"
                case .failure:
                    telegramTestResult = "❌ Falhou"
                }
            }
        }
    }
    
    private func testTeams() {
        isTeamsTesting = true
        teamsTestResult = nil
        
        Task {
            let result = await TeamsService.shared.testConnection(
                webhookUrl: teamsWebhookUrl
            )
            
            await MainActor.run {
                isTeamsTesting = false
                switch result {
                case .success:
                    teamsTestResult = "✅ Enviado!"
                case .failure:
                    teamsTestResult = "❌ Falhou"
                }
            }
        }
    }
}

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        h = h.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
