//
//  StatusItemView.swift
//  GitPilot
//
//  Copyright (c) 2026 Megamil
//  Contact: eduardo@megamil.com.br
//

import SwiftUI

struct StatusItemView: View {
    let status: GlobalStatus
    
    var body: some View {
        HStack(spacing: 2) {
            // App icon - rocket emoji
            Text("🚀")
                .font(.system(size: 12))
            
            // Status indicator dot
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
        }
    }
}
