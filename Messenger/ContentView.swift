import SwiftUI

struct ContentView: View {
    @StateObject private var webViewModel = WebViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            if webViewModel.showNavigationBar {
                NavigationBar(viewModel: webViewModel)
            }

            // WebView
            WebView(viewModel: webViewModel)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
