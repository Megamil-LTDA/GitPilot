//
//  NotificationService.swift
//  GitPilot
//
//  Created with ❤️ for the open-source community
//  Licensed under MIT License
//

import Foundation
import UserNotifications

// MARK: - Notification Categories
struct NotificationCategories {
    static let buildResult = "BUILD_RESULT"
    static let triggerConfirmation = "TRIGGER_CONFIRMATION"
}

// MARK: - Notification Actions
struct NotificationActions {
    static let viewLogs = "VIEW_LOGS"
    static let dismiss = "DISMISS"
    static let execute = "EXECUTE_TRIGGER"
    static let reject = "REJECT_TRIGGER"
}

/// Service for native macOS notifications
actor NotificationService {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    /// Callbacks for trigger confirmation responses
    private var triggerConfirmationCallbacks: [String: (Bool) -> Void] = [:]
    
    private init() {}
    
    /// Setup notification categories - call once at app startup
    func setupCategories() {
        let loc = LocalizationManager.shared
        
        // Build result category
        let viewLogsAction = UNNotificationAction(
            identifier: NotificationActions.viewLogs,
            title: "View Logs",
            options: .foreground
        )
        
        let dismissAction = UNNotificationAction(
            identifier: NotificationActions.dismiss,
            title: "Dismiss",
            options: .destructive
        )
        
        let buildResultCategory = UNNotificationCategory(
            identifier: NotificationCategories.buildResult,
            actions: [viewLogsAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Trigger confirmation category
        let executeAction = UNNotificationAction(
            identifier: NotificationActions.execute,
            title: loc.string("notification.confirmExecute"),
            options: .foreground
        )
        
        let rejectAction = UNNotificationAction(
            identifier: NotificationActions.reject,
            title: loc.string("notification.reject"),
            options: .destructive
        )
        
        let triggerConfirmationCategory = UNNotificationCategory(
            identifier: NotificationCategories.triggerConfirmation,
            actions: [executeAction, rejectAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([buildResultCategory, triggerConfirmationCategory])
    }
    
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
    
    /// Send a trigger confirmation notification with Execute/Reject actions
    /// Returns the notification ID for tracking
    func sendTriggerConfirmation(
        repositoryName: String,
        triggerName: String,
        commitMessage: String,
        callback: @escaping (Bool) -> Void
    ) async -> String {
        let loc = LocalizationManager.shared
        let notificationId = UUID().uuidString
        
        // Store callback
        triggerConfirmationCallbacks[notificationId] = callback
        
        let content = UNMutableNotificationContent()
        content.title = "🔧 \(loc.string("notification.triggerDetected"))"
        content.subtitle = "\(repositoryName) → \(triggerName)"
        content.body = "\(commitMessage.prefix(100))\n\(loc.string("notification.autoExecuteIn"))"
        content.sound = .default
        content.categoryIdentifier = NotificationCategories.triggerConfirmation
        content.userInfo = ["notificationId": notificationId]
        
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        do {
            try await notificationCenter.add(request)
            print("📬 Trigger confirmation notification sent: \(notificationId)")
        } catch {
            print("Failed to send trigger confirmation: \(error)")
        }
        
        return notificationId
    }
    
    /// Handle notification action response
    func handleNotificationAction(notificationId: String, actionId: String) {
        guard let callback = triggerConfirmationCallbacks.removeValue(forKey: notificationId) else {
            print("⚠️ No callback found for notification: \(notificationId)")
            return
        }
        
        let shouldExecute = actionId == NotificationActions.execute
        print("📬 Notification action: \(actionId) for \(notificationId) -> execute: \(shouldExecute)")
        callback(shouldExecute)
    }
    
    /// Handle timeout - auto-execute and remove notification
    func handleTimeout(notificationId: String) {
        // Remove delivered notification to clean up
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationId])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId])
        
        guard let callback = triggerConfirmationCallbacks.removeValue(forKey: notificationId) else {
            print("⚠️ No callback found for timeout notification: \(notificationId)")
            return
        }
        
        print("⏰ Notification timeout - auto-executing: \(notificationId)")
        callback(true) // Auto-execute on timeout
    }
    
    /// Cancel a pending trigger confirmation
    func cancelTriggerConfirmation(notificationId: String) {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationId])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId])
        triggerConfirmationCallbacks.removeValue(forKey: notificationId)
        print("🚫 Cancelled trigger notification: \(notificationId)")
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
        content.categoryIdentifier = NotificationCategories.buildResult
        
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
