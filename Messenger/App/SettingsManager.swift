import AppKit
import Combine
import ServiceManagement

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }

    @Published var dockBadgeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dockBadgeEnabled, forKey: "dockBadgeEnabled")
            if !dockBadgeEnabled {
                NSApplication.shared.dockTile.badgeLabel = nil
            }
        }
    }

    @Published var menuBarBadgeEnabled: Bool {
        didSet { UserDefaults.standard.set(menuBarBadgeEnabled, forKey: "menuBarBadgeEnabled") }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }

    private init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: "notificationsEnabled") == nil {
            defaults.set(true, forKey: "notificationsEnabled")
        }
        if defaults.object(forKey: "soundEnabled") == nil {
            defaults.set(true, forKey: "soundEnabled")
        }
        if defaults.object(forKey: "dockBadgeEnabled") == nil {
            defaults.set(true, forKey: "dockBadgeEnabled")
        }
        if defaults.object(forKey: "menuBarBadgeEnabled") == nil {
            defaults.set(true, forKey: "menuBarBadgeEnabled")
        }

        self.notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        self.soundEnabled = defaults.bool(forKey: "soundEnabled")
        self.dockBadgeEnabled = defaults.bool(forKey: "dockBadgeEnabled")
        self.menuBarBadgeEnabled = defaults.bool(forKey: "menuBarBadgeEnabled")
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Messenger] Launch at login error: \(error)")
        }
    }
}
