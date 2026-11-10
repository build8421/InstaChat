import SwiftUI

struct ContentView: View {
    @State private var showingSettings: Bool = false
    @State private var isLoading: Bool = false
    @State private var progress: Double = 0.0
    @State private var reloadTrigger: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            InstagramWebView(
                isLoading: $isLoading,
                progress: $progress,
                reloadTrigger: $reloadTrigger
            )
            .ignoresSafeArea(edges: .bottom)

            // Top Floating Quick Actions
            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: { reloadTrigger = true }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.footnote.weight(.semibold))
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Reload")

                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.footnote.weight(.semibold))
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Settings")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

                // Loading bar
                if isLoading && progress < 1.0 {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 2)
                        .transition(.opacity)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
}
