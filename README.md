# Messenger

A native macOS desktop app for Facebook Messenger, built with SwiftUI and WKWebView. Wraps the Messenger web interface in a lightweight, focused window — stripping away Facebook's UI chrome and adding native macOS integrations.

## Features

- Native macOS notifications (with reply action)
- Menu bar status icon with unread badge
- Dock badge with unread count
- Keyboard shortcuts (new message, search, zoom, reload)
- External links open in default browser
- Camera & microphone access for calls
- File downloads to ~/Downloads
- Dark mode support

## Requirements

- macOS 14.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

```bash
brew install xcodegen
xcodegen generate
open Messenger.xcodeproj
```

Build and run from Xcode (⌘R).

## Project Structure

```
Messenger/
├── App/                  # App entry point, delegate, state
├── Views/                # SwiftUI views, status bar controller
├── WebView/              # WKWebView factory, coordinator, content injection
├── Injection/            # CSS & JS injected into the web page
└── Resources/            # Info.plist, entitlements, assets
```
