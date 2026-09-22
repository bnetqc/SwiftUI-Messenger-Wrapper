# Messenger for macOS

A native macOS wrapper for Facebook Messenger built with SwiftUI and WebKit to replace the discontinued Facebook Messenger app.

It's kind of a fork of https://github.com/JensPauwels/messenger but written in SwiftUI and WebKit instead of Go/Wails for better performance.

![App Icon](Messenger/Assets.xcassets/AppIcon.appiconset/MessengerIcon-512.png)

## Features

- Native macOS application experience
- Full access to messenger.com functionality
- Lightweight WebKit wrapper
- Links open in your default browser; Messenger pages stay in the app
- Attach files and save attachments (native open/save panels)
- Voice and video calls (camera and microphone access)
- Native macOS notifications for new messages
- Back/forward navigation support
- Auto-hide app banners and promotional content
- Custom Messenger app icon
- App Sandbox and Hardened Runtime; releases are signed and notarized

## Requirements

- macOS 11.5 or later
- Xcode 16 or later (to build from source)

## Installation

### Option 1: Download Release
Download the latest `.app` from the [Releases](../../releases) page.

### Option 2: Build from Source

1. Clone this repository:
   ```bash
   git clone https://github.com/bnetqc/SwiftUI-Messenger-Wrapper.git
   cd SwiftUI-Messenger-Wrapper
   ```

2. Open `Messenger.xcodeproj` in Xcode

3. Build and run (Cmd+R)

## Building for Release

`build.sh` archives the app, signs it with your Developer ID, notarizes it with Apple, staples the ticket and produces `releases/Messenger-vX.Y.Z-macOS.zip` ready for GitHub Releases.

One-time setup:

1. Install a **Developer ID Application** certificate from your Apple Developer account in the login keychain.
2. Store notarization credentials (use an [app-specific password](https://appleid.apple.com)):
   ```bash
   xcrun notarytool store-credentials "messenger-notary" \
       --apple-id "you@example.com" --team-id "TEAMID1234" \
       --password "xxxx-xxxx-xxxx-xxxx"
   ```

Then, after bumping `MARKETING_VERSION` in the Xcode project:

```bash
./build.sh
```

Alternatively use Xcode: **Product → Archive → Distribute App → Direct Distribution**.

## Project Structure

```
Messenger/
├── Messenger/
│   ├── MessengerApp.swift         # Main app entry point
│   ├── ContentView.swift          # Main view container
│   ├── WebView.swift              # WebKit wrapper
│   ├── WebViewModel.swift         # View model for web state
│   ├── NavigationBar.swift        # Navigation controls
│   ├── Messenger.entitlements     # App capabilities
│   └── Assets.xcassets/          # App icon and assets
├── Messenger.xcodeproj/
├── ExportOptions.plist            # Developer ID export settings
├── build.sh                       # Sign, notarize and package a release
└── README.md
```

## Customization

### Toggle Navigation Bar

The navigation bar is hidden by default. To show it, change `showNavigationBar` in `WebViewModel.swift`:

```swift
@Published var showNavigationBar: Bool = true
```

### Change Default URL

Modify the `url` property in `WebViewModel.swift`:

```swift
@Published var url: URL = URL(string: "https://www.messenger.com")!
```

## License

This is a personal project wrapper. Facebook Messenger and all related trademarks are property of Meta Platforms, Inc.

## Disclaimer

This is an unofficial wrapper application and is not affiliated with, endorsed by, or connected to Meta Platforms, Inc. or Facebook Messenger in any way.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.
