import Foundation

/// Manages configuration and persistence for the pinned Instagram DM thread.
enum DirectChatConfig {
    static let threadIdKey = "instagram_pinned_thread_id"
    
    /// Extracts the thread ID from either a raw ID string or a full Instagram direct URL.
    /// Example inputs:
    ///   - "17849204859123456"
    ///   - "https://www.instagram.com/direct/t/17849204859123456/"
    ///   - "instagram.com/direct/t/17849204859123456"
    static func extractThreadId(from input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // If the user pasted a full URL or partial path containing "/direct/t/"
        if let directIndex = trimmed.range(of: "/direct/t/") {
            let afterDirect = trimmed[directIndex.upperBound...]
            let rawId = afterDirect.components(separatedBy: CharacterSet(charactersIn: "/?#")).first ?? ""
            let cleaned = rawId.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }
        
        // If only the numeric/alphanumeric thread ID was provided
        let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/?# \t\n\r"))
        return cleaned.isEmpty ? nil : cleaned
    }
    
    /// Constructs the direct URL for a given thread ID.
    static func makeThreadURL(for threadId: String) -> URL? {
        guard !threadId.isEmpty else { return nil }
        return URL(string: "https://www.instagram.com/direct/t/\(threadId)/")
    }
}
