import AppKit
import Combine
import ServiceManagement

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private enum Keys {
        static let notificationsEnabled = "notificationsEnabled"
        static let soundEnabled = "soundEnabled"
        static let dockBadgeEnabled = "dockBadgeEnabled"
        static let menuBarBadgeEnabled = "menuBarBadgeEnabled"
        static let launchAtLogin = "launchAtLogin"
    }

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Keys.soundEnabled) }
    }

    @Published var dockBadgeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dockBadgeEnabled, forKey: Keys.dockBadgeEnabled)
            if !dockBadgeEnabled {
                NSApplication.shared.dockTile.badgeLabel = nil
            }
        }
    }

    @Published var menuBarBadgeEnabled: Bool {
        didSet { UserDefaults.standard.set(menuBarBadgeEnabled, forKey: Keys.menuBarBadgeEnabled) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin()
        }
    }

    private init() {
        UserDefaults.standard.register(defaults: [
            Keys.notificationsEnabled: true,
            Keys.soundEnabled: true,
            Keys.dockBadgeEnabled: true,
            Keys.menuBarBadgeEnabled: true,
        ])

        let defaults = UserDefaults.standard
        self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        self.soundEnabled = defaults.bool(forKey: Keys.soundEnabled)
        self.dockBadgeEnabled = defaults.bool(forKey: Keys.dockBadgeEnabled)
        self.menuBarBadgeEnabled = defaults.bool(forKey: Keys.menuBarBadgeEnabled)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
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
