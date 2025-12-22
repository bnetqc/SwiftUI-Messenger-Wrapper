import SwiftUI

struct NavigationBar: View {
    @ObservedObject var viewModel: WebViewModel

    var body: some View {
        HStack {
            Button(action: { viewModel.goBack() }) {
                Image(systemName: "chevron.left")
            }
            .disabled(!viewModel.canGoBack)

            Button(action: { viewModel.goForward() }) {
                Image(systemName: "chevron.right")
            }
            .disabled(!viewModel.canGoForward)

            Button(action: { viewModel.reload() }) {
                Image(systemName: "arrow.clockwise")
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
