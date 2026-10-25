import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

/// Manages native iOS local notifications for incoming chat messages.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var recentMessages: [String: Date] = [:]
    private let deduplicationQueue = DispatchQueue(label: "com.instachat.notifications.dedup")

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Requests user authorization for banner, sound, and badge alerts.
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[NotificationManager] Permission error: \(error.localizedDescription)")
            } else {
                print("[NotificationManager] Permission granted: \(granted)")
            }
        }
    }

    /// Schedules an immediate native notification.
    func scheduleNotification(title: String, body: String) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Message" : title
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanBody.isEmpty else { return }

        // Deduplicate messages received within 4 seconds
        let deduplicationKey = "\(cleanTitle)::\(cleanBody)"
        var shouldPost = false

        deduplicationQueue.sync {
            let now = Date()
            if let lastPosted = recentMessages[deduplicationKey], now.timeIntervalSince(lastPosted) < 4.0 {
                shouldPost = false
            } else {
                recentMessages[deduplicationKey] = now
                shouldPost = true
                // Prune old keys
                recentMessages = recentMessages.filter { now.timeIntervalSince($0.value) < 30.0 }
            }
        }

        guard shouldPost else { return }

        let content = UNMutableNotificationContent()
        content.title = cleanTitle
        content.body = cleanBody
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[NotificationManager] Error scheduling notification: \(error.localizedDescription)")
            }
        }

        #if canImport(UIKit)
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
        #endif
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Allows notifications to display as banners and play sounds even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        #if canImport(UIKit)
        completionHandler([.banner, .sound, .badge, .list])
        #else
        completionHandler([.sound, .badge])
        #endif
    }
}
