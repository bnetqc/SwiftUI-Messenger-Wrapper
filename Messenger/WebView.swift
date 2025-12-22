import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    @ObservedObject var viewModel: WebViewModel

    func makeNSView(context: Context) -> WKWebView {
        let preferences = WKPreferences()

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.applicationNameForUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Enable notifications
        webView.configuration.userContentController.add(context.coordinator, name: "notificationHandler")

        // Custom CSS to improve the experience
        let userScript = WKUserScript(
            source: """
            // Hide desktop app banners
            const style = document.createElement('style');
            style.textContent = `
                [data-testid="app-banner"] { display: none !important; }
                ._8slc { display: none !important; }
            `;
            document.head.appendChild(style);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(userScript)

        viewModel.webView = webView

        let request = URLRequest(url: viewModel.url)
        webView.load(request)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Update if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var viewModel: WebViewModel

        init(viewModel: WebViewModel) {
            self.viewModel = viewModel
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            viewModel.updateNavigationState()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            viewModel.updateNavigationState()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            viewModel.updateNavigationState()
        }

        // Handle new windows (e.g., opening links in new tabs)
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        // Handle JavaScript alerts, confirms, etc.
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = "Messenger"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = NSAlert()
            alert.messageText = "Messenger"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            completionHandler(response == .alertFirstButtonReturn)
        }

        // Handle notifications from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "notificationHandler" {
                // Handle notification requests here
                // You can parse message.body to get notification details
                print("Notification received: \(message.body)")
            }
        }
    }
}
