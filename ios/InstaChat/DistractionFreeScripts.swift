import Foundation
import WebKit

/// Provides custom CSS and JavaScript to strip away feeds, reels, banners, explore tabs,
/// and activity/heart notifications, keeping the experience strictly direct-messaging only.
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

    /* Hide home feed, explore, reels, and heart/activity notifications */
    a[href="/reels/"],
    a[href="/explore/"],
    a[href="/"],
    a[href*="/notifications"],
    a[href*="/activity"],
    a[aria-label="Home"],
    a[aria-label="Search"],
    a[aria-label="Explore"],
    a[aria-label="Reels"],
    a[aria-label="Notifications"],
    svg[aria-label="Home"],
    svg[aria-label="Search"],
    svg[aria-label="Explore"],
    svg[aria-label="Reels"],
    svg[aria-label="Notifications"],
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

    /* Ensure container takes full height */
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
    
    /// Early script injected at document start to hook HTML5 Web Notifications and intercept root inbox back navigation.
    static let notificationShimJS: String = """
    (function() {
        if (window.__instaChatShimInjected) return;
        window.__instaChatShimInjected = true;

        // 1. Hook HTML5 Web Notifications for real-time messages
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

        // 2. Intercept clicks and touches on the top-left back button when at Direct Inbox
        function swallowInboxBack(e) {
            try {
                var path = (window.location.pathname || '').toLowerCase();
                // Allow back button inside conversation threads to return to inbox
                if (path.includes('/direct/t/')) return;
                if (!path.includes('/direct')) return;

                var target = e.target;
                if (!target) return;

                var btn = target.closest ? target.closest('button, [role="button"], a, header > div') : null;
                var isTopLeft = false;
                if (btn) {
                    var rect = btn.getBoundingClientRect();
                    if (rect.top >= 0 && rect.top < 65 && rect.left >= 0 && rect.left < 85) {
                        isTopLeft = true;
                    }
                }

                var isBackElement = (btn && (
                    btn.matches('a[href="/"], [aria-label*="Back" i], [aria-label*="Chevron" i]') ||
                    btn.querySelector('[aria-label*="Back" i], [aria-label*="Chevron" i], a[href="/"]')
                )) || (target.closest && target.closest('[aria-label*="Back" i], [aria-label*="Chevron" i]'));

                if (isTopLeft || isBackElement) {
                    e.preventDefault();
                    e.stopPropagation();
                    e.stopImmediatePropagation();
                }
            } catch (err) {}
        }

        document.addEventListener('click', swallowInboxBack, true);
        document.addEventListener('touchend', swallowInboxBack, true);
    })();
    """

    /// Main script injected at document end for DOM cleaning.
    static let injectionJS: String = """
    (function() {
        // 1. Inject CSS
        const style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `\(customCSS)`;
        document.head.appendChild(style);

        // 2. Clean DOM and handle page states
        function cleanDOM() {
            var path = (window.location.pathname || '').toLowerCase();
            // Preserve full rendering on login and verification pages
            if (path.includes('/accounts/') || path.includes('/login') || path.includes('/challenge/')) {
                document.body.classList.add('auth-page');
            } else {
                document.body.classList.remove('auth-page');
            }

            // Suppress explore/reels/home/activity anchors
            const bannedLinks = document.querySelectorAll('a[href="/explore/"], a[href="/reels/"], a[href="/"], a[href*="/notifications"], a[href*="/activity"]');
            bannedLinks.forEach(link => {
                link.style.display = 'none';
            });
        }

        // Run on load
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', cleanDOM);
        } else {
            cleanDOM();
        }

        // Monitor DOM mutations
        const observer = new MutationObserver(cleanDOM);
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

    /// Script for DOM cleaning injected at document end.
    static func makeUserScript() -> WKUserScript {
        return WKUserScript(
            source: injectionJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    }
}
