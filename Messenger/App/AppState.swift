import Foundation
import WebKit

final class AppState: ObservableObject {
    @Published var unreadCount: Int = 0
    weak var webView: WKWebView?
}
