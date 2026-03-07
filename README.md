# Messenger for macOS

A lightweight, native macOS replacement for the discontinued Facebook Messenger desktop app. No Electron, no browser tabs — just your conversations in a proper Mac app.

## Why?

Meta killed the official Messenger app for Mac. Your options are a browser tab lost among dozens of others, or bloated Electron wrappers. This app is a thin native shell (~5MB) around Messenger's web interface, with the features you'd expect from a real Mac app:

- **Native notifications** with reply support directly from the banner
- **Dock badge** and **menu bar icon** for unread count at a glance
- **Video & voice calls** — camera and microphone just work
- **Keyboard shortcuts** — Cmd+N new message, Cmd+F search, Cmd+R reload
- **Dark mode** — follows your system appearance automatically
- **Launch at login** — always ready
- **Auto-updates** via Sparkle
- **Close to tray** — closing the window keeps the app running in the background

No news feed, no stories, no marketplace. Just Messenger.

## Install

Download the latest `.dmg` from [Releases](https://github.com/adriandmitroca/messenger/releases), or build from source:

```bash
brew install xcodegen
git clone https://github.com/adriandmitroca/messenger.git
cd messenger
xcodegen generate
open Messenger.xcodeproj
```

Requires macOS 14.0 (Sonoma) or later.

## License

MIT
