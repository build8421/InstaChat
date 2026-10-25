import SwiftUI
import WebKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingLogoutConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: About & Anti-Doomscrolling
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(.accentColor)
                                .font(.title3)
                            Text("Distraction-Free Direct Messages")
                                .font(.headline)
                        }
                        Text("InstaChat strictly confines your Instagram experience to Direct Messaging. Home feeds, Explore pages, and Reels are blocked to protect your time and attention.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("About InstaChat")
                }

                // Section 2: Notifications
                Section("Notifications") {
                    Button(action: {
                        NotificationManager.shared.requestPermission()
                    }) {
                        Label("Enable / Check Permissions", systemImage: "bell.badge")
                    }

                    Button(action: {
                        NotificationManager.shared.scheduleNotification(
                            title: "InstaChat",
                            body: "Notifications are working properly! 🎉"
                        )
                    }) {
                        Label("Send Test Notification", systemImage: "bell")
                    }
                }

                // Section 3: Session
                Section("Session") {
                    Button(role: .destructive, action: { showingLogoutConfirmation = true }) {
                        Label("Log Out / Clear Instagram Session", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Log Out", isPresented: $showingLogoutConfirmation, titleVisibility: .visible) {
                Button("Log Out and Clear Data", role: .destructive) {
                    clearInstagramSession()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will clear stored cookies and session data. You will need to log in to Instagram again.")
            }
        }
    }

    private func clearInstagramSession() {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.fetchDataRecords(ofTypes: types) { records in
            dataStore.removeData(ofTypes: types, for: records) {
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
