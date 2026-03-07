import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var cancellable: AnyCancellable?

    func setup(appState: AppState) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "message.fill",
                accessibilityDescription: "Messenger"
            )
            button.target = self
            button.action = #selector(statusItemClicked)
        }

        cancellable = appState.$unreadCount
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                self?.updateBadge(count: count)
            }
    }

    private func updateBadge(count: Int) {
        guard let button = statusItem?.button else { return }
        let showBadge = count > 0 && SettingsManager.shared.menuBarBadgeEnabled
        button.image = NSImage(
            systemSymbolName: showBadge ? "message.badge.fill" : "message.fill",
            accessibilityDescription: "Messenger"
        )
    }

    @objc private func statusItemClicked() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
