import SwiftUI
import Sparkle

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        TabView {
            GeneralTab(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            NotificationsTab(settings: settings)
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            UpdatesTab(updater: updater)
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .frame(width: 380, height: 200)
    }
}

private struct GeneralTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
        }
        .padding(20)
    }
}

private struct NotificationsTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
            Toggle("Notification sound", isOn: $settings.soundEnabled)
                .disabled(!settings.notificationsEnabled)
            Toggle("Dock badge", isOn: $settings.dockBadgeEnabled)
            Toggle("Menu bar badge", isOn: $settings.menuBarBadgeEnabled)
        }
        .padding(20)
    }
}

private struct UpdatesTab: View {
    let updater: SPUUpdater
    @State private var automaticallyChecks: Bool

    init(updater: SPUUpdater) {
        self.updater = updater
        self._automaticallyChecks = State(initialValue: updater.automaticallyChecksForUpdates)
    }

    var body: some View {
        Form {
            Toggle("Check for updates automatically", isOn: $automaticallyChecks)
                .onChange(of: automaticallyChecks) { _, newValue in
                    updater.automaticallyChecksForUpdates = newValue
                }

            Button("Check for Updates...") {
                updater.checkForUpdates()
            }
        }
        .padding(20)
    }
}
