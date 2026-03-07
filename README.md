# Messenger for macOS

A beautiful, native macOS app for Facebook Messenger. No browser tabs, no distractions — just your conversations.

## Why Messenger?

Facebook doesn't offer a dedicated Messenger app for Mac. You're stuck with a browser tab buried among dozens of others, or the clunky Electron-based alternatives that eat your RAM.

Messenger gives you a lightweight, native wrapper that feels like it belongs on your Mac:

- **Native notifications** — get notified like any other Mac app, with reply support right from the banner
- **Menu bar icon** — see unread messages at a glance without switching windows
- **Dock badge** — unread count on the dock, just like Mail or Messages
- **Video & voice calls** — camera and microphone work out of the box
- **Keyboard shortcuts** — Cmd+N for new message, Cmd+F to search, Cmd+R to reload
- **Dark mode** — follows your system appearance
- **Launch at login** — always ready when you need it
- **Auto-updates** — stays up to date via Sparkle

All of Facebook's UI clutter — the news feed links, stories, marketplace, ads — is stripped away. You get Messenger and nothing else.

## Install

### Requirements

- macOS 14.0 (Sonoma) or later

### Build from source

```bash
brew install xcodegen
git clone https://github.com/adriandmitroca/messenger.git
cd messenger
xcodegen generate
open Messenger.xcodeproj
```

Build and run from Xcode (Cmd+R).

## Settings

Open Preferences (Cmd+,) to configure:

- **Notifications** — toggle notifications, sound, dock badge, and menu bar badge independently
- **Launch at login** — start Messenger when you log in
- **Auto-updates** — check for updates automatically or manually

## License

MIT
