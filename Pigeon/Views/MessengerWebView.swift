import SwiftUI
import WebKit

struct MessengerWebView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeNSView(context: Context) -> WKWebView {
        let config = WebViewFactory.makeConfiguration()

        let contentController = config.userContentController
        contentController.add(context.coordinator, name: "notificationBridge")
        contentController.add(context.coordinator, name: "unreadCount")
        contentController.add(context.coordinator, name: "externalLink")

        let webView = WebViewFactory.makeWebView(config: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webView = webView

        let url = URL(string: "https://www.facebook.com/messages/")!
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(appState: appState)
    }
}
