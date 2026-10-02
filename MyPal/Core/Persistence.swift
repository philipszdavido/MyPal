import CoreData

private final class LoadErrorBox: @unchecked Sendable {
    var error: Error?
}

final class PersistenceController {

    static let shared = PersistenceController()

    let container: NSPersistentContainer

    /// Non-nil when the on-disk store couldn't be opened and an in-memory fallback is in use.
    /// The on-disk data is left untouched so a later launch (or app update) can recover it.
    private(set) var loadError: Error?

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MyPal")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        let box = LoadErrorBox()
        container.loadPersistentStores { _, error in box.error = error }

        if let failure = box.error {
            Log.data.fault("Persistent store failed to load: \(failure.localizedDescription)")
            loadError = failure

            let fallback = NSPersistentStoreDescription()
            fallback.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [fallback]
            container.loadPersistentStores { _, error in
                if let error { fatalError("Unable to load even an in-memory store: \(error)") }
            }
        }

        let context = container.viewContext
        context.name = "view"
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}

// MARK: - Previews

extension PersistenceController {

    @MainActor
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext

        let samples: [(String, String)] = [
            ("Movie Critic", "You are a thoughtful movie critic."),
            ("Mentor", "You are a calm, encouraging mentor."),
            ("Hobbies Pal", "Suggest related topics. Keep them concise.")
        ]
        for (index, sample) in samples.enumerated() {
            let pal = Pal(context: context)
            pal.id = UUID()
            pal.name = sample.0
            pal.instruction = sample.1
            pal.timestamp = Date.now.addingTimeInterval(Double(index))

            if index == 0, let palId = pal.id?.uuidString {
                let exchange: [(String, Bool)] = [
                    ("What should I watch tonight?", false),
                    ("**Arrival** is a great pick:\n- Thoughtful sci-fi\n- Strong lead performance\n- Short enough for a weeknight", true)
                ]
                for (offset, line) in exchange.enumerated() {
                    let message = Message(context: context)
                    message.id = UUID()
                    message.content = line.0
                    message.isAi = line.1
                    message.palId = palId
                    message.timestamp = Date.now.addingTimeInterval(Double(offset) - 60)
                }
            }
        }
        try? context.save()
        return controller
    }()

    @MainActor
    var samplePal: Pal {
        let request = Pal.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Pal.timestamp, ascending: true)]
        request.fetchLimit = 1
        return (try? viewContext.fetch(request).first) ?? Pal(context: viewContext)
    }
}
