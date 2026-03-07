import Foundation

final class AppState: ObservableObject {
    @Published var unreadCount: Int = 0
    @Published var isConnected: Bool = true
}
