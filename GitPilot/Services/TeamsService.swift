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
            "message": "🔔 GitPilot - Teste de conexão realizado com sucesso!"
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
        let message = """
        🚀 *Trigger Iniciando*
        
        📦 Repositório: \(repositoryName)
        🌿 Branch: \(branch)
        📝 Commit: \(commitHash)
        ⚡️ Trigger: \(triggerName)
        
        💬 \(commitMessage)
        """
        
        let payload: [String: Any] = ["message": message]
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
        let status = success ? "✅ SUCESSO" : "❌ FALHA"
        
        let message = """
        Build \(status)
        
        📦 Repositório: \(repositoryName)
        🌿 Branch: \(branch)
        📝 Commit: \(commitHash)
        ⚡️ Trigger: \(triggerName)
        ⏱ Duração: \(duration)
        
        💬 \(commitMessage)
        """
        
        let payload: [String: Any] = ["message": message]
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
