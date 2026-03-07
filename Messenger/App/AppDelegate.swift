import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSWindowDelegate {
    private var mainWindow: NSWindow?
    private var windowRetryCount = 0

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

        DispatchQueue.main.async {
            self.captureMainWindow()
        }
    }

    private func captureMainWindow() {
        if let window = NSApplication.shared.windows.first(where: { $0.contentView != nil && !($0 is NSPanel) }) {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = NSColor(red: 36/255, green: 37/255, blue: 38/255, alpha: 1)
            window.delegate = self
            mainWindow = window
            return
        }
        windowRetryCount += 1
        if windowRetryCount < 50 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.captureMainWindow()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func showMainWindow() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            showMainWindow()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return await MainActor.run {
            if NSApplication.shared.isActive {
                return []
            } else {
                var options: UNNotificationPresentationOptions = [.banner, .badge]
                if SettingsManager.shared.soundEnabled {
                    options.insert(.sound)
                }
                return options
            }
        }
    }
}
