import AppKit
import Combine

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private var currentlyShowingBadge = false
    private weak var appState: AppState?

    func setup(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "message.fill",
                accessibilityDescription: "Messenger"
            )
            button.target = self
            button.action = #selector(statusItemClicked)
        }

        appState.$unreadCount
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateBadge() }
            .store(in: &cancellables)

        SettingsManager.shared.$menuBarBadgeEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateBadge() }
            .store(in: &cancellables)
    }

    private func updateBadge() {
        guard let button = statusItem?.button else { return }
        let showBadge = (appState?.unreadCount ?? 0) > 0 && SettingsManager.shared.menuBarBadgeEnabled
        guard showBadge != currentlyShowingBadge else { return }
        currentlyShowingBadge = showBadge
        button.image = NSImage(
            systemSymbolName: showBadge ? "message.badge.fill" : "message.fill",
            accessibilityDescription: "Messenger"
        )
    }

    @objc private func statusItemClicked() {
        (NSApplication.shared.delegate as? AppDelegate)?.showMainWindow()
    }
}
