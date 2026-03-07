import SwiftUI

@main
struct PigeonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MessengerWebView()
                .environmentObject(appState)
                .frame(minWidth: 400, idealWidth: 900, minHeight: 500, idealHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 900, height: 700)
    }
}
