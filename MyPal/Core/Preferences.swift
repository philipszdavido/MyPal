import Foundation

/// `UserDefaults` keys for settings the person can change, plus non-view accessors for them.
enum Preferences {
    static let showSuggestionsKey = "showSuggestions"
    static let readRepliesAloudKey = "readRepliesAloud"

    static var suggestionsEnabled: Bool {
        UserDefaults.standard.object(forKey: showSuggestionsKey) as? Bool ?? true
    }
}
