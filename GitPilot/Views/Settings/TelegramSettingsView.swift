//
//  TelegramSettingsView.swift
//  GitPilot
//

import SwiftUI

/// Legacy - Telegram is now configured per notification group
struct TelegramSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "info.circle")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            
            Text("Configuração de Telegram")
                .font(.headline)
            
            Text("O Telegram agora é configurado por grupo de notificação.\n\nVá para a aba 'Grupos' na janela principal para configurar integrações de Telegram e Teams para cada projeto.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
