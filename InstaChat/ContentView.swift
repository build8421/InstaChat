import SwiftUI

struct ContentView: View {
    @AppStorage(DirectChatConfig.threadIdKey) private var threadId: String = ""
    @State private var showingSettings: Bool = false
    @State private var isLoading: Bool = false
    @State private var progress: Double = 0.0
    @State private var reloadTrigger: Bool = false

    var body: some View {
        Group {
            if threadId.isEmpty {
                setupPromptView
            } else if let threadURL = DirectChatConfig.makeThreadURL(for: threadId) {
                activeChatView(url: threadURL)
            } else {
                setupPromptView
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(threadId: $threadId)
        }
    }

    // MARK: - Active Chat View

    private func activeChatView(url: URL) -> some View {
        ZStack(alignment: .top) {
            InstagramWebView(
                targetURL: url,
                threadId: threadId,
                isLoading: $isLoading,
                progress: $progress,
                reloadTrigger: $reloadTrigger
            )
            .ignoresSafeArea(edges: .bottom)

            // Top Floating Navigation Bar
            VStack(spacing: 0) {
                HStack {
                    // Small branding indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("InstaChat")
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())

                    Spacer()

                    // Quick Actions (Reload & Settings)
                    HStack(spacing: 8) {
                        Button(action: { reloadTrigger = true }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.footnote.weight(.semibold))
                                .frame(width: 30, height: 30)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Reload Conversation")

                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.footnote.weight(.semibold))
                                .frame(width: 30, height: 30)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

                // Thin loading bar indicator
                if isLoading && progress < 1.0 {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 2)
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Setup Prompt View

    private var setupPromptView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("Welcome to InstaChat")
                    .font(.title2.bold())

                Text("A distraction-free direct messenger for Instagram. Connect to one specific chat thread without feeds, reels, or explore algorithms.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: { showingSettings = true }) {
                HStack {
                    Image(systemName: "link")
                    Text("Connect Instagram Chat")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
