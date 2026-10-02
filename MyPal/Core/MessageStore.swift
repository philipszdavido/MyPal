import CoreData

/// All message I/O runs on one serial background context so the UI thread never blocks on SQLite.
/// Writes are scheduled in call order; reads are cursor-paginated by timestamp.
final class MessageStore: @unchecked Sendable {

    static let shared = MessageStore(persistence: .shared)

    private let context: NSManagedObjectContext
    private let viewContext: NSManagedObjectContext

    init(persistence: PersistenceController) {
        context = persistence.container.newBackgroundContext()
        context.name = "MessageStore"
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext = persistence.viewContext
    }

    /// Newest-first paging: returns up to `limit` messages older than `cursor`, oldest → newest.
    func fetchPage(palId: UUID, before cursor: Date?, limit: Int) async throws -> [ChatMessage] {
        try await context.perform { [context] () throws -> [ChatMessage] in
            let request = Message.fetchRequest()
            var predicates = [NSPredicate(format: "palId == %@", palId.uuidString)]
            if let cursor {
                predicates.append(NSPredicate(format: "timestamp < %@", cursor as NSDate))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.timestamp, ascending: false)]
            request.fetchLimit = limit
            request.returnsObjectsAsFaults = false

            let objects = try context.fetch(request)
            var page: [ChatMessage] = []
            page.reserveCapacity(objects.count)
            for object in objects.reversed() {
                page.append(ChatMessage(
                    id: object.id ?? UUID(),
                    role: object.isAi ? .assistant : .user,
                    text: object.content ?? "",
                    date: object.timestamp ?? .distantPast
                ))
            }
            context.reset()
            return page
        }
    }

    func insert(_ message: ChatMessage, palId: UUID) {
        context.perform { [context] in
            let object = Message(context: context)
            object.id = message.id
            object.content = message.text
            object.isAi = message.role == .assistant
            object.isPartial = false
            object.timestamp = message.date
            object.palId = palId.uuidString
            MessageStore.save(context)
        }
    }

    func delete(id: UUID) {
        context.perform { [context] in
            let request = Message.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            for object in (try? context.fetch(request)) ?? [] {
                context.delete(object)
            }
            MessageStore.save(context)
            context.reset()
        }
    }

    /// Deletes one pal's messages, or every message when `palId` is nil.
    func deleteAll(palId: UUID?) async throws {
        try await context.perform { [context, viewContext] () throws -> Void in
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Message")
            if let palId {
                fetch.predicate = NSPredicate(format: "palId == %@", palId.uuidString)
            }
            let request = NSBatchDeleteRequest(fetchRequest: fetch)
            request.resultType = .resultTypeObjectIDs

            let result = try context.execute(request) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [viewContext]
                )
            }
            context.reset()
        }
    }

    private static func save(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Log.data.error("Message save failed: \(error.localizedDescription)")
            context.rollback()
        }
    }
}
