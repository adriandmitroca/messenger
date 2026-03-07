# Messenger — Technical Spec

## Overview

Messenger is a native macOS wrapper around Facebook's web-based Messenger (`facebook.com/messages/`). It uses WKWebView to render the Messenger UI and injects custom CSS/JS to strip Facebook chrome and bridge web notifications to native macOS notifications.

## Architecture

### App Layer (`Messenger/App/`)

- **MessengerApp.swift** — `@main` entry point using SwiftUI `App` protocol. Defines the window, menu commands (New Message, Reload, Zoom, Search, Log Out), initializes the status bar controller, Sparkle updater, and Settings scene.
- **AppDelegate.swift** — Handles `UNUserNotificationCenter` setup. Registers a "Reply" text input action on the `MESSAGE` notification category. Configures notification presentation behavior (suppressed when app is active, respects sound preference).
- **AppState.swift** — `ObservableObject` holding shared state: `unreadCount` (published) and a weak reference to the `WKWebView`.
- **SettingsManager.swift** — `@MainActor` singleton wrapping `UserDefaults` for app preferences: notifications, sound, dock badge, menu bar badge, launch at login. Uses `SMAppService` for login item registration.

### WebView Layer (`Messenger/WebView/`)

- **WebViewFactory.swift** — Creates and configures `WKWebView` instances. Sets a Safari user agent string, enables back/forward gestures, magnification, and web inspector (debug builds). Injects CSS/JS via `ContentInjector`.
- **WebViewCoordinator.swift** — `WKNavigationDelegate`, `WKUIDelegate`, `WKScriptMessageHandler`, `WKDownloadDelegate`. Handles:
  - **Navigation policy** — allows Facebook/Messenger domains, opens everything else in the default browser.
  - **Script messages** — receives `notificationBridge`, `unreadCount`, and `externalLink` messages from injected JS.
  - **Media permissions** — auto-grants camera/mic for Facebook/Messenger origins.
  - **Downloads** — saves to ~/Downloads.
  - **Crash recovery** — reloads on web content process termination.
- **ContentInjector.swift** — Loads `facebook-cleanup.css` and JS files (`facebook-cleanup.js`, `notification-bridge.js`) from the bundle and injects them as `WKUserScript` at document end.

### Views (`Messenger/Views/`)

- **MessengerWebView.swift** — `NSViewRepresentable` bridging WKWebView to SwiftUI. Loads `facebook.com/messages/` on appear.
- **StatusBarController.swift** — Creates an `NSStatusItem` with a message icon. Observes `appState.unreadCount` and toggles between `message.fill` and `message.badge.fill` SF Symbols. Respects `menuBarBadgeEnabled` setting.
- **SettingsView.swift** — SwiftUI `Settings` scene with three tabs: General (launch at login), Notifications (enable/disable notifications, sound, dock badge, menu bar badge), Updates (auto-check toggle, manual check button via Sparkle).

### Injected Content (`Messenger/Injection/`)

- **facebook-cleanup.css** — Hides Facebook navigation bar, stories, marketplace/gaming/watch links, Meta AI prompts, and create/notification/account buttons. Adds dark mode `color-scheme` support.
- **facebook-cleanup.js** — MutationObserver that removes reels, people-you-may-know, and ad elements as they appear. Intercepts clicks on non-Messenger links and forwards them to native code via `externalLink` message handler.
- **notification-bridge.js** — Replaces the browser `Notification` API with a fake that forwards notification data to native code via `notificationBridge` message handler. Observes `document.title` changes and polls every 5s to extract unread count (e.g. `(3)`) and send it via `unreadCount` message handler.

## Configuration

- **project.yml** — XcodeGen project spec. Bundle ID: `com.messenger.app`. Deployment target: macOS 14.0. Swift 6.0. Sparkle SPM dependency.
- **Info.plist** — Camera and microphone usage descriptions. Allows arbitrary loads in web content. `SUFeedURL` for Sparkle appcast.
- **Messenger.entitlements** — Network client, camera, audio input, downloads read-write.

## Data Flow

```
Facebook Messenger Web Page
    ↓ (injected JS)
WKScriptMessageHandler (WebViewCoordinator)
    ↓
AppState.unreadCount ──→ StatusBarController (menu bar badge)
                     ──→ NSApplication.dockTile.badgeLabel
notificationBridge   ──→ UNUserNotificationCenter (native notification, if enabled)
externalLink         ──→ NSWorkspace.shared.open(url)

SettingsManager      ──→ UserDefaults (notifications, sound, badges, launch at login)
                     ──→ SMAppService (login item)
SPUUpdater           ──→ Sparkle (auto-update via appcast)
```
