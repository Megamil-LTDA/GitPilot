//
//  NotificationService.swift
//  GitPilot
//
//  Created with ❤️ for the open-source community
//  Licensed under MIT License
//

import Foundation
import UserNotifications

/// Service for native macOS notifications
actor NotificationService {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {}
    
    /// Request notification permissions
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }
    
    /// Check if notifications are authorized
    func isAuthorized() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    /// Send a build notification
    func sendBuildNotification(
        repositoryName: String,
        triggerName: String,
        success: Bool,
        duration: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = success ? "✅ Build Succeeded" : "❌ Build Failed"
        content.subtitle = repositoryName
        content.body = "\(triggerName) completed in \(duration)"
        content.sound = .default
        content.categoryIdentifier = "BUILD_RESULT"
        
        // Add action buttons
        let viewLogsAction = UNNotificationAction(
            identifier: "VIEW_LOGS",
            title: "View Logs",
            options: .foreground
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: .destructive
        )
        
        let category = UNNotificationCategory(
            identifier: "BUILD_RESULT",
            actions: [viewLogsAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([category])
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to send notification: \(error)")
        }
    }
    
    /// Send a generic notification
    func send(title: String, body: String, subtitle: String? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to send notification: \(error)")
        }
    }
    
    /// Send error notification
    func sendError(title: String, message: String, repositoryName: String? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ \(title)"
        content.body = message
        if let repo = repositoryName {
            content.subtitle = repo
        }
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try? await notificationCenter.add(request)
    }
}
