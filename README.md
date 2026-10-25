# InstaChat (Direct-Only Instagram Messenger)

An intentional, distraction-free iOS app built with SwiftUI that connects **exclusively** to a single Instagram DM thread. It strips away the feed, reels, explore tab, notifications, and all doomscrolling algorithms.

---

## 🎯 Problem & Solution

* **The Problem:** Keeping Instagram installed on your phone just to stay in touch with one specific person leads to endless mindless scrolling (Reels, Explore feed, Stories).
* **The Solution:** A locked-down, native iOS container that loads only that specific conversation thread, injects custom CSS/JS to hide all distracting UI elements, and blocks any navigation attempts to feeds or reels.

---

## 🏗️ Architecture & How It Works

1. **Persistent Session (`WKWebsiteDataStore`):**
   * Uses persistent cookie storage so you log in to Instagram once and stay authenticated across app launches.
2. **Target Thread Pinning:**
   * Navigates directly to your specific chat thread (`https://www.instagram.com/direct/t/<thread_id>/`).
3. **DOM / CSS Injection (`WKUserScript`):**
   * Dynamically removes:
     * Bottom navigation bar (Home, Explore, Reels, Profile tabs).
     * Top header bar and search interface.
     * Suggested posts, stories bar, and explore triggers.
     * Keeps strictly the messaging header, chat history, and message input box.
4. **Navigation Policy Guard (`WKNavigationDelegate`):**
   * Intercepts URL requests before they load.
   * Whitelists:
     * Authentication flows (`/accounts/login/`, 2FA, etc.).
     * The direct messaging thread (`/direct/t/...`).
   * Blocks:
     * Home feed (`/`), Reels (`/reels/`), Explore (`/explore/`).
     * Automatically redirects you back to the pinned conversation if you click an external link.

---

## 🔑 How to Find Your Chat Thread ID

1. Log into [instagram.com](https://www.instagram.com) on your computer browser.
2. Go to **Messages** (Direct) and click on the specific conversation.
3. Look at the URL in your browser address bar:
   ```text
   https://www.instagram.com/direct/t/17849204859123456/
   ```
4. The long number after `/t/` (e.g. `17849204859123456`) is your **Thread ID**.

---

## 📋 Implementation Roadmap / Status

### Phase 1: Core Web Container & Configuration
- [x] Create `DirectChatConfig.swift`:
  - Store `threadId` or target direct URL using `@AppStorage` / `UserDefaults`.
  - Provide a fallback setup view if no thread ID is configured yet.
- [x] Create `InstagramWebView.swift` (`UIViewRepresentable`):
  - Configure `WKWebViewConfiguration` with `WKWebsiteDataStore.default()`.
  - Set modern Mobile Safari `customUserAgent` to prevent Instagram from displaying unsupported browser warnings.

### Phase 2: Distraction-Free Script Injection
- [x] Implement `WKUserScript` with custom CSS injected at `document_end`:
  - Hide bottom navigation bar (`div[role="tablist"]`, `svg[aria-label="Home"]`, etc.).
  - Hide explore / reels / notification icons.
  - Hide sidebar conversation list (focus strictly on active chat).
- [x] Implement DOM observer script to continuously ensure newly hydrated elements (like popups, reel recommendations, or "Get App" banners) remain hidden.

### Phase 3: Navigation Lockdown
- [x] Implement `WKNavigationDelegate`:
  - Allow login & authentication endpoints (`instagram.com/accounts/*`).
  - Allow target thread URL (`instagram.com/direct/t/<thread_id>/*`).
  - Block `/reels/*`, `/explore/*`, and root `/`.
  - Handle back-navigation so tapping back always returns to the configured chat thread.

### Phase 4: UI & Polish
- [x] Update `ContentView.swift`:
  - Show a simple setup sheet on first launch to paste the Thread ID / URL.
  - Show a small, subtle settings button to reconfigure the Thread ID if needed.
  - Add native loading indicator / offline state handling.
- [ ] Test on iOS Simulator and physical iPhone.

---

## 🚀 Getting Started

1. Open `InstaChat.xcodeproj` in Xcode.
2. Select your development team in **Signing & Capabilities**.
3. Select an iOS Simulator or your connected iPhone.
4. Press **Cmd + R** to build and run.
