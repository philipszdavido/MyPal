import Foundation

/// Long-term memory for one pal: a rolling summary of older conversation plus lasting facts
/// about the person. Everything older than the verbatim "recent window" lives here.
struct PalMemory: Codable, Equatable, Sendable {
    static let pinnedLimit = 20

    var summary: String = ""
    /// Learned by the summarizer; rewritten on every memory update.
    var facts: [String] = []
    /// Added by the person ("Remember this" or the editor). The summarizer never removes these.
    var pinnedFacts: [String] = []
    /// Messages up to and including this date are already folded into the summary.
    var coveredUntil: Date = .distantPast

    var isEmpty: Bool { summary.isEmpty && facts.isEmpty && pinnedFacts.isEmpty }

    init(summary: String = "", facts: [String] = [], pinnedFacts: [String] = [], coveredUntil: Date = .distantPast) {
        self.summary = summary
        self.facts = facts
        self.pinnedFacts = pinnedFacts
        self.coveredUntil = coveredUntil
    }

    /// Tolerates files written before a field existed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        facts = try container.decodeIfPresent([String].self, forKey: .facts) ?? []
        pinnedFacts = try container.decodeIfPresent([String].self, forKey: .pinnedFacts) ?? []
        coveredUntil = try container.decodeIfPresent(Date.self, forKey: .coveredUntil) ?? .distantPast
    }

    /// Adds a fact the person wants kept. Returns false if it was empty or already known.
    @discardableResult
    mutating func pin(_ rawFact: String) -> Bool {
        let fact = String(rawFact.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        let key = fact.lowercased()
        guard !fact.isEmpty,
              !pinnedFacts.contains(where: { $0.lowercased() == key }) else { return false }
        facts.removeAll { $0.lowercased() == key }
        pinnedFacts.append(fact)
        if pinnedFacts.count > Self.pinnedLimit { pinnedFacts.removeFirst() }
        return true
    }
}

/// Persists each pal's memory as a small JSON file in Application Support (on-device only).
actor MemoryStore {

    static let shared = MemoryStore()

    private let directory: URL
    private var cache: [UUID: PalMemory] = [:]

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("PalMemory", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func load(_ palId: UUID) -> PalMemory {
        if let cached = cache[palId] { return cached }
        let memory: PalMemory
        if let data = try? Data(contentsOf: url(for: palId)),
           let decoded = try? JSONDecoder().decode(PalMemory.self, from: data) {
            memory = decoded
        } else {
            memory = PalMemory()
        }
        cache[palId] = memory
        return memory
    }

    func save(_ memory: PalMemory, for palId: UUID) {
        cache[palId] = memory
        do {
            let data = try JSONEncoder().encode(memory)
            try data.write(to: url(for: palId), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            Log.data.error("Memory save failed: \(error.localizedDescription)")
        }
    }

    /// Empties memory but marks existing messages as already handled, so they aren't re-learned.
    func forget(_ palId: UUID) {
        save(PalMemory(coveredUntil: .now), for: palId)
    }

    /// Read-modify-write so edits from the editor and the chat don't clobber each other.
    @discardableResult
    func update(_ palId: UUID, _ change: (inout PalMemory) -> Void) -> PalMemory {
        var memory = load(palId)
        change(&memory)
        save(memory, for: palId)
        return memory
    }

    func delete(_ palId: UUID) {
        cache[palId] = nil
        try? FileManager.default.removeItem(at: url(for: palId))
    }

    func deleteAll() {
        cache.removeAll()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(for palId: UUID) -> URL {
        directory.appendingPathComponent("\(palId.uuidString).json")
    }
}
