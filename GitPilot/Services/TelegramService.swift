//
//  TelegramService.swift
//  GitPilot
//

import Foundation

class TelegramService {
    static let shared = TelegramService()
    private init() {}
    
    /// Test connection with specific token and chat ID
    func testConnection(token: String, chatId: String) async -> Result<Void, Error> {
        let message = "🔔 GitPilot - Teste de conexão realizado com sucesso!"
        return await sendMessage(token: token, chatId: chatId, message: message)
    }
    
    /// Send build notification using specific token and chat ID
    func sendBuildNotification(
        token: String,
        chatId: String,
        repositoryName: String,
        branch: String,
        commitHash: String,
        commitMessage: String,
        triggerName: String,
        duration: String,
        success: Bool
    ) async {
        let emoji = success ? "✅" : "❌"
        let status = success ? "SUCESSO" : "FALHA"
        
        let message = """
        \(emoji) *Build \(status)*
        
        📦 *Repositório:* \(repositoryName)
        🌿 *Branch:* \(branch)
        📝 *Commit:* `\(commitHash)`
        💬 \(commitMessage)
        
        ⚡️ *Trigger:* \(triggerName)
        ⏱ *Duração:* \(duration)
        """
        
        _ = await sendMessage(token: token, chatId: chatId, message: message)
    }
    
    private func sendMessage(token: String, chatId: String, message: String) async -> Result<Void, Error> {
        let urlString = "https://api.telegram.org/bot\(token)/sendMessage"
        
        guard let url = URL(string: urlString) else {
            return .failure(NSError(domain: "TelegramService", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL inválida"]))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "chat_id": chatId,
            "text": message,
            "parse_mode": "Markdown"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NSError(domain: "TelegramService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Resposta inválida"]))
            }
            
            if httpResponse.statusCode == 200 {
                return .success(())
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Erro desconhecido"
                return .failure(NSError(domain: "TelegramService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage]))
            }
        } catch {
            return .failure(error)
        }
    }
}
