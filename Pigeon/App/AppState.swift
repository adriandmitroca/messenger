import Foundation
import WebKit

final class AppState: ObservableObject {
    @Published var unreadCount: Int = 0
    @Published var isConnected: Bool = true
    weak var webView: WKWebView?
}
