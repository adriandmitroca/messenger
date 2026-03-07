import AppKit

enum Constants {
    static let messengerURL = URL(string: "https://www.facebook.com/messages/")!
    static let windowBackground = NSColor(red: 36/255, green: 37/255, blue: 38/255, alpha: 1)
    static let notificationCategory = "MESSAGE"

    enum MessageHandler: String, CaseIterable {
        case notificationBridge
        case unreadCount
        case externalLink
    }
}
