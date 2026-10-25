import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit
typealias PlatformViewRepresentable = UIViewRepresentable
#elseif canImport(AppKit)
import AppKit
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

/// A dedicated WKWebView container for Instagram Direct Inbox.
struct InstagramWebView: PlatformViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var reloadTrigger: Bool

    // MARK: - UIViewRepresentable (iOS / iPadOS / visionOS)
    #if canImport(UIKit)
    func makeUIView(context: Context) -> WKWebView {
        return context.coordinator.makeWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.update(webView: uiView, reloadTrigger: $reloadTrigger)
    }
    #endif

    // MARK: - NSViewRepresentable (macOS Native)
    #if canImport(AppKit) && !canImport(UIKit)
    func makeNSView(context: Context) -> WKWebView {
        return context.coordinator.makeWebView()
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.update(webView: nsView, reloadTrigger: $reloadTrigger)
    }
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: InstagramWebView
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

            let scheme = url.scheme?.lowercased() ?? ""
            let urlString = url.absoluteString.lowercased()
            let host = url.host?.lowercased() ?? ""

            // 1. Allow internal browser schemes (about:blank, blob:, data:, javascript:)
            if scheme == "about" || scheme == "blob" || scheme == "data" || scheme == "javascript" {
                decisionHandler(.allow)
                return
            }

            // 2. Allow login, 2FA, Meta/Facebook login-sync, Accounts Center, and static asset CDNs
            if urlString.contains("/accounts/") ||
               urlString.contains("/oauth/") ||
               urlString.contains("/challenge/") ||
               urlString.contains("/two_factor/") ||
               urlString.contains("/login") ||
               urlString.contains("/consent/") ||
               urlString.contains("/checkpoint/") ||
               host.contains("facebook.com") ||
               host.contains("meta.com") ||
               host.contains("accountscenter") ||
               host.contains("cdninstagram.com") ||
               host.contains("fbcdn.net") {
                decisionHandler(.allow)
                return
            }

            // 3. Allow all Direct Messaging (inbox, threads, requests)
            if urlString.contains("/direct/") {
                decisionHandler(.allow)
                return
            }

            // 4. Block Instagram Feeds, Reels, Explore, and Activity/Notification pages
            if urlString.contains("/reels/") ||
               urlString.contains("/explore/") ||
               urlString.contains("/notifications") ||
               urlString.contains("/activity") ||
               (urlString == "https://www.instagram.com/" || urlString == "https://instagram.com/") {
                decisionHandler(.cancel)
                // Redirect back to Direct Inbox
                let request = URLRequest(url: DirectChatConfig.inboxURL)
                webView.load(request)
                return
            }

            // 5. Handle external web links clicked by user inside DMs (open in external browser)
            if scheme == "http" || scheme == "https" {
                let isMetaDomain = host.contains("instagram.com") ||
                                   host.contains("facebook.com") ||
                                   host.contains("meta.com") ||
                                   host.contains("accountscenter") ||
                                   host.contains("cdninstagram.com") ||
                                   host.contains("fbcdn.net")

                if !isMetaDomain {
                    decisionHandler(.cancel)
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #elseif canImport(AppKit)
                    NSWorkspace.shared.open(url)
                    #endif
                    return
                }
            }

            // Default: allow remaining direct chat navigation
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

        // Support window.open / popups inside the same view
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
