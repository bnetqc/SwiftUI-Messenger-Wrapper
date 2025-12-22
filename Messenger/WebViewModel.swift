import Foundation
import WebKit
import Combine

class WebViewModel: ObservableObject {
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var showNavigationBar: Bool = false
    @Published var url: URL = URL(string: "https://www.messenger.com")!

    weak var webView: WKWebView?

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    func updateNavigationState() {
        canGoBack = webView?.canGoBack ?? false
        canGoForward = webView?.canGoForward ?? false
        isLoading = webView?.isLoading ?? false
    }
}
