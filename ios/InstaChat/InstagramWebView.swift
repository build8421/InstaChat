import SwiftUI
import WebKit
import UIKit

/// A dedicated WKWebView container for Instagram Direct Inbox.
struct InstagramWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var reloadTrigger: Bool

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.makeWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update(webView: uiView, reloadTrigger: $reloadTrigger)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: InstagramWebView
        private var webView: WKWebView?
        private var progressObservation: NSKeyValueObservation?

        init(_ parent: InstagramWebView) {
            self.parent = parent
            super.init()
        }

        deinit {
            progressObservation?.invalidate()
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "incomingMessageBridge")
        }

        func makeWebView() -> WKWebView {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = WKWebsiteDataStore.default()
            configuration.allowsInlineMediaPlayback = true

            // Add notification shim at document start and DOM scripts at document end
            let userContentController = configuration.userContentController
            userContentController.addUserScript(DistractionFreeScripts.makeNotificationShimScript())
            userContentController.addUserScript(DistractionFreeScripts.makeUserScript())
            userContentController.add(ScriptMessageHandlerWeakProxy(self), name: "incomingMessageBridge")

            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = self
            webView.uiDelegate = self
            webView.allowsBackForwardNavigationGestures = true

            // Set clean modern mobile Safari user agent
            webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

            // Track loading progress
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                DispatchQueue.main.async {
                    self?.parent.progress = view.estimatedProgress
                }
            }

            self.webView = webView
            let request = URLRequest(url: DirectChatConfig.inboxURL)
            webView.load(request)

            return webView
        }

        func update(webView: WKWebView, reloadTrigger: Binding<Bool>) {
            if reloadTrigger.wrappedValue {
                DispatchQueue.main.async {
                    reloadTrigger.wrappedValue = false
                }
                webView.reload()
            }
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "incomingMessageBridge",
                  let dict = message.body as? [String: Any] else { return }

            let title = dict["title"] as? String ?? "Instagram"
            let body = dict["body"] as? String ?? ""

            NotificationManager.shared.scheduleNotification(title: title, body: body)
        }

        // MARK: - WKNavigationDelegate Lockdown

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let urlString = url.absoluteString.lowercased()
            let host = url.host?.lowercased() ?? ""

            // 1. Block feeds, explore, reels, and notification feeds -> redirect back to Direct Inbox
            if urlString.contains("/reels/") ||
               urlString.contains("/explore/") ||
               urlString.contains("/notifications") ||
               urlString.contains("/activity") ||
               urlString == "https://www.instagram.com/" {
                decisionHandler(.cancel)
                webView.load(URLRequest(url: DirectChatConfig.inboxURL))
                return
            }

            // 2. Open external non-Meta links in default mobile browser
            if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
                let isMetaDomain = host.contains("instagram.com") ||
                                   host.contains("facebook.com") ||
                                   host.contains("meta.com") ||
                                   host.contains("accountscenter") ||
                                   host.contains("cdninstagram.com") ||
                                   host.contains("fbcdn.net")

                if !isMetaDomain {
                    decisionHandler(.cancel)
                    UIApplication.shared.open(url)
                    return
                }
            }

            // 3. Allow everything else (direct messaging, auth/2FA, static assets, internal schemes)
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        // Support target="_blank" / popups by routing them through the main navigation flow
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

/// A weak proxy to prevent retain cycles between WKUserContentController and Coordinator.
private final class ScriptMessageHandlerWeakProxy: NSObject, WKScriptMessageHandler {
    private weak var handler: WKScriptMessageHandler?

    init(_ handler: WKScriptMessageHandler) {
        self.handler = handler
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        handler?.userContentController(userContentController, didReceive: message)
    }
}
