import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

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
