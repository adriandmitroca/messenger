# Implementation Brief: Native macOS Facebook Messenger App

## Project Overview

A lightweight, native macOS application that provides a dedicated Facebook Messenger experience by wrapping `facebook.com/messages` in a `WKWebView` with CSS/JS injection to strip away the Facebook chrome. The app should feel like a first-class macOS citizen with proper notifications, menu bar integration, keyboard shortcuts, and minimal resource footprint.

**Target**: macOS 14.0+ (Sonoma), Swift 6, SwiftUI + AppKit hybrid  
**Distribution**: Direct `.dmg` download (notarized), potentially Mac App Store later  
**Estimated binary size**: ~5–8 MB (no Electron/Chromium bundled)

---

## Architecture

```
MessengerApp/
├── App/
│   ├── MessengerApp.swift           # @main entry point, AppDelegate setup
│   ├── AppDelegate.swift            # NSApplicationDelegate, global menu, dock badge
│   └── AppState.swift               # Observable global state (unread count, connection status)
├── Views/
│   ├── MainWindow.swift             # SwiftUI WindowGroup with toolbar
│   ├── MessengerWebView.swift       # NSViewRepresentable wrapping WKWebView
│   └── StatusBarController.swift    # Optional menu bar icon with unread count
├── WebView/
│   ├── WebViewCoordinator.swift     # WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler
│   ├── CookieManager.swift          # Session persistence via WKWebsiteDataStore
│   ├── ContentInjector.swift        # CSS/JS injection pipeline
│   └── NotificationBridge.swift     # JS → native notification forwarding
├── Injection/
│   ├── facebook-cleanup.css         # Hide Facebook UI elements
│   ├── facebook-cleanup.js          # DOM mutation observer for dynamic content removal
│   └── notification-bridge.js       # Intercept Messenger's notification system
├── Utilities/
│   ├── KeyboardShortcuts.swift      # Global and in-app shortcuts
│   └── ExternalLinkHandler.swift    # Route non-Messenger links to default browser
└── Resources/
    ├── Assets.xcassets               # App icon
    └── Messenger.entitlements        # Network, notifications, keychain entitlements
```

### Why SwiftUI + AppKit Hybrid

Pure SwiftUI doesn't yet give us the level of control needed for WKWebView integration, dock badge manipulation, or menu bar extras with the reliability required. The approach:

- **SwiftUI** for the window shell, toolbar, settings UI, and any overlay views
- **NSViewRepresentable** to bridge `WKWebView` into SwiftUI
- **AppDelegate** (via `@NSApplicationDelegateAdaptor`) for dock badge, global keyboard shortcuts, and `NSApplication`-level lifecycle events

---

## Core Component: WKWebView Setup

### Configuration

```swift
import WebKit

final class MessengerWebViewFactory {
    
    static func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        
        // CRITICAL: Use default (persistent) data store for cookie/session persistence
        // This survives app restarts. Do NOT use .nonPersistent()
        config.websiteDataStore = .default()
        
        // Allow inline media playback (voice messages, video calls)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Enable microphone/camera for calls
        // Requires NSMicrophoneUsageDescription and NSCameraUsageDescription in Info.plist
        config.allowsAirPlayForMediaPlayback = true
        
        // Web page preferences
        let pagePrefs = WKWebpagePreferences()
        pagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = pagePrefs
        
        // User content controller for CSS/JS injection and message bridge
        let contentController = WKUserContentController()
        
        // Inject CSS to hide Facebook noise (runs at document start)
        if let css = ContentInjector.loadCSS() {
            let cssScript = WKUserScript(
                source: """
                    var style = document.createElement('style');
                    style.textContent = `\(css)`;
                    document.head.appendChild(style);
                """,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            contentController.addUserScript(cssScript)
        }
        
        // Inject JS for DOM cleanup and notification bridge (runs at document end)
        if let js = ContentInjector.loadJS() {
            let jsScript = WKUserScript(
                source: js,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            contentController.addUserScript(jsScript)
        }
        
        config.userContentController = contentController
        
        return config
    }
    
    static func makeWebView(config: WKWebViewConfiguration) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: config)
        
        // Set a desktop user agent to ensure Facebook serves the full web experience
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        // Allow back/forward navigation gestures
        webView.allowsBackForwardNavigationGestures = true
        
        // Allow magnification
        webView.allowsMagnification = true
        
        // Enable developer tools in debug builds
        #if DEBUG
        webView.isInspectable = true  // macOS 13.3+ / Safari 16.4+
        #endif
        
        return webView
    }
}
```

### SwiftUI Bridge (NSViewRepresentable)

```swift
struct MessengerWebView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState
    
    func makeNSView(context: Context) -> WKWebView {
        let config = MessengerWebViewFactory.makeConfiguration()
        
        // Register message handlers BEFORE creating webview
        let contentController = config.userContentController
        contentController.add(context.coordinator, name: "notificationBridge")
        contentController.add(context.coordinator, name: "unreadCount")
        contentController.add(context.coordinator, name: "externalLink")
        
        let webView = MessengerWebViewFactory.makeWebView(config: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Load facebook.com/messages
        let url = URL(string: "https://www.facebook.com/messages/")!
        webView.load(URLRequest(url: url))
        
        // Store reference for later use (reload, navigation, etc.)
        context.coordinator.webView = webView
        
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No-op for now; webview manages its own state
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(appState: appState)
    }
}
```

---

## Authentication & Session Management

### How It Works

Authentication is entirely handled by Facebook's standard web login flow rendered inside the WKWebView. The user sees the normal Facebook login page, enters credentials (including 2FA if enabled), and Facebook sets session cookies. There is **no need to reverse-engineer any authentication protocol**.

### Cookie Persistence Strategy

`WKWebsiteDataStore.default()` persists cookies, localStorage, and IndexedDB to disk automatically. This means the user's session survives app restarts without re-authentication.

**Known issues and mitigations:**

1. **Session cookies vs. persistent cookies**: Facebook's `c_user` and `xs` cookies have long expiry times (typically 1 year), so they persist naturally. However, some auxiliary cookies may be session-only. The default data store handles this correctly — session cookies are cleared on app termination, but the critical auth cookies are persistent.

2. **WKWebView cookie loss on process termination**: There's a documented edge case where `WKWebView`'s web content process can be terminated by the OS under memory pressure, causing session cookies to be lost. Mitigation:

```swift
// In WebViewCoordinator
func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    // Web content process was killed (memory pressure, crash, etc.)
    // Simply reload — persistent cookies in WKWebsiteDataStore survive this
    webView.reload()
}
```

3. **Cookie backup to Keychain** (optional hardening): For extra resilience, periodically snapshot critical cookies to Keychain:

```swift
final class CookieManager {
    private let keychainService = "com.yourapp.messenger.cookies"
    
    func backupCriticalCookies() async {
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        let cookies = await cookieStore.allCookies()
        
        let fbCookies = cookies.filter { cookie in
            cookie.domain.contains("facebook.com") || cookie.domain.contains("messenger.com")
        }
        
        let criticalNames = ["c_user", "xs", "datr", "sb", "fr"]
        let criticalCookies = fbCookies.filter { criticalNames.contains($0.name) }
        
        // Serialize and store in Keychain
        if let data = try? NSKeyedArchiver.archivedData(
            withRootObject: criticalCookies.compactMap { $0.properties },
            requiringSecureCoding: false
        ) {
            KeychainHelper.save(data, service: keychainService, account: "fb-session")
        }
    }
    
    func restoreCookiesIfNeeded() async {
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        let existing = await cookieStore.allCookies()
        
        let hasSession = existing.contains { $0.name == "c_user" }
        guard !hasSession else { return }
        
        // Restore from Keychain
        guard let data = KeychainHelper.load(service: keychainService, account: "fb-session"),
              let properties = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(
                  ofClass: NSDictionary.self, from: data
              ) else { return }
        
        for props in properties {
            if let cookie = HTTPCookie(properties: props as! [HTTPCookiePropertyKey: Any]) {
                await cookieStore.setCookie(cookie)
            }
        }
    }
}
```

4. **Logout handling**: Provide a menu option that clears all Facebook-related data:

```swift
func logout() async {
    let dataStore = WKWebsiteDataStore.default()
    let records = await dataStore.dataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes())
    let fbRecords = records.filter { $0.displayName.contains("facebook") }
    await dataStore.removeData(
        ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
        for: fbRecords
    )
    KeychainHelper.delete(service: keychainService, account: "fb-session")
    // Reload to show login page
    coordinator.webView?.load(URLRequest(url: messengerURL))
}
```

### Two-Factor Authentication

2FA (TOTP, SMS, or security key) works natively in WKWebView since it's just a standard web form. Hardware security keys (WebAuthn/FIDO2) are supported by WKWebView on macOS 14+ via the platform authenticator. No special handling is needed.

---

## CSS/JS Injection: Stripping Facebook UI

This is the most critical and maintenance-intensive part of the project. Facebook's DOM structure changes frequently, so selectors need monitoring.

### CSS Injection (`facebook-cleanup.css`)

```css
/* === HIDE FACEBOOK NAVIGATION & CHROME === */

/* Top navigation bar */
div[role="banner"],
div[aria-label="Facebook"] {
    display: none !important;
}

/* Left sidebar (News Feed, Marketplace, Groups, etc.) */
div[role="navigation"]:not([aria-label*="Messenger"]):not([aria-label*="Chat"]) {
    display: none !important;
}

/* Facebook stories in Messenger */
div[aria-label="Stories"] {
    display: none !important;
}

/* Marketplace, Gaming, Watch links */
a[href*="/marketplace"],
a[href*="/gaming"],
a[href*="/watch"] {
    display: none !important;
}

/* Meta AI chat suggestions / prompts */
div[data-testid*="meda-ai"],
div[aria-label*="Meta AI"] {
    display: none !important;
}

/* "Create" and other Facebook action buttons */
div[aria-label="Create"],
div[aria-label="Notifications"],
div[aria-label="Account"] {
    display: none !important;
}

/* === EXPAND MESSENGER TO FULL WIDTH === */

/* Make the message panel take full available width */
div[role="main"] {
    margin-left: 0 !important;
    max-width: 100% !important;
}

/* === CUSTOM TITLE BAR AREA === */

/* Add padding for macOS traffic lights if using titlebar-less window */
body {
    padding-top: env(safe-area-inset-top, 0px);
}

/* === DARK MODE SUPPORT === */
@media (prefers-color-scheme: dark) {
    /* Facebook's Messenger already has dark mode; this ensures consistency 
       if any injected elements need theming */
    :root {
        color-scheme: dark;
    }
}
```

### JS Injection (`facebook-cleanup.js`)

```javascript
(function() {
    'use strict';
    
    // === DOM CLEANUP via MutationObserver ===
    // Facebook dynamically injects content, so CSS alone isn't enough.
    // We need to observe and remove elements as they appear.
    
    const SELECTORS_TO_REMOVE = [
        // Reels overlay prompts
        '[data-testid="reels_surface"]',
        // "People you may know" suggestions
        '[data-testid="pymk"]',
        // Ad-related containers in Messenger
        '[data-testid="messenger_ad"]',
        // Facebook notification toasts (we handle our own)
        '.notificationContainer:not([data-messenger])',
    ];
    
    const observer = new MutationObserver((mutations) => {
        for (const selector of SELECTORS_TO_REMOVE) {
            document.querySelectorAll(selector).forEach(el => el.remove());
        }
    });
    
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
    
    // === EXTERNAL LINK INTERCEPTION ===
    // Route non-Messenger links to the system browser
    
    document.addEventListener('click', (e) => {
        const anchor = e.target.closest('a[href]');
        if (!anchor) return;
        
        const href = anchor.href;
        const isMessengerLink = href.includes('facebook.com/messages') 
            || href.includes('messenger.com')
            || href.startsWith('#')
            || href.startsWith('javascript:');
        
        if (!isMessengerLink && href.startsWith('http')) {
            e.preventDefault();
            e.stopPropagation();
            // Send to native layer to open in default browser
            window.webkit.messageHandlers.externalLink.postMessage(href);
        }
    }, true);
    
    // === FILE DOWNLOAD INTERCEPTION ===
    // Ensure file downloads work correctly via native download handling
    
    document.addEventListener('click', (e) => {
        const anchor = e.target.closest('a[download]');
        if (anchor) {
            // WKWebView handles downloads natively on macOS 14+
            // No special handling needed, but log for debugging
            console.log('[Messenger] Download initiated:', anchor.href);
        }
    }, true);
    
})();
```

### Notification Bridge (`notification-bridge.js`)

```javascript
(function() {
    'use strict';
    
    // === INTERCEPT BROWSER NOTIFICATIONS ===
    // Facebook's web Messenger uses the Notification API.
    // We intercept it to forward to macOS native notifications.
    
    const OriginalNotification = window.Notification;
    
    // Always report notifications as granted (we handle permission natively)
    Object.defineProperty(window, 'Notification', {
        value: class FakeNotification {
            static get permission() { return 'granted'; }
            static requestPermission(cb) {
                if (cb) cb('granted');
                return Promise.resolve('granted');
            }
            
            constructor(title, options = {}) {
                // Forward to native macOS notification system
                window.webkit.messageHandlers.notificationBridge.postMessage({
                    title: title,
                    body: options.body || '',
                    icon: options.icon || '',
                    tag: options.tag || '',
                    data: options.data || {}
                });
                
                // Store callbacks for interaction handling
                this._onclick = null;
                this._onclose = null;
            }
            
            set onclick(fn) { this._onclick = fn; }
            get onclick() { return this._onclick; }
            set onclose(fn) { this._onclose = fn; }
            get onclose() { return this._onclose; }
            close() {}
        },
        writable: false,
        configurable: false
    });
    
    // === UNREAD COUNT OBSERVER ===
    // Watch the document title for unread message count changes
    // Facebook sets title to "Messenger (3)" or "Messages (3)" when there are unreads
    
    const titleObserver = new MutationObserver(() => {
        const title = document.title;
        const match = title.match(/\((\d+)\)/);
        const count = match ? parseInt(match[1], 0) : 0;
        window.webkit.messageHandlers.unreadCount.postMessage(count);
    });
    
    // Observe <title> changes
    const titleElement = document.querySelector('title');
    if (titleElement) {
        titleObserver.observe(titleElement, { childList: true });
    }
    
    // Also poll as a fallback (title observer can miss some updates)
    setInterval(() => {
        const title = document.title;
        const match = title.match(/\((\d+)\)/);
        const count = match ? parseInt(match[1], 0) : 0;
        window.webkit.messageHandlers.unreadCount.postMessage(count);
    }, 5000);
    
})();
```

---

## WebView Coordinator (Native Bridge)

```swift
final class WebViewCoordinator: NSObject, 
    WKNavigationDelegate, 
    WKUIDelegate,
    WKScriptMessageHandler,
    WKDownloadDelegate 
{
    weak var webView: WKWebView?
    var appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(
        _ controller: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "notificationBridge":
            handleNotification(message.body)
        case "unreadCount":
            if let count = message.body as? Int {
                DispatchQueue.main.async {
                    self.appState.unreadCount = count
                    NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
                }
            }
        case "externalLink":
            if let urlString = message.body as? String, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        let host = url.host ?? ""
        
        // Allow Facebook/Messenger domains
        let allowedDomains = [
            "facebook.com", "www.facebook.com",
            "messenger.com", "www.messenger.com",
            "fbcdn.net",           // CDN for media
            "facebook.net",        // Static assets
            "fbsbx.com",           // Sandbox
            "accountkit.com",      // Auth
            "fb.com",              // Short links
        ]
        
        let isAllowed = allowedDomains.contains { host.hasSuffix($0) }
        
        if isAllowed || url.scheme == "about" || url.scheme == "data" {
            decisionHandler(.allow)
        } else {
            // Open external links in default browser
            decisionHandler(.cancel)
            NSWorkspace.shared.open(url)
        }
    }
    
    // Handle new window requests (target="_blank") — open in same webview or externally
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let url = navigationAction.request.url {
            let host = url.host ?? ""
            if host.contains("facebook.com") || host.contains("messenger.com") {
                // Load in the same webview
                webView.load(navigationAction.request)
            } else {
                // Open externally
                NSWorkspace.shared.open(url)
            }
        }
        return nil
    }
    
    // MARK: - Permission Requests (Camera, Microphone)
    
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        // Auto-grant for Facebook domains (user already trusts the app)
        if origin.host.contains("facebook.com") || origin.host.contains("messenger.com") {
            decisionHandler(.grant)
        } else {
            decisionHandler(.deny)
        }
    }
    
    // MARK: - Downloads
    
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, 
                 didBecome download: WKDownload) {
        download.delegate = self
    }
    
    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destinationURL = downloadsURL.appendingPathComponent(suggestedFilename)
        completionHandler(destinationURL)
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // Recover from WebContent process crash
        webView.reload()
    }
    
    // MARK: - Native Notifications
    
    private func handleNotification(_ body: Any) {
        guard let dict = body as? [String: Any],
              let title = dict["title"] as? String else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = (dict["body"] as? String) ?? ""
        content.sound = .default
        content.categoryIdentifier = "MESSAGE"
        
        // Use tag for deduplication
        let identifier = (dict["tag"] as? String) ?? UUID().uuidString
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
```

---

## macOS Native Integration

### Dock Badge

```swift
// Updated automatically via the unreadCount message handler
NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
```

### Menu Bar (Optional Status Item)

```swift
final class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    
    func setup(appState: AppState) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "message.fill", accessibilityDescription: "Messenger")
            button.action = #selector(toggleWindow)
        }
    }
    
    // Update badge on status bar icon
    func updateBadge(count: Int) {
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: count > 0 ? "message.badge.fill" : "message.fill",
                accessibilityDescription: "Messenger"
            )
        }
    }
}
```

### Global Keyboard Shortcuts

```swift
// In AppDelegate or MainWindow
NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    // Cmd+N: New message
    if event.modifierFlags.contains(.command) && event.keyCode == 45 { // N
        self.navigateToNewMessage()
        return nil
    }
    // Cmd+F: Search conversations
    if event.modifierFlags.contains(.command) && event.keyCode == 3 { // F
        self.focusSearch()
        return nil
    }
    // Cmd+1...9: Switch conversations (like browser tabs)
    if event.modifierFlags.contains(.command),
       let num = Int(event.characters ?? ""),
       (1...9).contains(num) {
        self.switchToConversation(index: num)
        return nil
    }
    return event
}
```

### Window Behavior

```swift
// Main window configuration
WindowGroup {
    MessengerWebView()
        .frame(minWidth: 400, idealWidth: 900, minHeight: 500, idealHeight: 700)
}
.windowStyle(.titleBar)
.windowToolbarStyle(.unified)
.defaultSize(width: 900, height: 700)
.commands {
    CommandGroup(replacing: .newItem) {
        Button("New Message") { /* inject Cmd+N into webview */ }
            .keyboardShortcut("n", modifiers: .command)
    }
    CommandMenu("View") {
        Button("Reload") { coordinator.webView?.reload() }
            .keyboardShortcut("r", modifiers: .command)
        Button("Actual Size") { coordinator.webView?.magnification = 1.0 }
            .keyboardShortcut("0", modifiers: .command)
        Button("Zoom In") { coordinator.webView?.magnification += 0.1 }
            .keyboardShortcut("+", modifiers: .command)
        Button("Zoom Out") { coordinator.webView?.magnification -= 0.1 }
            .keyboardShortcut("-", modifiers: .command)
    }
}
```

---

## Entitlements & Info.plist

### Entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Network access (required for WKWebView) -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- App sandbox (required for notarization) -->
    <key>com.apple.security.app-sandbox</key>
    <true/>
    
    <!-- Camera access for video calls -->
    <key>com.apple.security.device.camera</key>
    <true/>
    
    <!-- Microphone access for voice/video calls -->
    <key>com.apple.security.device.audio-input</key>
    <true/>
    
    <!-- Read/write downloads folder for file downloads -->
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
    
    <!-- Keychain access for cookie backup -->
    <key>com.apple.security.keychain</key>
    <true/>
</dict>
</plist>
```

### Info.plist Keys

```xml
<!-- Camera usage description -->
<key>NSCameraUsageDescription</key>
<string>Messenger needs camera access for video calls.</string>

<!-- Microphone usage description -->
<key>NSMicrophoneUsageDescription</key>
<string>Messenger needs microphone access for voice and video calls.</string>

<!-- Allow arbitrary loads for Facebook CDN subdomains -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
</dict>
```

---

## Notification System

### Setup (in AppDelegate)

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        if granted {
            print("[Messenger] Notification permission granted")
        }
    }
    UNUserNotificationCenter.current().delegate = self
    
    // Register notification category for message actions
    let replyAction = UNTextInputNotificationAction(
        identifier: "REPLY",
        title: "Reply",
        textInputButtonTitle: "Send",
        textInputPlaceholder: "Type a message..."
    )
    let category = UNNotificationCategory(
        identifier: "MESSAGE",
        actions: [replyAction],
        intentIdentifiers: [],
        options: .customDismissAction
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
}
```

### Handle Notification Tap (Navigate to Conversation)

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Bring app to foreground
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        if response.actionIdentifier == "REPLY",
           let textResponse = response as? UNTextInputNotificationResponse {
            // Quick reply from notification — inject into active conversation
            let replyText = textResponse.userText
            // This requires knowing the active thread; complex but possible
            // via JS injection into the Messenger compose box
        }
        
        completionHandler()
    }
    
    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Only show if window is not key (user is in another app)
        if NSApplication.shared.isActive {
            completionHandler([])  // Suppress — user is already looking at Messenger
        } else {
            completionHandler([.banner, .sound, .badge])
        }
    }
}
```

---

## Build, Code Signing & Distribution

### Code Signing

```bash
# Development
xcodebuild -scheme Messenger -configuration Debug \
    CODE_SIGN_IDENTITY="Apple Development" \
    DEVELOPMENT_TEAM="YOUR_TEAM_ID"

# Distribution (Developer ID for direct download)
xcodebuild -scheme Messenger -configuration Release \
    CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
    DEVELOPMENT_TEAM="YOUR_TEAM_ID" \
    archive -archivePath ./build/Messenger.xcarchive
```

### Notarization

```bash
# Create DMG
hdiutil create -volname "Messenger" -srcfolder build/Messenger.app \
    -ov -format UDZO build/Messenger.dmg

# Submit for notarization
xcrun notarytool submit build/Messenger.dmg \
    --apple-id "your@email.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "@keychain:notarytool-password" \
    --wait

# Staple the ticket
xcrun stapler staple build/Messenger.dmg
```

### Auto-Updates (Sparkle Framework)

For direct distribution outside the Mac App Store, integrate [Sparkle 2](https://sparkle-project.org/) for automatic updates:

```swift
// In AppDelegate
import Sparkle

let updaterController = SPUStandardUpdaterController(
    startingUpdater: true, 
    updaterDelegate: nil, 
    userDriverDelegate: nil
)
```

Host an `appcast.xml` on GitHub Releases or your own CDN with signed update deltas.

---

## Known Challenges & Mitigations

### 1. Facebook DOM Changes Break Selectors

**Risk**: High. Facebook ships multiple times per day and DOM class names are often randomly generated hashes.

**Mitigation**: 
- Prefer `aria-label`, `role`, and `data-testid` selectors over class names — these are more stable as they're tied to accessibility and testing infrastructure
- Ship CSS/JS injection files as remotely updatable assets (fetch from a GitHub raw URL on app launch, with bundled fallback)
- Build a simple DOM diff reporter that alerts you when expected elements aren't found

### 2. End-to-End Encrypted Chats

E2E encrypted chats work normally in the webview since the encryption/decryption happens in Facebook's client-side JavaScript. WKWebView executes all JS faithfully, so this is a non-issue.

### 3. Video/Voice Calls

WebRTC works in WKWebView on macOS 14+. Camera and microphone permissions need to be granted both at the macOS system level (entitlements + user permission prompt) and in the webview (via `requestMediaCapturePermissionFor` delegate method). Screen sharing may not work — this is a limitation of WKWebView's WebRTC implementation.

### 4. Facebook May Block the App

**Risk**: Low-Medium. Facebook could detect a non-standard browser environment and block access or force redirects.

**Mitigation**: 
- Use a legitimate Safari user agent string (the app uses the system WebKit engine anyway)
- Don't modify Facebook's JavaScript behavior beyond cosmetic DOM changes
- The webview is functionally identical to Safari — there's nothing to fingerprint

### 5. Mac App Store Considerations

Apple's App Store guidelines (section 2.5.6) restrict apps that are simply website wrappers. To get approved, the app would need to provide substantial native functionality beyond the web experience (notifications, keyboard shortcuts, dock integration, menu bar, etc.). For initial distribution, Developer ID + notarization (direct download) avoids this issue entirely.

---

## Development Roadmap

### Phase 1 — MVP (1–2 weeks)
- [ ] Basic SwiftUI window with WKWebView loading `facebook.com/messages`
- [ ] Cookie persistence (session survives restart)
- [ ] External link routing to default browser
- [ ] Camera/microphone permission handling for calls
- [ ] File download support
- [ ] Basic CSS injection to hide Facebook navigation

### Phase 2 — Native Experience (1–2 weeks)
- [ ] Notification interception and native macOS notifications
- [ ] Dock badge for unread count
- [ ] Keyboard shortcuts (Cmd+N, Cmd+F, Cmd+1-9)
- [ ] Zoom controls
- [ ] Window state persistence (size, position)
- [ ] Dark mode support / automatic theme matching

### Phase 3 — Polish (1 week)
- [ ] Menu bar status item with unread indicator
- [ ] Quick reply from notification banner
- [ ] App icon design
- [ ] Code signing + notarization
- [ ] DMG packaging
- [ ] Sparkle auto-updater

### Phase 4 — Maintenance
- [ ] Remote CSS/JS injection updates (avoid shipping app updates for selector changes)
- [ ] DOM monitoring / health check for selector breakage
- [ ] Crash reporting (Sentry integration)
- [ ] Usage analytics (opt-in)

---

## Reference Projects

| Project | Tech | Status | Notes |
|---|---|---|---|
| [rozsazoltan/messenger](https://github.com/rozsazoltan/messenger) | Tauri/Rust | Active, maintained | Targets `facebook.com/messages`, strips Facebook UI, ~5MB |
| [JensPauwels/messenger](https://github.com/JensPauwels/messenger) | Go/Wails | Active | macOS-focused, wraps `messenger.com` |
| [stefanminch/messenger-mac](https://github.com/stefanminch/messenger-mac) | Unknown | Active | Signed + notarized, wraps `messenger.com` |
| [sindresorhus/caprine](https://github.com/sindresorhus/caprine) | Electron | Stale | Feature-rich but heavy, buggy, infrequently updated |
| [rsms/fb-mac-messenger](https://github.com/rsms/fb-mac-messenger) | Swift/WKWebView | Archived | Original native Swift approach, good reference |
