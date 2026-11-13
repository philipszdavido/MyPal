import AppIntents
import CoreData

/// A pal as Siri / Shortcuts / Spotlight see it.
struct PalEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Pal"
    static let defaultQuery = PalQuery()

    let id: UUID
    let name: String
    let emoji: String?

    var displayRepresentation: DisplayRepresentation {
        if let emoji, !emoji.isEmpty {
            return DisplayRepresentation(title: "\(emoji) \(name)")
        }
        return DisplayRepresentation(title: "\(name)")
    }
}

struct PalQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [PalEntity] {
        try await fetch(NSPredicate(format: "id IN %@", identifiers))
    }

    func entities(matching string: String) async throws -> [PalEntity] {
        try await fetch(NSPredicate(format: "name CONTAINS[cd] %@", string))
    }

    func suggestedEntities() async throws -> [PalEntity] {
        try await fetch(nil)
    }

    private func fetch(_ predicate: NSPredicate?) async throws -> [PalEntity] {
        let context = PersistenceController.shared.container.newBackgroundContext()
        // NSPredicate is immutable once built, so handing it to the context's queue is safe.
        nonisolated(unsafe) let predicate = predicate
        return try await context.perform {
            let request = Pal.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Pal.timestamp, ascending: true)]
            return try context.fetch(request).compactMap { pal in
                guard let id = pal.id else { return nil }
                return PalEntity(id: id, name: pal.name ?? "Pal", emoji: pal.emoji)
            }
        }
    }
}

/// Sends a message to a pal and speaks / returns the reply. Uses the same view model as the
/// chat screen, so the exchange lands in the conversation and in the pal's memory.
struct AskPalIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask a Pal"
    static let description = IntentDescription("Send a message to one of your pals and get its reply.")

    @Parameter(title: "Pal")
    var pal: PalEntity

    @Parameter(title: "Message", requestValueDialog: "What would you like to say?")
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask \(\.$pal) \(\.$message)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let request = Pal.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", pal.id as CVarArg)
        request.fetchLimit = 1
        guard let object = try PersistenceController.shared.viewContext.fetch(request).first else {
            throw AskPalError.message("That pal no longer exists.")
        }

        do {
            let reply = try await ChatModelCache.shared.model(for: object).sendAndWait(message)
            return .result(value: reply, dialog: IntentDialog(stringLiteral: reply.markdownStripped))
        } catch {
            throw AskPalError.message(error.localizedDescription)
        }
    }
}

enum AskPalError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let text): "\(text)"
        }
    }
}

struct MyPalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskPalIntent(),
            phrases: [
                "Ask \(\.$pal) in \(.applicationName)",
                "Talk to \(\.$pal) in \(.applicationName)",
                "Ask a pal in \(.applicationName)"
            ],
            shortTitle: "Ask a Pal",
            systemImageName: "bubble.left.and.text.bubble.right"
        )
    }
}
