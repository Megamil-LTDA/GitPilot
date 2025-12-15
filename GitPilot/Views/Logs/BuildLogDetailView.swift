//
//  BuildLogDetailView.swift
//  GitPilot
//
//  Copyright (c) 2024 Megamil
//  Contact: eduardo@megamil.com.br
//

import SwiftUI
import SwiftData
import AppKit

struct BuildLogDetailView: View {
    let log: BuildLog
    var onRetryComplete: ((BuildLog) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var gitMonitor: GitMonitorService
    @Query(sort: \WatchedRepository.name) private var repositories: [WatchedRepository]
    @ObservedObject var loc = LocalizationManager.shared
    @State private var isRetrying = false
    @State private var copiedOutput = false
    
    // Check if this is the currently running build to show live output
    private var isLiveBuild: Bool {
        gitMonitor.currentBuildLog?.id == log.id
    }
    
    private var displayOutput: String {
        isLiveBuild ? gitMonitor.liveOutput : (log.output ?? "")
    }
    
    var isTruncated: Bool {
        displayOutput.count > 10000
    }
    
    var truncatedOutput: String {
        if isTruncated {
            return String(displayOutput.suffix(10000))
        }
        return displayOutput
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: isLiveBuild ? "hourglass" : log.status.icon)
                    .foregroundStyle(isLiveBuild ? .blue : (log.status == .success ? .green : log.status == .failed ? .red : .gray))
                    .font(.title2)
                    .symbolEffect(.pulse, isActive: isLiveBuild)
                
                Text(isLiveBuild ? "Build em Execução..." : loc.string("build.title")).font(.headline)
                
                if isLiveBuild {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.leading, 8)
                }
                
                Spacer()
                
                // Retry button for failed builds (only when not live)
                if log.status == .failed && !isLiveBuild {
                    Button {
                        isRetrying = true
                        Task {
                            if let newLog = await gitMonitor.retryBuild(buildLog: log, repositories: repositories) {
                                // Notify parent to open new log
                                onRetryComplete?(newLog)
                            }
                            isRetrying = false
                            dismiss()
                        }
                    } label: {
                        if isRetrying {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Label("Tentar Novamente", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isRetrying)
                }
                
                Button(loc.string("action.close")) { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Info Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(label: loc.string("build.status"), value: isLiveBuild ? "Em execução" : log.status.rawValue, valueColor: isLiveBuild ? .blue : (log.status == .success ? .green : log.status == .failed ? .red : .gray))
                            InfoRow(label: loc.string("build.repository"), value: log.repositoryName)
                            InfoRow(label: loc.string("build.trigger"), value: log.triggerName)
                            InfoRow(label: loc.string("build.commit"), value: log.shortCommitHash, isMonospaced: true)
                            InfoRow(label: loc.string("check.message"), value: log.commitMessage)
                            InfoRow(label: loc.string("build.duration"), value: isLiveBuild ? "Em andamento..." : log.formattedDuration)
                            InfoRow(label: loc.string("build.date"), value: formatDate(log.startedAt))
                            
                            if let exitCode = log.exitCode, !isLiveBuild {
                                InfoRow(label: "Exit Code", value: "\(exitCode)", valueColor: exitCode == 0 ? .green : .red)
                            }
                        }
                        .padding(4)
                    } label: {
                        Label(loc.string("group.info"), systemImage: "info.circle")
                    }
                    
                    // Command Section
                    GroupBox {
                        Text(log.command)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label(loc.string("trigger.command"), systemImage: "terminal")
                    }
                    
                    // Output Section (Live or Static)
                    GroupBox {
                        ScrollViewReader { scrollView in
                            ScrollView {
                                VStack(alignment: .leading) {
                                    Text(truncatedOutput)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id("outputEnd")
                                    
                                    if isTruncated {
                                        Text("... (Output truncado para evitar travamento. Salve o arquivo para ver completo)")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                            .padding(.top, 8)
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                            .onChange(of: gitMonitor.liveOutput) { _, _ in
                                if isLiveBuild {
                                    withAnimation {
                                        scrollView.scrollTo("outputEnd", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Label(isLiveBuild ? "Output (Live)" : "Output", systemImage: isLiveBuild ? "waveform" : "doc.text")
                            
                            if isLiveBuild {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                                    .overlay(
                                        Circle()
                                            .stroke(.red.opacity(0.5), lineWidth: 2)
                                            .scaleEffect(1.5)
                                    )
                                Text("LIVE")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.red)
                            }
                            
                            Spacer()
                            
                            // Copy button
                            Button { copyToClipboard() } label: {
                                Label(copiedOutput ? "Copiado!" : "Copiar", systemImage: copiedOutput ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .tint(copiedOutput ? .green : nil)
                            .disabled(displayOutput.isEmpty)
                            
                            // Save button (only when not live)
                            if !isLiveBuild {
                                Button { saveLogToFile() } label: {
                                    Label("Salvar .txt", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 500, idealHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(displayOutput, forType: .string)
        
        copiedOutput = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedOutput = false
        }
    }
    
    private func saveLogToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "build_\(log.repositoryName)_\(log.shortCommitHash).txt"
        panel.title = "Salvar Log"
        
        if panel.runModal() == .OK, let url = panel.url {
            var content = "GitPilot - Build Log\n"
            content += String(repeating: "=", count: 60) + "\n\n"
            content += "Status: \(log.status.rawValue)\n"
            content += "Repositório: \(log.repositoryName)\n"
            content += "Trigger: \(log.triggerName)\n"
            content += "Commit: \(log.shortCommitHash)\n"
            content += "Mensagem: \(log.commitMessage)\n"
            content += "Data: \(formatDate(log.startedAt))\n"
            content += "Duração: \(log.formattedDuration)\n"
            if let exitCode = log.exitCode {
                content += "Exit Code: \(exitCode)\n"
            }
            content += "\n" + String(repeating: "-", count: 60) + "\n"
            content += "Comando:\n\(log.command)\n"
            content += "\n" + String(repeating: "-", count: 60) + "\n"
            content += "Output:\n\(displayOutput)\n"
            
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Erro ao salvar: \(error)")
            }
        }
    }
}
