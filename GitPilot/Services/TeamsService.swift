//
//  TeamsService.swift
//  GitPilot
//

import Foundation

class TeamsService {
    static let shared = TeamsService()
    private init() {}
    
    /// Test connection with specific webhook URL
    func testConnection(webhookUrl: String) async -> Result<Void, Error> {
        let payload: [String: Any] = [
            "type": "message",
            "attachments": [[
                "contentType": "application/vnd.microsoft.card.adaptive",
                "content": [
                    "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                    "type": "AdaptiveCard",
                    "version": "1.4",
                    "body": [[
                        "type": "TextBlock",
                        "text": "🔔 GitPilot - Teste de conexão realizado com sucesso!",
                        "wrap": true,
                        "weight": "bolder"
                    ]]
                ]
            ]]
        ]
        return await sendPayload(webhookUrl: webhookUrl, payload: payload)
    }
    
    /// Send notification when a trigger is about to execute
    func sendTriggerStartNotification(
        webhookUrl: String,
        repositoryName: String,
        branch: String,
        commitHash: String,
        commitMessage: String,
        triggerName: String
    ) async {
        let payload: [String: Any] = [
            "type": "message",
            "attachments": [[
                "contentType": "application/vnd.microsoft.card.adaptive",
                "content": [
                    "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                    "type": "AdaptiveCard",
                    "version": "1.4",
                    "body": [
                        [
                            "type": "TextBlock",
                            "text": "🚀 Trigger Iniciando",
                            "wrap": true,
                            "weight": "bolder",
                            "size": "large",
                            "color": "accent"
                        ],
                        [
                            "type": "FactSet",
                            "facts": [
                                ["title": "📦 Repositório", "value": repositoryName],
                                ["title": "🌿 Branch", "value": branch],
                                ["title": "📝 Commit", "value": commitHash],
                                ["title": "⚡️ Trigger", "value": triggerName]
                            ]
                        ],
                        [
                            "type": "TextBlock",
                            "text": "💬 \(commitMessage)",
                            "wrap": true,
                            "isSubtle": true
                        ]
                    ]
                ]
            ]]
        ]
        
        _ = await sendPayload(webhookUrl: webhookUrl, payload: payload)
    }
    
    /// Send build notification using specific webhook URL
    func sendBuildNotification(
        webhookUrl: String,
        repositoryName: String,
        branch: String,
        commitHash: String,
        commitMessage: String,
        triggerName: String,
        duration: String,
        success: Bool
    ) async {
        let color = success ? "good" : "attention"
        let status = success ? "✅ SUCESSO" : "❌ FALHA"
        
        let payload: [String: Any] = [
            "type": "message",
            "attachments": [[
                "contentType": "application/vnd.microsoft.card.adaptive",
                "content": [
                    "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                    "type": "AdaptiveCard",
                    "version": "1.4",
                    "body": [
                        [
                            "type": "TextBlock",
                            "text": "Build \(status)",
                            "wrap": true,
                            "weight": "bolder",
                            "size": "large",
                            "color": color
                        ],
                        [
                            "type": "FactSet",
                            "facts": [
                                ["title": "📦 Repositório", "value": repositoryName],
                                ["title": "🌿 Branch", "value": branch],
                                ["title": "📝 Commit", "value": commitHash],
                                ["title": "⚡️ Trigger", "value": triggerName],
                                ["title": "⏱ Duração", "value": duration]
                            ]
                        ],
                        [
                            "type": "TextBlock",
                            "text": "💬 \(commitMessage)",
                            "wrap": true,
                            "isSubtle": true
                        ]
                    ]
                ]
            ]]
        ]
        
        _ = await sendPayload(webhookUrl: webhookUrl, payload: payload)
    }
    
    private func sendPayload(webhookUrl: String, payload: [String: Any]) async -> Result<Void, Error> {
        guard let url = URL(string: webhookUrl) else {
            return .failure(NSError(domain: "TeamsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL inválida"]))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NSError(domain: "TeamsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resposta inválida"]))
            }
            
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                return .success(())
            } else {
                return .failure(NSError(domain: "TeamsService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erro HTTP \(httpResponse.statusCode)"]))
            }
        } catch {
            return .failure(error)
        }
    }
}
