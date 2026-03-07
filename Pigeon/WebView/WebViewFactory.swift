import WebKit

enum WebViewFactory {
    static func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true

        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pagePrefs

        let contentController = WKUserContentController()
        config.userContentController = contentController

        return config
    }

    static func makeWebView(config: WKWebViewConfiguration) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: config)

        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        #if DEBUG
        webView.isInspectable = true
        #endif

        return webView
    }
}
