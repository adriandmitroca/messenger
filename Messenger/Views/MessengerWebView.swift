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
            Color(nsColor: Constants.windowBackground)
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
        for handler in Constants.MessageHandler.allCases {
            contentController.add(context.coordinator, name: handler.rawValue)
        }

        let webView = WebViewFactory.makeWebView(config: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webView = webView
        appState.webView = webView

        webView.load(URLRequest(url: Constants.messengerURL))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(appState: appState)
    }
}
