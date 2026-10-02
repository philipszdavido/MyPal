import CoreData

struct DefaultPal {
    let name: String
    let instruction: String
}

enum DefaultPals {
    static let all: [DefaultPal] = [
        DefaultPal(
            name: "Hobbies Pal",
            instruction: """
            Suggest related topics. Keep them concise (three to seven words) and \
            make sure they build naturally from the person's topic.
            """
        ),
        DefaultPal(
            name: "Movie Critic",
            instruction: "You are a thoughtful movie critic. Discuss story, performances, direction and craft, and avoid spoilers unless asked."
        ),
        DefaultPal(
            name: "Music Critic",
            instruction: "You are a thoughtful music critic. Discuss songs, albums and artists with insight into sound, lyrics and context."
        ),
        DefaultPal(
            name: "Mentor",
            instruction: "You are a calm, encouraging mentor. Ask good questions and give practical, honest guidance."
        )
    ]
}

/// One-time launch work: repairs records written by older builds and seeds the default pals.
enum PalSeeder {

    private static let seededKey = "didSeedDefaultPals"

    static func run(in context: NSManagedObjectContext) {
        context.performAndWait {
            repairLegacyRecords(in: context)
            seedDefaultsIfNeeded(in: context)

            guard context.hasChanges else { return }
            do {
                try context.save()
            } catch {
                Log.data.error("Seeding failed: \(error.localizedDescription)")
                context.rollback()
            }
        }
    }

    private static func repairLegacyRecords(in context: NSManagedObjectContext) {
        // Pals created by older builds could be missing an id or timestamp.
        let palRequest = Pal.fetchRequest()
        palRequest.predicate = NSPredicate(format: "id == nil OR timestamp == nil")
        for pal in (try? context.fetch(palRequest)) ?? [] {
            if pal.id == nil { pal.id = UUID() }
            if pal.timestamp == nil { pal.timestamp = Date.now }
        }

        // Streaming placeholders that were never finalized (app killed mid-reply).
        let partialRequest = Message.fetchRequest()
        partialRequest.predicate = NSPredicate(format: "isPartial == YES")
        for message in (try? context.fetch(partialRequest)) ?? [] {
            context.delete(message)
        }
    }

    private static func seedDefaultsIfNeeded(in context: NSManagedObjectContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)

        // Existing installs keep exactly the pals they already have.
        let existing = (try? context.count(for: Pal.fetchRequest())) ?? 0
        guard existing == 0 else { return }

        let now = Date.now
        for (index, template) in DefaultPals.all.enumerated() {
            let pal = Pal(context: context)
            pal.id = UUID()
            pal.name = template.name
            pal.instruction = template.instruction
            pal.timestamp = now.addingTimeInterval(Double(index))
        }
    }
}
