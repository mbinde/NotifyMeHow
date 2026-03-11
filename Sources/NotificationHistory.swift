import Cocoa

/// A recorded notification for the history
struct RecordedNotification: Identifiable {
    let id = UUID()
    let timestamp: Date
    let appName: String
    let title: String
    let subtitle: String
    let body: String
    let appIcon: NSImage?

    /// Generate suggested keywords by extracting non-stopwords from title and body
    func suggestedKeywords(maxWords: Int = 5) -> String {
        let stopWords: Set<String> = [
            "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "is", "are", "was", "were", "be", "been",
            "being", "have", "has", "had", "do", "does", "did", "will", "would",
            "could", "should", "may", "might", "must", "shall", "can", "need",
            "it", "its", "this", "that", "these", "those", "i", "you", "he", "she",
            "we", "they", "my", "your", "his", "her", "our", "their", "me", "him",
            "us", "them", "what", "which", "who", "whom", "when", "where", "why",
            "how", "all", "each", "every", "both", "few", "more", "most", "other",
            "some", "such", "no", "not", "only", "own", "same", "so", "than", "too",
            "very", "just", "also", "now", "new", "one", "two", "first", "last"
        ]

        let allText = "\(title) \(subtitle) \(body)"
        let words = allText
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { word in
                word.count > 2 && !stopWords.contains(word)
            }

        // Get unique words preserving order of first appearance
        var seen = Set<String>()
        var uniqueWords: [String] = []
        for word in words {
            if !seen.contains(word) {
                seen.insert(word)
                uniqueWords.append(word)
            }
            if uniqueWords.count >= maxWords {
                break
            }
        }

        return uniqueWords.joined(separator: ", ")
    }
}

/// Manages in-memory notification history for creating rules
class NotificationHistory {
    static let shared = NotificationHistory()

    /// Posted when history changes
    static let didChangeNotification = Notification.Name("NotificationHistoryDidChange")

    private(set) var notifications: [RecordedNotification] = []

    /// Whether recording is enabled
    var isRecording: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationHistoryRecording") }
        set {
            UserDefaults.standard.set(newValue, forKey: "notificationHistoryRecording")
            notifyChange()
        }
    }

    /// How many minutes of history to keep
    var retentionMinutes: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: "notificationHistoryRetentionMinutes")
            return value > 0 ? value : 30  // Default 30 minutes
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "notificationHistoryRetentionMinutes")
            pruneOldNotifications()
        }
    }

    private init() {
        // Default to recording enabled
        if UserDefaults.standard.object(forKey: "notificationHistoryRecording") == nil {
            UserDefaults.standard.set(true, forKey: "notificationHistoryRecording")
        }
    }

    /// Record a notification (if recording is enabled)
    func record(_ content: NotificationContent) {
        guard isRecording else { return }

        let recorded = RecordedNotification(
            timestamp: Date(),
            appName: content.appName,
            title: content.title,
            subtitle: content.subtitle,
            body: content.body,
            appIcon: content.appIcon
        )

        notifications.insert(recorded, at: 0)
        pruneOldNotifications()
        notifyChange()
    }

    /// Remove notifications older than retention period
    private func pruneOldNotifications() {
        let cutoff = Date().addingTimeInterval(-Double(retentionMinutes * 60))
        notifications.removeAll { $0.timestamp < cutoff }
    }

    /// Clear all history
    func clearAll() {
        notifications.removeAll()
        notifyChange()
    }

    /// Delete a specific notification
    func delete(_ notification: RecordedNotification) {
        notifications.removeAll { $0.id == notification.id }
        notifyChange()
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: NotificationHistory.didChangeNotification, object: nil)
    }
}
