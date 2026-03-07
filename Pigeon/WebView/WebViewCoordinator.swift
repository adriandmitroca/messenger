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

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "notificationBridge":
            handleNotification(message.body)
        case "unreadCount":
            if let count = message.body as? Int {
                DispatchQueue.main.async {
                    self.appState.unreadCount = count
                    NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
                }
            }
        case "externalLink":
            if let urlString = message.body as? String, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }

    // MARK: - WKNavigationDelegate

    private static let allowedDomains = [
        "facebook.com", "www.facebook.com",
        "messenger.com", "www.messenger.com",
        "fbcdn.net", "facebook.net",
        "fbsbx.com", "accountkit.com", "fb.com",
    ]

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let host = url.host ?? ""

        let isAllowed = Self.allowedDomains.contains { host.hasSuffix($0) }

        if isAllowed || url.scheme == "about" || url.scheme == "data" {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            NSWorkspace.shared.open(url)
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            let host = url.host ?? ""
            if host.contains("facebook.com") || host.contains("messenger.com") {
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
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        if origin.host.contains("facebook.com") || origin.host.contains("messenger.com") {
            decisionHandler(.grant)
        } else {
            decisionHandler(.deny)
        }
    }

    // MARK: - Downloads

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destinationURL = downloadsURL.appendingPathComponent(suggestedFilename)
        completionHandler(destinationURL)
    }

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
        content.sound = .default
        content.categoryIdentifier = "MESSAGE"

        let identifier = (dict["tag"] as? String) ?? UUID().uuidString

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
