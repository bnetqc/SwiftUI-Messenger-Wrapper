import SwiftUI
import WebKit
import UserNotifications

struct WebView: NSViewRepresentable {
    @ObservedObject var viewModel: WebViewModel

    /// Hosts that are allowed to load inside the app. Everything else (links
    /// people send, Facebook's l.messenger.com link shim, etc.) opens in the
    /// default browser so the user never gets stuck on a foreign page.
    static let firstPartyHosts: Set<String> = [
        "messenger.com", "www.messenger.com",
        "facebook.com", "www.facebook.com", "m.facebook.com", "web.facebook.com",
    ]

    static func isFirstParty(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return true }
        return firstPartyHosts.contains(host)
            || host.hasSuffix(".fbcdn.net")
            || host.hasSuffix(".fbsbx.com")
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Appended to WebKit's default UA so the page sees a regular Safari,
        // which Facebook's login flow expects.
        configuration.applicationNameForUserAgent = "Version/17.0 Safari/605.1.15"

        let userContent = configuration.userContentController
        userContent.add(context.coordinator, name: WebView.notificationHandlerName)
        userContent.addUserScript(WKUserScript(
            source: WebView.notificationShimScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        userContent.addUserScript(WKUserScript(
            source: WebView.pageTweaksScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        viewModel.webView = webView
        webView.load(URLRequest(url: viewModel.url))
        context.coordinator.startBackgroundSync(for: webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    // MARK: - Injected scripts

    static let notificationHandlerName = "notificationHandler"

    /// WKWebView has no Web Notifications API, so Messenger's calls to
    /// `new Notification(...)` are forwarded to native macOS notifications.
    static let notificationShimScript = """
    (function () {
        function NativeNotification(title, options) {
            options = options || {};
            this.title = String(title);
            this.body = options.body ? String(options.body) : '';
            this.tag = options.tag ? String(options.tag) : '';
            this.onclick = null; this.onclose = null; this.onshow = null; this.onerror = null;
            try {
                window.webkit.messageHandlers.\(notificationHandlerName).postMessage({ title: this.title, body: this.body, tag: this.tag });
            } catch (e) {}
            var self = this;
            setTimeout(function () { if (typeof self.onshow === 'function') { self.onshow(); } }, 0);
        }
        NativeNotification.permission = 'granted';
        NativeNotification.requestPermission = function (callback) {
            if (typeof callback === 'function') { callback('granted'); }
            return Promise.resolve('granted');
        };
        NativeNotification.prototype.close = function () {};
        NativeNotification.prototype.addEventListener = function () {};
        NativeNotification.prototype.removeEventListener = function () {};
        window.Notification = NativeNotification;
    })();
    """

    /// Small page tweaks: hide "get the app" banners, and make window.close()
    /// (which Messenger calls when a call ends) return to the inbox instead
    /// of leaving the user on a dead page.
    static let pageTweaksScript = """
    (function () {
        var style = document.createElement('style');
        style.textContent = '[data-testid="app-banner"] { display: none !important; } ._8slc { display: none !important; }';
        (document.head || document.documentElement).appendChild(style);
        window.close = function () { window.location.href = 'https://www.messenger.com/'; };
    })();
    """

    /// Returns the effective background colour at the page's top-left corner
    /// as [r, g, b], used to paint the window (and its title bar) to match.
    static let backgroundProbeScript = """
    (function () {
        var el = document.elementFromPoint(1, 1) || document.body;
        while (el) {
            var m = /^rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([\\d.]+))?\\)$/.exec(getComputedStyle(el).backgroundColor);
            if (m && (m[4] === undefined || parseFloat(m[4]) > 0.99)) { return [+m[1], +m[2], +m[3]]; }
            el = el.parentElement;
        }
        return [255, 255, 255];
    })()
    """

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler,
                       WKDownloadDelegate, UNUserNotificationCenterDelegate {
        let viewModel: WebViewModel
        private var backgroundTimer: Timer?
        private var lastBackground: [Int] = []
        private var notificationsAuthorized = false

        init(viewModel: WebViewModel) {
            self.viewModel = viewModel
            super.init()
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                self?.notificationsAuthorized = granted
            }
        }

        deinit {
            backgroundTimer?.invalidate()
        }

        // MARK: Window background matching

        func startBackgroundSync(for webView: WKWebView) {
            backgroundTimer?.invalidate()
            backgroundTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self, weak webView] _ in
                guard let self = self, let webView = webView else { return }
                self.syncBackground(webView)
            }
        }

        private func syncBackground(_ webView: WKWebView) {
            webView.evaluateJavaScript(WebView.backgroundProbeScript) { [weak self] result, _ in
                guard let self = self,
                      let rgb = (result as? [NSNumber])?.map({ $0.intValue }),
                      rgb.count == 3, rgb != self.lastBackground else { return }
                self.lastBackground = rgb
                webView.window?.backgroundColor = NSColor(
                    calibratedRed: CGFloat(rgb[0]) / 255, green: CGFloat(rgb[1]) / 255,
                    blue: CGFloat(rgb[2]) / 255, alpha: 1
                )
            }
        }

        // MARK: Navigation

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            viewModel.updateNavigationState()
            syncBackground(webView)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            viewModel.updateNavigationState()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            viewModel.updateNavigationState()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            viewModel.updateNavigationState()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // mailto:, tel:, etc. belong to other apps.
            if let scheme = url.scheme?.lowercased(), scheme != "http", scheme != "https", scheme != "about", scheme != "blob", scheme != "data" {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            // target="_blank" links: keep Messenger pages here, send the rest out.
            if navigationAction.targetFrame == nil {
                openInNewWindow(navigationAction.request, from: webView)
                decisionHandler(.cancel)
                return
            }

            // Regular clicks on links to other sites open in the browser.
            if navigationAction.navigationType == .linkActivated,
               navigationAction.targetFrame?.isMainFrame == true,
               !WebView.isFirstParty(url) {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            // Anything the web view cannot display (attachments, files) is downloaded.
            if !navigationResponse.canShowMIMEType {
                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }

        private func openInNewWindow(_ request: URLRequest, from webView: WKWebView) {
            guard let url = request.url else { return }
            if WebView.isFirstParty(url) {
                webView.load(request)
            } else {
                NSWorkspace.shared.open(url)
            }
        }

        // MARK: Downloads

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                      suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = suggestedFilename
            panel.canCreateDirectories = true
            let finish: (NSApplication.ModalResponse) -> Void = { response in
                completionHandler(response == .OK ? panel.url : nil)
            }
            if let window = download.webView?.window {
                panel.beginSheetModal(for: window, completionHandler: finish)
            } else {
                finish(panel.runModal())
            }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            NSLog("Download failed: \(error.localizedDescription)")
        }

        // MARK: UI delegate

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            openInNewWindow(navigationAction.request, from: webView)
            return nil
        }

        /// Required for <input type="file"> (attaching photos and files).
        func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = parameters.allowsDirectories
            panel.allowsMultipleSelection = parameters.allowsMultipleSelection
            let finish: (NSApplication.ModalResponse) -> Void = { response in
                completionHandler(response == .OK ? panel.urls : nil)
            }
            if let window = webView.window {
                panel.beginSheetModal(for: window, completionHandler: finish)
            } else {
                finish(panel.runModal())
            }
        }

        /// Camera and microphone for calls: Messenger's own origins are
        /// trusted; macOS still shows its one-time system permission prompt.
        @available(macOS 12.0, *)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            let host = origin.host.lowercased()
            decisionHandler(WebView.firstPartyHosts.contains(host) ? .grant : .prompt)
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = "Messenger"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = NSAlert()
            alert.messageText = "Messenger"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            completionHandler(alert.runModal() == .alertFirstButtonReturn)
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            let alert = NSAlert()
            alert.messageText = "Messenger"
            alert.informativeText = prompt
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            field.stringValue = defaultText ?? ""
            alert.accessoryView = field
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")
            completionHandler(alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil)
        }

        // MARK: Notifications

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == WebView.notificationHandlerName,
                  let body = message.body as? [String: Any],
                  let title = body["title"] as? String else { return }
            // Only notify when the user is not already looking at the app.
            guard notificationsAuthorized, !NSApp.isActive else { return }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body["body"] as? String ?? ""
            content.sound = .default
            let identifier = (body["tag"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? UUID().uuidString
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        }

        /// Clicking a notification brings the app to the front.
        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                    withCompletionHandler completionHandler: @escaping () -> Void) {
            NSApp.activate(ignoringOtherApps: true)
            completionHandler()
        }
    }
}
