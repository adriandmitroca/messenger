# Messenger macOS App

## Project Setup

- **XcodeGen** project — run `xcodegen generate` after changing `project.yml`
- Build: `xcodebuild -project Messenger.xcodeproj -scheme Messenger -configuration Debug build`
- No external dependencies (no SPM packages)

## Key Paths

- App entry: `Messenger/App/MessengerApp.swift`
- WebView setup: `Messenger/WebView/WebViewFactory.swift`
- Navigation/message handling: `Messenger/WebView/WebViewCoordinator.swift`
- Injected CSS: `Messenger/Injection/facebook-cleanup.css`
- Injected JS: `Messenger/Injection/facebook-cleanup.js`, `Messenger/Injection/notification-bridge.js`
- Project config: `project.yml`

## Conventions

- Swift 6.0 with `SWIFT_STRICT_CONCURRENCY: minimal`
- `@MainActor` on types that touch UI (WebViewFactory, StatusBarController)
- CSS/JS injection happens via `ContentInjector` → `WKUserScript` at document end
- All Facebook domain filtering is in `WebViewCoordinator.allowedDomains`

## Important

- Keep SPEC.md updated when changing architecture or data flow
- The web inspector is only enabled in debug builds (`webView.isInspectable = true`)
- The app loads `facebook.com/messages/` (not messenger.com) — this is intentional as it provides the full Messenger experience within Facebook's web app
