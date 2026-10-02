import CoreData

/// Destructive pal operations in one place so every screen behaves identically.
@MainActor
enum PalActions {

    static func clearMessages(of pal: Pal) async {
        guard let id = pal.id else { return }
        ChatModelCache.shared.reset(palId: id)
        do {
            try await MessageStore.shared.deleteAll(palId: id)
        } catch {
            Log.data.error("Clear failed: \(error.localizedDescription)")
        }
    }

    static func delete(_ pal: Pal) async {
        let context = PersistenceController.shared.viewContext
        if let id = pal.id {
            ChatModelCache.shared.reset(palId: id)
            do {
                try await MessageStore.shared.deleteAll(palId: id)
            } catch {
                Log.data.error("Message cleanup failed: \(error.localizedDescription)")
            }
            ChatModelCache.shared.discard(palId: id)
        }
        context.delete(pal)
        do {
            try context.save()
        } catch {
            Log.data.error("Pal delete failed: \(error.localizedDescription)")
            context.rollback()
        }
    }

    static func clearAllConversations() async {
        ChatModelCache.shared.resetAll()
        do {
            try await MessageStore.shared.deleteAll(palId: nil)
        } catch {
            Log.data.error("Clear all failed: \(error.localizedDescription)")
        }
    }
}
