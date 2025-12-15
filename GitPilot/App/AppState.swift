//
//  AppState.swift
//  GitPilot
//
//  Created with ❤️ for the open-source community
//  Licensed under MIT License
//

import SwiftUI
import Combine

/// Global application state
class AppState: ObservableObject {
    static let shared = AppState()
    
    /// Overall status for the menu bar icon
    @Published var globalStatus: GlobalStatus = .idle
    
    /// Whether all monitoring is paused
    @Published var isPaused: Bool = false
    
    /// Current running builds count
    @Published var runningBuildsCount: Int = 0
    
    /// Last error message (if any)
    @Published var lastError: String?
    
    private init() {}
    
    /// Update global status based on repository states
    func updateGlobalStatus(repositories: [WatchedRepository], runningCount: Int, hasError: Bool) {
        runningBuildsCount = runningCount
        
        if isPaused {
            globalStatus = .paused
        } else if runningCount > 0 {
            globalStatus = .building
        } else if hasError {
            globalStatus = .error
        } else if repositories.contains(where: { $0.isChecking }) {
            globalStatus = .checking
        } else {
            globalStatus = .idle
        }
    }
}

/// Represents the overall app status shown in menu bar
enum GlobalStatus: String, CaseIterable {
    case idle       // Green - all good, waiting
    case checking   // Yellow - fetching/comparing
    case building   // Blue - running a command
    case error      // Red - something failed
    case paused     // Gray - monitoring disabled
    
    var color: Color {
        switch self {
        case .idle: return .green
        case .checking: return .yellow
        case .building: return .blue
        case .error: return .red
        case .paused: return .gray
        }
    }
    
    var iconName: String {
        switch self {
        case .idle: return "circle.fill"
        case .checking: return "arrow.triangle.2.circlepath"
        case .building: return "hammer.fill"
        case .error: return "exclamationmark.circle.fill"
        case .paused: return "pause.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .idle: return "Monitoring active"
        case .checking: return "Checking for updates..."
        case .building: return "Build in progress..."
        case .error: return "Error occurred"
        case .paused: return "Monitoring paused"
        }
    }
}
