import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("[Messenger] Notification permission granted")
            }
        }
        UNUserNotificationCenter.current().delegate = self

        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY",
            title: "Reply",
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a message..."
        )
        let category = UNNotificationCategory(
            identifier: "MESSAGE",
            actions: [replyAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if NSApplication.shared.isActive {
            completionHandler([])
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }
}
