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
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 3) {
            // Status indicator with icon based on state
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(status.color)
                .opacity(status == .building ? (isAnimating ? 0.5 : 1.0) : 1.0)
                .animation(status == .building ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: isAnimating)
            
            // Status dot as secondary indicator
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
        }
        .onAppear {
            if status == .building {
                isAnimating = true
            }
        }
        .onChange(of: status) { _, newStatus in
            isAnimating = newStatus == .building
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .idle: return "checkmark.circle.fill"
        case .checking: return "arrow.triangle.2.circlepath"
        case .building: return "hammer.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .paused: return "pause.circle.fill"
        }
    }
}
