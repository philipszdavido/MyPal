import CoreData

/// Destructive pal operations in one place so every screen behaves identically.
@MainActor
enum PalActions {

    static func clearMessages(of pal: Pal) async {
        guard let id = pal.id else { return }
        ChatModelCache.shared.reset(palId: id)
        await MemoryStore.shared.delete(id)
        do {
            try await MessageStore.shared.deleteAll(palId: id)
        } catch {
            Log.data.error("Clear failed: \(error.localizedDescription)")
        }
    }

    /// Keeps the conversation but erases what the pal has learned from it.
    static func forgetMemory(of pal: Pal) async {
        guard let id = pal.id else { return }
        ChatModelCache.shared.forgetMemory(palId: id)
        await MemoryStore.shared.forget(id)
    }

    /// Applies a person-made memory edit (pin, remove) and hands the result to the live chat.
    @discardableResult
    static func editMemory(palId: UUID, _ change: @Sendable (inout PalMemory) -> Void) async -> PalMemory {
        let updated = await MemoryStore.shared.update(palId, change)
        ChatModelCache.shared.memoryDidChange(palId: palId, to: updated)
        return updated
    }

    static func delete(_ pal: Pal) async {
        let context = PersistenceController.shared.viewContext
        if let id = pal.id {
            ChatModelCache.shared.reset(palId: id)
            await MemoryStore.shared.delete(id)
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
            MyPalShortcuts.updateAppShortcutParameters()
        } catch {
            Log.data.error("Pal delete failed: \(error.localizedDescription)")
            context.rollback()
        }
    }

    static func clearAllConversations() async {
        ChatModelCache.shared.resetAll()
        await MemoryStore.shared.deleteAll()
        do {
            try await MessageStore.shared.deleteAll(palId: nil)
        } catch {
            Log.data.error("Clear all failed: \(error.localizedDescription)")
        }
    }
}
