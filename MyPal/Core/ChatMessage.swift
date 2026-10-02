import Foundation

enum ChatRole: Sendable {
    case user
    case assistant
}

/// Value-type snapshot of a persisted message. The UI never touches Core Data objects directly.
struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: ChatRole
    let text: String
    let date: Date
}
