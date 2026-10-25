import Foundation
import WebKit

/// Provides custom CSS and JavaScript to strip away feeds, reels, banners, and explore tabs.
enum DistractionFreeScripts {
    
    /// Custom CSS rules injected at document end.
    static let customCSS: String = """
    /* 1. Hide bottom navigation bar and tabs (Home, Explore, Reels, Profile) */
    div[role="tablist"],
    nav[role="navigation"]:not([aria-label*="conversation"]):not([aria-label*="chat"]):not([aria-label*="Thread"]),
    footer {
        display: none !important;
        visibility: hidden !important;
        height: 0 !important;
        pointer-events: none !important;
    }

    /* 2. Hide top header branding, explore icon, notifications */
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

    /* 3. Hide 'Use the App' / 'Get Instagram' prompt banners */
    div[role="banner"],
    div[data-testid="smart-banner"],
    div[data-testid="app-upsell"],
    .AppUpsellBanner,
    div:has(> a[href*="itunes.apple.com"]),
    div:has(> a[href*="play.google.com"]) {
        display: none !important;
        height: 0 !important;
    }

    /* 4. Ensure the chat container takes the full height of the viewport */
    html, body {
        overflow: hidden !important;
        height: 100% !important;
        width: 100% !important;
        -webkit-user-select: text !important;
    }

    /* 5. Hide secondary left-sidebar thread lists on wider screens so the active chat occupies full width */
    @media (min-width: 768px) {
        div[aria-label="Conversations"] {
            display: none !important;
        }
    }
    """
    
    /// JavaScript that injects the CSS styles and continuously cleans distracting elements.
    static let injectionJS: String = """
    (function() {
        // Inject CSS
        const style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `\(customCSS)`;
        document.head.appendChild(style);

        // Continuous DOM observer to dismiss banners and popups
        function cleanDOM() {
            // Dismiss 'Turn on Notifications' or 'Open in App' dialogs
            const buttons = document.querySelectorAll('button');
            buttons.forEach(btn => {
                const text = (btn.innerText || '').toLowerCase();
                if (text.includes('not now') || text.includes('cancel')) {
                    // Auto-dismiss the prompt
                    btn.click();
                }
            });

            // Remove any explore or reel links that dynamically attach
            const bannedLinks = document.querySelectorAll('a[href="/explore/"], a[href="/reels/"], a[href="/"]');
            bannedLinks.forEach(link => {
                link.style.display = 'none';
            });
        }

        // Run once on load
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', cleanDOM);
        } else {
            cleanDOM();
        }

        // Monitor DOM mutations
        const observer = new MutationObserver(() => {
            cleanDOM();
        });

        observer.observe(document.body || document.documentElement, {
            childList: true,
            subtree: true
        });
    })();
    """
    
    /// Creates a WKUserScript ready to be added to WKUserContentController.
    static func makeUserScript() -> WKUserScript {
        return WKUserScript(
            source: injectionJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    }
}
