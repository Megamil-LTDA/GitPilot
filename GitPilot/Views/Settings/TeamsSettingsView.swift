//
//  TeamsSettingsView.swift
//  GitPilot
//

import SwiftUI

/// Legacy - Teams is now configured per notification group
struct TeamsSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "info.circle")
                .font(.largeTitle)
                .foregroundStyle(.purple)
            
            Text("Configuração de Teams")
                .font(.headline)
            
            Text("O Microsoft Teams agora é configurado por grupo de notificação.\n\nVá para a aba 'Grupos' na janela principal para configurar integrações de Telegram e Teams para cada projeto.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
