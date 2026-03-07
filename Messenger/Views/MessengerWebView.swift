import SwiftUI
import WebKit

struct MessengerWebView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            WebViewWrapper()
                .environmentObject(appState)
                .opacity(appState.isLoading ? 0 : 1)

            if appState.isLoading {
                loadingView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isLoading)
    }

    private var loadingView: some View {
        ZStack {
            Color(nsColor: NSColor(red: 36/255, green: 37/255, blue: 38/255, alpha: 1))
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressIndicator()
                    .frame(width: 32, height: 32)
                Text("Loading Messenger…")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProgressIndicator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSProgressIndicator {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .regular
        indicator.startAnimation(nil)
        return indicator
    }

    func updateNSView(_ nsView: NSProgressIndicator, context: Context) {}
}

struct WebViewWrapper: NSViewRepresentable {
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
        appState.webView = webView

        let url = URL(string: "https://www.facebook.com/messages/")!
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(appState: appState)
    }
}
