import SwiftUI

@main
struct MessengerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
