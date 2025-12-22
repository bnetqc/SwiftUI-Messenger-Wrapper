# Messenger for macOS

A native macOS wrapper for Facebook Messenger built with SwiftUI and WebKit to replaced the discontinued Facebook Messenger App.

It's kind of a fork of this https://github.com/JensPauwels/messenger but writen in SwiftUI and WebKit instead of java for better performances.

![App Icon](Messenger/Assets.xcassets/AppIcon.appiconset/MessengerIcon-512.png)

## Features

- Native macOS application experience
- Full access to messenger.com functionality
- Lightweight WebKit wrapper
- Back/forward navigation support
- Auto-hide app banners and promotional content
- Custom Messenger app icon
- Notification handling infrastructure
- App Sandbox security

## Requirements

- macOS 11.0 or later
- Xcode 13.0 or later

## Installation

### Option 1: Download Release
Download the latest `.app` from the [Releases](../../releases) page.

### Option 2: Build from Source

1. Clone this repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/messenger-macos.git
   cd messenger-macos
   ```

2. Open `Messenger.xcodeproj` in Xcode

3. Build and run (Cmd+R)

## Building for Release

1. In Xcode, select **Product → Archive**
2. Once archived, click **Distribute App**
3. Choose **Copy App** for personal use
4. The built app will be exported to your chosen location

## Project Structure

```
Messenger/
├── Messenger/
│   ├── MessengerApp.swift         # Main app entry point
│   ├── ContentView.swift          # Main view container
│   ├── WebView.swift              # WebKit wrapper
│   ├── WebViewModel.swift         # View model for web state
│   ├── NavigationBar.swift        # Navigation controls
│   ├── Info.plist                 # App configuration
│   ├── Messenger.entitlements     # App capabilities
│   └── Assets.xcassets/          # App icon and assets
├── Messenger.xcodeproj/
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
