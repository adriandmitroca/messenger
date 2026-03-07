import AppKit
import WebKit
import UserNotifications

final class WebViewCoordinator: NSObject,
    WKNavigationDelegate,
    WKUIDelegate,
    WKScriptMessageHandler,
    WKDownloadDelegate
{
    weak var webView: WKWebView?
    var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    // MARK: - Domain Filtering

    private static let allowedDomains = [
        "facebook.com", "www.facebook.com",
        "messenger.com", "www.messenger.com",
        "fbcdn.net", "facebook.net",
        "fbsbx.com", "accountkit.com", "fb.com",
    ]

    private static func isAllowedDomain(_ host: String) -> Bool {
        allowedDomains.contains { host.hasSuffix($0) }
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let handler = Constants.MessageHandler(rawValue: message.name) else { return }
        switch handler {
        case .notificationBridge:
            if SettingsManager.shared.notificationsEnabled {
                handleNotification(message.body)
            }
        case .unreadCount:
            if let count = message.body as? Int, count != appState.unreadCount {
                appState.unreadCount = count
                if SettingsManager.shared.dockBadgeEnabled {
                    NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
                } else {
                    NSApplication.shared.dockTile.badgeLabel = nil
                }
            }
        case .externalLink:
            if let urlString = message.body as? String, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else {
            return .allow
        }

        let host = url.host ?? ""

        if Self.isAllowedDomain(host) || url.scheme == "about" || url.scheme == "data" {
            return .allow
        } else {
            NSWorkspace.shared.open(url)
            return .cancel
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            if Self.isAllowedDomain(url.host ?? "") {
                webView.load(navigationAction.request)
            } else {
                NSWorkspace.shared.open(url)
            }
        }
        return nil
    }

    // MARK: - Permission Requests

    func webView(
        _ webView: WKWebView,
        decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
        initiatedBy frame: WKFrameInfo,
        type: WKMediaCaptureType
    ) async -> WKPermissionDecision {
        Self.isAllowedDomain(origin.host) ? .grant : .deny
    }

    // MARK: - Downloads

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String) async -> URL? {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        return downloadsURL.appendingPathComponent(suggestedFilename)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        #if DEBUG
        injectFromDisk(into: webView)
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.appState.isLoading = false
        }
    }

    #if DEBUG
    private func injectFromDisk(into webView: WKWebView) {
        if let css = ContentInjector.loadCSS() {
            let js = """
                document.querySelectorAll('[data-hot-reload]').forEach(e => e.remove());
                var style = document.createElement('style');
                style.dataset.hotReload = '1';
                style.textContent = `\(css)`;
                document.head.appendChild(style);
            """
            webView.evaluateJavaScript(js)
        }
    }
    #endif

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    // MARK: - Native Notifications

    private func handleNotification(_ body: Any) {
        guard let dict = body as? [String: Any],
              let title = dict["title"] as? String else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = (dict["body"] as? String) ?? ""
        content.sound = SettingsManager.shared.soundEnabled ? .default : nil
        content.categoryIdentifier = Constants.notificationCategory

        let identifier = (dict["tag"] as? String) ?? UUID().uuidString

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
