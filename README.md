# InstaChat - Anti-Doomscrolling Direct Messenger

An intentional, distraction-free iOS app built with SwiftUI that gives you access exclusively to Instagram Direct Messages. It strips away the algorithm feeds, reels, stories, explore tab, and all doomscrolling mechanics so you can stay connected with friends without wasting hours scrolling.


## Problem and Solution

- The Problem: Having Instagram installed on your phone just to stay in touch with friends or family leads to mindless scrolling through Reels, Explore, and Stories.
- The Solution: A locked-down, native iOS WebKit container that opens directly to Instagram Direct Inbox (/direct/inbox/), injects custom CSS/JS to strip away all distracting feeds and banners, and strictly blocks navigation to feeds or reels.


## Architecture and How It Works

1. Direct Inbox by Default
   - Opens straight to https://www.instagram.com/direct/inbox/ or the login screen.
   - Full access to all direct chats, message requests, voice messages, and media sharing.
   - Native iOS swipe-to-back gestures allow natural navigation between conversations and the inbox.

2. Persistent Session (WKWebsiteDataStore)
   - Uses persistent cookie storage via WKWebsiteDataStore.default().
   - Log in once and stay authenticated across app launches.

3. DOM and CSS Stripping (DistractionFreeScripts.swift)
   - Automatically removes bottom navigation bar (Home, Explore, Reels, Profile tabs).
   - Removes top header explore and notification triggers.
   - Removes app upsell banners ("Use the App", "Get Instagram", etc.).
   - Auto-dismisses "Turn on notifications" and "Save password" modals.
   - Authentication pages (/accounts/login/) render untouched so login and 2FA work reliably.

4. Navigation Policy Guard (WKNavigationDelegate)
   - Allowed: Direct inbox (/direct/inbox/), conversation threads (/direct/t/*), message requests, login (/accounts/*, 2FA, OAuth, Meta Accounts Center), and media CDNs.
   - Blocked: Home feed (/), Reels (/reels/), and Explore (/explore/). If Instagram attempts to route to feeds or reels, InstaChat immediately redirects back to Direct Inbox.
   - External Web Links: Safe links tapped inside direct messages open externally in Mobile Safari.

5. Real-Time iOS Local Notifications (NotificationManager.swift)
   - HTML5 Notification API Shim: Injected at document start to hook Instagram web notifications.
   - DOM Message Observer: Continuously detects incoming message bubbles inside active chats.
   - WebKit Native Bridge (WKScriptMessageHandler): Bridges events into Swift to trigger immediate native iOS banners, sound alerts, and haptic vibrations via UNUserNotificationCenter.


## File Structure

- MyApp.swift: App lifecycle entry point and initial notification permission request.
- ContentView.swift: Main view container with minimalist floating controls (reload, settings, and loading indicator).
- InstagramWebView.swift: Native UIViewRepresentable wrapping WKWebView, configuring navigation lockdown, and handling the notification bridge.
- DistractionFreeScripts.swift: Injected CSS and JavaScript rules that strip distracting UI elements and observe incoming chat messages.
- NotificationManager.swift: Manages iOS local notifications, foreground banner display, and deduplication.
- SettingsView.swift: Settings sheet to test notifications, check permissions, and log out or clear stored session data.
- DirectChatConfig.swift: Core URL routing constants for Direct Inbox.
