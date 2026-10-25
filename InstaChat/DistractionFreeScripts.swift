import Foundation
import WebKit

/// Provides custom CSS and JavaScript to strip away feeds, reels, banners, and explore tabs,
/// as well as hooking incoming messages for native iOS notifications.
enum DistractionFreeScripts {
    
    /// Custom CSS rules injected at document end.
    static let customCSS: String = """
    /* Only apply distraction-free rules once outside authentication pages */
    body:not(.auth-page) div[role="tablist"],
    body:not(.auth-page) nav[role="navigation"]:not([aria-label*="conversation"]):not([aria-label*="chat"]):not([aria-label*="Thread"]):not([aria-label*="Direct"]),
    body:not(.auth-page) footer {
        display: none !important;
        visibility: hidden !important;
        height: 0 !important;
        pointer-events: none !important;
    }

    /* Hide top header branding, explore icon, notifications */
    a[href="/reels/"],
    a[href="/explore/"],
    a[href="/"],
    a[aria-label="Home"],
    a[aria-label="Search"],
    a[aria-label="Explore"],
    a[aria-label="Reels"],
    a[aria-label="Notifications"],
    svg[aria-label="Home"],
    svg[aria-label="Search"],
    svg[aria-label="Explore"],
    svg[aria-label="Reels"],
    svg[aria-label="Activity Feed"] {
        display: none !important;
    }

    /* Hide 'Use the App' / 'Get Instagram' prompt banners */
    div[role="banner"],
    div[data-testid="smart-banner"],
    div[data-testid="app-upsell"],
    .AppUpsellBanner,
    div:has(> a[href*="itunes.apple.com"]),
    div:has(> a[href*="play.google.com"]) {
        display: none !important;
        height: 0 !important;
    }

    /* Ensure the chat container takes the full height of the viewport */
    html, body {
        height: 100% !important;
        width: 100% !important;
        -webkit-user-select: text !important;
    }

    /* Hide secondary left-sidebar thread lists on wider screens once inside a chat */
    @media (min-width: 768px) {
        div[aria-label="Conversations"] {
            display: none !important;
        }
    }
    """
    
    /// Early script injected at document start to hook HTML5 Web Notifications.
    static let notificationShimJS: String = """
    (function() {
        if (window.__instaChatShimInjected) return;
        window.__instaChatShimInjected = true;

        function CustomNotification(title, options) {
            try {
                var bodyText = (options && options.body) ? options.body : "";
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.incomingMessageBridge) {
                    window.webkit.messageHandlers.incomingMessageBridge.postMessage({
                        title: title || "Instagram Message",
                        body: bodyText
                    });
                }
            } catch (e) {}
        }

        CustomNotification.permission = "granted";
        CustomNotification.requestPermission = function(callback) {
            if (callback) callback("granted");
            return Promise.resolve("granted");
        };

        window.Notification = CustomNotification;
    })();
    """

    /// Main script injected at document end for DOM cleaning and incoming message detection.
    static let injectionJS: String = """
    (function() {
        // 1. Inject CSS
        const style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `\(customCSS)`;
        document.head.appendChild(style);

        // 2. Dismiss prompts and clean banned links
        function cleanDOM() {
            // Do not alter or click buttons on login or accounts verification pages
            var path = (window.location.pathname || '').toLowerCase();
            if (path.includes('/accounts/') || path.includes('/login') || path.includes('/challenge/')) {
                document.body.classList.add('auth-page');
                return;
            } else {
                document.body.classList.remove('auth-page');
            }

            // Dismiss 'Turn on Notifications' modal dialogs
            const buttons = document.querySelectorAll('button');
            buttons.forEach(btn => {
                const text = (btn.innerText || '').toLowerCase().trim();
                if (text === 'not now') {
                    btn.click();
                }
            });

            // Suppress explore/reels/home anchors
            const bannedLinks = document.querySelectorAll('a[href="/explore/"], a[href="/reels/"], a[href="/"]');
            bannedLinks.forEach(link => {
                link.style.display = 'none';
            });
        }

        // 3. Incoming message observer
        var seenMessages = new Set();
        var isInitialScanDone = false;

        function scanIncomingMessages() {
            try {
                var textNodes = document.querySelectorAll('div[dir="auto"], span[dir="auto"]');
                textNodes.forEach(function(node) {
                    var text = (node.innerText || '').trim();
                    if (!text || text.length === 0) return;
                    
                    // Exclude system labels
                    if (text === 'Seen' || text === 'Sent' || text.startsWith('Active ') || text === 'InstaChat') return;

                    // Determine if this bubble belongs to an outgoing message
                    var isOutgoing = false;
                    var curr = node;
                    while (curr && curr !== document.body) {
                        var style = window.getComputedStyle(curr);
                        if (style && (style.alignSelf === 'flex-end' || style.justifyContent === 'flex-end')) {
                            isOutgoing = true;
                            break;
                        }
                        curr = curr.parentElement;
                    }

                    var key = text;
                    if (!seenMessages.has(key)) {
                        seenMessages.add(key);
                        // Only dispatch notification for new incoming messages after initial thread load
                        if (isInitialScanDone && !isOutgoing) {
                            try {
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.incomingMessageBridge) {
                                    window.webkit.messageHandlers.incomingMessageBridge.postMessage({
                                        title: "Instagram",
                                        body: text
                                    });
                                }
                            } catch (err) {}
                        }
                    }
                });
            } catch (e) {}
        }

        // Mark pre-existing messages as seen after 3 seconds
        setTimeout(function() {
            scanIncomingMessages();
            isInitialScanDone = true;
        }, 3000);

        // Run once on load
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', function() {
                cleanDOM();
                scanIncomingMessages();
            });
        } else {
            cleanDOM();
            scanIncomingMessages();
        }

        // Monitor DOM mutations continuously
        const observer = new MutationObserver(function() {
            cleanDOM();
            if (isInitialScanDone) {
                scanIncomingMessages();
            }
        });

        observer.observe(document.body || document.documentElement, {
            childList: true,
            subtree: true
        });
    })();
    """
    
    /// Script for hooking notification APIs at start of document loading.
    static func makeNotificationShimScript() -> WKUserScript {
        return WKUserScript(
            source: notificationShimJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    /// Script for DOM cleaning and chat observer injected at document end.
    static func makeUserScript() -> WKUserScript {
        return WKUserScript(
            source: injectionJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    }
}
