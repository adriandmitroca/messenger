import SwiftUI
import WebKit

@main
struct MessengerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    @State private var statusBar: StatusBarController?

    var body: some Scene {
        WindowGroup {
            MessengerWebView()
                .environmentObject(appState)
                .ignoresSafeArea()
                .frame(minWidth: 400, idealWidth: 900, minHeight: 500, idealHeight: 700)
                .onAppear {
                    let controller = StatusBarController()
                    controller.setup(appState: appState)
                    statusBar = controller
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Message") {
                    appState.webView?.evaluateJavaScript(
                        "document.querySelector('[aria-label=\"New message\"]')?.click()"
                    )
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Reload") {
                    appState.webView?.reload()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Actual Size") {
                    appState.webView?.magnification = 1.0
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Zoom In") {
                    if let wv = appState.webView {
                        wv.magnification += 0.1
                    }
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    if let wv = appState.webView {
                        wv.magnification -= 0.1
                    }
                }
                .keyboardShortcut("-", modifiers: .command)
            }

            CommandMenu("Messenger") {
                Button("Search Conversations") {
                    appState.webView?.evaluateJavaScript(
                        "document.querySelector('[aria-label=\"Search Messenger\"]')?.click()"
                    )
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()

                Button("Log Out") {
                    Task {
                        await logout()
                    }
                }
            }
        }

        Settings {
            SettingsView()
        }
    }

    private func logout() async {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await dataStore.dataRecords(ofTypes: dataTypes)
        let fbRecords = records.filter { $0.displayName.contains("facebook") }
        await dataStore.removeData(
            ofTypes: dataTypes,
            for: fbRecords
        )
        appState.webView?.load(URLRequest(url: Constants.messengerURL))
    }
}
