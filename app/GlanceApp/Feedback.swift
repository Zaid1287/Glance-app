import Foundation
import GlanceCore
#if canImport(UIKit)
import UIKit
#endif
import UserNotifications

/// Haptic feedback when a task finishes. Fires only with the app foregrounded
/// (UIKit feedback generators are no-ops in the background — the completion
/// notification carries the buzz there).
enum Haptics {
    @MainActor
    static func taskFinished(success: Bool) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(success ? .success : .error)
        #endif
    }
}

/// Local completion notification — buzzes/sounds when the app is in the
/// background, and satisfies "notify on completion" (F7).
enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func taskFinished(_ task: TrackedTask) {
        let content = UNMutableNotificationContent()
        content.title = task.state == .failed ? "Failed" : "Done"
        content.body = task.name
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "glance.done.\(task.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
