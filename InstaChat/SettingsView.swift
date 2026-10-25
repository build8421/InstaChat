import SwiftUI
import WebKit

struct SettingsView: View {
    @Binding var threadId: String
    @Environment(\.dismiss) private var dismiss

    @State private var inputThread: String = ""
    @State private var showingError: Bool = false
    @State private var showingLogoutConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Thread ID or URL", text: $inputThread)
                        .autocorrectionDisabled()
                        #if canImport(UIKit)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        #endif

                    Button(action: saveThreadId) {
                        HStack {
                            Spacer()
                            Text(threadId.isEmpty ? "Connect Thread" : "Update Thread")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(inputThread.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("Target Instagram Conversation")
                } footer: {
                    Text("Paste the full conversation URL or the numeric Thread ID.")
                }

                Section("How to find your Thread ID") {
                    VStack(alignment: .leading, spacing: 10) {
                        stepRow(number: "1", text: "Open instagram.com on your computer browser.")
                        stepRow(number: "2", text: "Go to Direct Messages and click the conversation.")
                        stepRow(number: "3", text: "Copy the URL from the browser address bar:")
                        
                        Text("https://www.instagram.com/direct/t/17849204859123456/")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        
                        stepRow(number: "4", text: "Paste the URL above. InstaChat will extract the Thread ID automatically.")
                    }
                    .padding(.vertical, 4)
                }

                Section("Session") {
                    Button(role: .destructive, action: { showingLogoutConfirmation = true }) {
                        Label("Log Out / Clear Instagram Session", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Configuration")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !threadId.isEmpty {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                inputThread = threadId
            }
            .alert("Invalid Input", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid Instagram Thread ID or direct conversation URL.")
            }
            .confirmationDialog("Log Out", isPresented: $showingLogoutConfirmation, titleVisibility: .visible) {
                Button("Log Out and Clear Data", role: .destructive) {
                    clearInstagramSession()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will clear cookies and stored session data. You will need to log in to Instagram again.")
            }
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(Color.accentColor.opacity(0.2))
                .clipShape(Circle())
            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private func saveThreadId() {
        if let extracted = DirectChatConfig.extractThreadId(from: inputThread) {
            threadId = extracted
            dismiss()
        } else {
            showingError = true
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
