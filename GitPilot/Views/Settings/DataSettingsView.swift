//
//  DataSettingsView.swift
//  GitPilot
//

import SwiftUI
import SwiftData

struct DataSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var groups: [NotificationGroup]
    @Query private var repositories: [WatchedRepository]
    @ObservedObject var loc = LocalizationManager.shared
    
    @State private var exportResult: String?
    @State private var importResult: String?
    @State private var showingExportSuccess = false
    @State private var showingImportSuccess = false
    @State private var showingImportError = false
    @State private var errorMessage = ""
    @State private var showingResetConfirmation = false
    
    var body: some View {
        Form {
            


            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label(loc.string("data.export"), systemImage: "square.and.arrow.up")
                        .font(.headline)
                    
                    Text(loc.string("data.exportDescription"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("\(loc.string("data.dataCount")): \(groups.count) \(loc.string("sidebar.groups").lowercased()), \(repositories.count) \(loc.string("sidebar.repositories").lowercased())")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        Spacer()
                        
                        Button(loc.string("action.export")) { exportData() }
                            .buttonStyle(.borderedProminent)
                            .disabled(groups.isEmpty && repositories.isEmpty)
                    }
                    
                    if let result = exportResult {
                        Text(result).font(.caption).foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label(loc.string("data.import"), systemImage: "square.and.arrow.down")
                        .font(.headline)
                    
                    Text(loc.string("data.importDescription"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Spacer()
                        Button(loc.string("action.import")) { importData() }
                            .buttonStyle(.bordered)
                    }
                    
                    if let result = importResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("Erro") || result.contains("Error") ? .red : .green)
                    }
                }
                .padding(.vertical, 4)
            }
            
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Resetar Sistema", systemImage: "trash.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    
                    Text("Esta ação irá remover TODOS os dados do GitPilot. Grupos, Repositórios, Logs e Histórico serão apagados permanentemente.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Spacer()
                        Button("Limpar Tudo", role: .destructive) { showingResetConfirmation = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(loc.string("settings.language"), systemImage: "globe")
                        .font(.headline)
                    
                    LanguagePicker()
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .alert(loc.string("data.exportSuccess"), isPresented: $showingExportSuccess) {
            Button("OK") {}
        } message: {
            Text(exportResult ?? "")
        }
        .alert(loc.string("data.importSuccess"), isPresented: $showingImportSuccess) {
            Button("OK") {}
        } message: {
            Text(importResult ?? "")
        }
                .alert("Resetar Sistema", isPresented: $showingResetConfirmation) {
            Button("Resetar Tudo", role: .destructive) { resetSystem() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Tem certeza absoluta? Todos os dados serão perdidos permanentemente.")
        }
        .alert("Error", isPresented: $showingImportError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    
    private func resetSystem() {
        do {
            // Manual delete loop safer for compatibility
            for group in groups { modelContext.delete(group) }
            for repo in repositories { modelContext.delete(repo) }
            
            let buildLogs = try modelContext.fetch(FetchDescriptor<BuildLog>())
            for log in buildLogs { modelContext.delete(log) }
            
            let checkLogs = try modelContext.fetch(FetchDescriptor<CheckLog>())
            for log in checkLogs { modelContext.delete(log) }
            
            try modelContext.save()
            exportResult = "Sistema resetado com sucesso."
            showingImportSuccess = true // Show success using import alert or export result text
        } catch {
            errorMessage = "Erro ao resetar: \(error.localizedDescription)"
            showingImportError = true
        }
    }


    private func exportData() {
        guard let data = ExportImportService.shared.exportData(groups: groups, repositories: repositories) else {
            exportResult = "Error"; return
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "gitpilot_config.json"
        panel.title = loc.string("data.export")
        panel.prompt = loc.string("action.export")
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                exportResult = "✅ \(groups.count) \(loc.string("sidebar.groups").lowercased()), \(repositories.count) \(loc.string("sidebar.repositories").lowercased())"
                showingExportSuccess = true
            } catch {
                exportResult = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func importData() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.title = loc.string("data.import")
        panel.prompt = loc.string("action.import")
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let result = ExportImportService.shared.importData(from: data, into: modelContext)
                
                switch result {
                case .success(let importResult):
                    self.importResult = "✅ \(importResult.summary)"
                    showingImportSuccess = true
                case .failure(let error):
                    self.importResult = "Error: \(error.localizedDescription)"
                    errorMessage = error.localizedDescription
                    showingImportError = true
                }
            } catch {
                importResult = "Error"
                errorMessage = error.localizedDescription
                showingImportError = true
            }
        }
    }
}

struct LanguagePicker: View {
    @ObservedObject var localization = LocalizationManager.shared
    
    var body: some View {
        Picker("", selection: $localization.currentLanguage) {
            ForEach(AppLanguage.allCases, id: \.self) { lang in
                HStack {
                    Text(lang.flag)
                    Text(lang.displayName)
                }
                .tag(lang)
            }
        }
        .pickerStyle(.radioGroup)
    }

}
