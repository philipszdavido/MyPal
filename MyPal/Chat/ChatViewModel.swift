import Foundation
import FoundationModels
import Observation

struct ChatItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case day(Date)
        case message(ChatMessage)
    }
    let id: String
    let kind: Kind
}

/// Structured output the summarizer fills in.
@Generable
struct MemoryUpdate {
    @Guide(description: "A concise third-person summary of everything discussed so far, under 700 characters.")
    var summary: String

    @Guide(description: "Lasting facts about the person (name, preferences, goals, relationships, important events). One short sentence each, at most 12.")
    var facts: [String]
}

/// Short messages the person might send next, shown as tappable chips.
@Generable
struct ReplySuggestions {
    @Guide(description: "Messages the person might send next, written in their voice. Each under 8 words, no quotes.", .count(3))
    var replies: [String]
}

struct ChatFailure: Equatable {
    let message: String
    let retryPrompt: String?
}

/// A brief, self-dismissing status line ("Saved to memory").
struct ChatNotice: Equatable, Identifiable {
    let id = UUID()
    let text: String
}

struct ChatReplyError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Owns one pal's conversation: paged history, the live model session, and streaming state.
///
/// Streaming text lives in `streamingText`, separate from `messages`, so each token only
/// invalidates the single streaming bubble — not the whole list. The finished reply is written
/// to Core Data once, on a background context.
@MainActor
@Observable
final class ChatViewModel {

    let palId: UUID
    private(set) var instruction: String

    private(set) var messages: [ChatMessage] = []
    private(set) var items: [ChatItem] = []
    private(set) var hasMoreHistory = false
    private(set) var didLoad = false
    private(set) var isReplying = false
    private(set) var streamingText = ""
    private(set) var failure: ChatFailure?
    private(set) var sentCount = 0
    private(set) var receivedCount = 0
    /// Conversation starters when the chat is empty, follow-up replies otherwise.
    private(set) var suggestions: [String] = []
    private(set) var notice: ChatNotice?

    @ObservationIgnored private let store: MessageStore
    @ObservationIgnored private var session: LanguageModelSession?
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var suggestionTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var isLoadingInitial = false
    @ObservationIgnored private var isLoadingOlder = false
    @ObservationIgnored private let pageSize = 30

    // Memory
    @ObservationIgnored private var memory = PalMemory()
    @ObservationIgnored private var isSummarizing = false
    @ObservationIgnored private var turnsInSession = 0

    /// Messages replayed verbatim to a rebuilt session. Everything older is carried by `memory`.
    private static let recentWindow = 10
    /// A live session is rebuilt after this many turns, well before the ~4K-token window fills.
    private static let maxTurnsPerSession = 5
    /// Summarize once at least this many messages have aged out of the recent window.
    private static let summarizeThreshold = 4

    init(palId: UUID, instruction: String, store: MessageStore = .shared) {
        self.palId = palId
        self.instruction = instruction
        self.store = store
    }

    // MARK: - History

    func loadInitial() async {
        guard !didLoad, !isLoadingInitial else { return }
        isLoadingInitial = true
        defer { isLoadingInitial = false }

        memory = await MemoryStore.shared.load(palId)
        do {
            let page = try await store.fetchPage(palId: palId, before: nil, limit: pageSize)
            messages = page
            hasMoreHistory = page.count == pageSize
        } catch {
            Log.chat.error("Initial load failed: \(error.localizedDescription)")
        }
        rebuildItems()
        didLoad = true
        if messages.isEmpty { refreshSuggestions() }
    }

    /// Loads the next-older page. Returns the id of the previously-oldest row so the view can
    /// restore its scroll position after the prepend.
    func loadOlder() async -> String? {
        guard hasMoreHistory, !isLoadingOlder, let oldest = messages.first else { return nil }
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            let page = try await store.fetchPage(palId: palId, before: oldest.date, limit: pageSize)
            hasMoreHistory = page.count == pageSize
            guard !page.isEmpty else { return nil }
            messages.insert(contentsOf: page, at: 0)
            rebuildItems()
            return oldest.id.uuidString
        } catch {
            Log.chat.error("Older page failed: \(error.localizedDescription)")
            hasMoreHistory = false
            return nil
        }
    }

    /// Drops far-off history from memory when the screen goes away; it pages back in on demand.
    func trim(keepingLast count: Int = 60) {
        guard !isReplying, messages.count > count else { return }
        messages = Array(messages.suffix(count))
        hasMoreHistory = true
        rebuildItems()
    }

    // MARK: - Sending

    func updateInstruction(_ newValue: String) {
        guard newValue != instruction else { return }
        instruction = newValue
        session = nil
    }

    /// Spins up the model before the person finishes typing to cut first-token latency.
    func prewarm() {
        guard didLoad, !isReplying, SystemLanguageModel.default.isAvailable else { return }
        if session == nil {
            session = makeSession(excludingLastMessage: false, shrinkRecap: false)
        }
        session?.prewarm()
    }

    func send(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isReplying else { return }

        failure = nil
        clearSuggestions()
        let message = ChatMessage(id: UUID(), role: .user, text: text, date: .now)
        messages.append(message)
        rebuildItems()
        store.insert(message, palId: palId)
        sentCount += 1
        startReply(to: text)
    }

    func retry() {
        guard !isReplying, let prompt = failure?.retryPrompt else { return }
        failure = nil
        startReply(to: prompt)
    }

    func stop() {
        streamTask?.cancel()
    }

    func delete(_ message: ChatMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages.remove(at: index)
        session = nil
        clearSuggestions()
        rebuildItems()
        store.delete(id: message.id)
    }

    /// True when the newest message is a reply to a prompt that can be asked again.
    var canRegenerate: Bool {
        !isReplying && messages.last?.role == .assistant && messages.dropLast().last?.role == .user
    }

    /// Replaces the newest reply with a fresh one for the same prompt.
    func regenerate() {
        guard canRegenerate, let reply = messages.last, let prompt = messages.dropLast().last else { return }
        messages.removeLast()
        store.delete(id: reply.id)
        session = nil
        failure = nil
        clearSuggestions()
        rebuildItems()
        startReply(to: prompt.text)
    }

    /// Removes the newest prompt (and any reply to it) so it can be edited and resent. Returns its text.
    func takeBackLastPrompt() -> String? {
        guard !isReplying, let index = messages.lastIndex(where: { $0.role == .user }) else { return nil }
        let removed = messages[index...]
        let text = removed.first?.text
        removed.forEach { store.delete(id: $0.id) }
        messages.removeSubrange(index...)
        session = nil
        failure = nil
        clearSuggestions()
        rebuildItems()
        return text
    }

    /// Pins a message's text into the pal's long-term memory.
    func remember(_ message: ChatMessage) {
        let text = message.text
        var probe = memory
        let isNew = probe.pin(text)
        Task {
            await PalActions.editMemory(palId: palId) { _ = $0.pin(text) }
            notice = ChatNotice(text: isNew ? "Saved to memory" : "Already remembered")
        }
    }

    func clearNotice() { notice = nil }

    /// Sends a message and waits for the finished reply. Used by Siri / Shortcuts.
    func sendAndWait(_ text: String) async throws -> String {
        await loadInitial()
        guard !isReplying else { throw ChatReplyError(message: "This pal is still replying. Try again in a moment.") }
        let countBefore = messages.count
        send(text)
        guard messages.count > countBefore else { throw ChatReplyError(message: "There was nothing to send.") }
        await streamTask?.value
        if let failure { throw ChatReplyError(message: failure.message) }
        guard let reply = messages.last, reply.role == .assistant else {
            throw ChatReplyError(message: "The pal didn't reply.")
        }
        return reply.text
    }

    /// Wipes in-memory state after the conversation was cleared elsewhere.
    func reset() {
        generation += 1
        streamTask?.cancel()
        streamTask = nil
        isReplying = false
        streamingText = ""
        failure = nil
        messages = []
        hasMoreHistory = false
        session = nil
        memory = PalMemory()
        turnsInSession = 0
        notice = nil
        rebuildItems()
        clearSuggestions()
        if didLoad { refreshSuggestions() }
    }

    /// Called when the person asks the pal to forget what it has learned (conversation is kept).
    func forgetMemory() {
        memory = PalMemory(coveredUntil: .now)
        session = nil
        turnsInSession = 0
    }

    /// Called after the person edited memory (pinned or removed facts) outside the summarizer.
    func memoryDidChange(to updated: PalMemory) {
        memory = updated
        session = nil
        turnsInSession = 0
    }

    // MARK: - Reply pipeline

    private func startReply(to prompt: String) {
        isReplying = true
        streamingText = ""
        let id = UUID()
        let date = Date.now
        let currentGeneration = generation
        streamTask = Task { [weak self] in
            await self?.runReply(prompt: prompt, id: id, date: date, generation: currentGeneration, isRetry: false)
        }
    }

    private func runReply(prompt: String, id: UUID, date: Date, generation gen: Int, isRetry: Bool) async {
        guard gen == generation else { return }
        var text = ""

        do {
            guard SystemLanguageModel.default.isAvailable else {
                throw ChatError.modelUnavailable
            }
            if turnsInSession >= Self.maxTurnsPerSession {
                self.session = nil
                turnsInSession = 0
            }
            let session = self.session ?? makeSession(excludingLastMessage: true, shrinkRecap: isRetry)
            self.session = session

            let clock = ContinuousClock()
            var lastFlush = clock.now

            for try await snapshot in session.streamResponse(to: prompt) {
                try Task.checkCancellation()
                text = snapshot.content
                let now = clock.now
                if now - lastFlush >= .milliseconds(33) {
                    streamingText = text
                    lastFlush = now
                }
            }
            streamingText = text
            turnsInSession += 1
            finishReply(id: id, date: date, text: text, generation: gen)

        } catch {
            guard gen == generation else { return }

            if Task.isCancelled || error is CancellationError {
                finishReply(id: id, date: date, text: text, generation: gen)
                return
            }

            session = nil
            Log.chat.error("Generation failed: \(error.localizedDescription)")

            if Self.isContextOverflow(error) {
                if text.isEmpty, !isRetry {
                    streamingText = ""
                    await runReply(prompt: prompt, id: id, date: date, generation: gen, isRetry: true)
                    return
                }
                if !text.isEmpty {
                    finishReply(id: id, date: date, text: text, generation: gen)
                    return
                }
            }

            isReplying = false
            streamingText = ""
            streamTask = nil
            failure = ChatFailure(message: Self.describe(error), retryPrompt: prompt)
        }
    }

    private func finishReply(id: UUID, date: Date, text: String, generation gen: Int) {
        guard gen == generation else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty {
            let reply = ChatMessage(id: id, role: .assistant, text: trimmed, date: date)
            messages.append(reply)
            rebuildItems()
            store.insert(reply, palId: palId)
            receivedCount += 1
        }
        isReplying = false
        streamingText = ""
        streamTask = nil
        updateMemoryIfNeeded()
        refreshSuggestions()
    }

    // MARK: - Session

    private func makeSession(excludingLastMessage: Bool, shrinkRecap: Bool) -> LanguageModelSession {
        let persona = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = [
            persona.isEmpty ? "You are a friendly, helpful companion." : persona,
            "Today is \(Date.now.formatted(date: .complete, time: .shortened)).",
            "You are a long-term companion with a real memory of this person. Use what you remember naturally, "
                + "without announcing that you are recalling it. If you are unsure of a detail, say so instead of guessing.",
            "Reply in plain text with light Markdown only (bold, lists, code blocks)."
        ]

        if let memoryBlock = memoryBlock(shrunk: shrinkRecap) {
            parts.append(memoryBlock)
        }
        if let recap = recap(
            excludingLast: excludingLastMessage,
            maxMessages: shrinkRecap ? 2 : Self.recentWindow,
            maxCharacters: shrinkRecap ? 400 : 2400
        ) {
            parts.append("Most recent messages, oldest first:\n\(recap)")
        }
        return LanguageModelSession(instructions: parts.joined(separator: "\n\n"))
    }

    private func memoryBlock(shrunk: Bool) -> String? {
        guard !memory.isEmpty else { return nil }
        var lines: [String] = []
        let allFacts = memory.pinnedFacts + memory.facts
        if !allFacts.isEmpty {
            let facts = shrunk ? Array(allFacts.prefix(5)) : allFacts
            lines.append("What you know about the person:\n" + facts.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !memory.summary.isEmpty {
            let summary = shrunk ? String(memory.summary.prefix(500)) : memory.summary
            lines.append("Summary of your earlier conversations:\n\(summary)")
        }
        return lines.joined(separator: "\n\n")
    }

    /// The on-device model has a small context window, so a rebuilt session only gets a compact recap.
    private func recap(excludingLast: Bool, maxMessages: Int, maxCharacters: Int) -> String? {
        let history = excludingLast ? Array(messages.dropLast()) : messages
        guard !history.isEmpty else { return nil }

        var lines: [String] = []
        var budget = maxCharacters
        for message in history.suffix(maxMessages).reversed() {
            var text = message.text.replacingOccurrences(of: "\n", with: " ")
            if text.count > 350 { text = String(text.prefix(350)) + "…" }
            let line = (message.role == .user ? "User: " : "You: ") + text
            guard line.count <= budget else { break }
            budget -= line.count
            lines.append(line)
        }
        return lines.isEmpty ? nil : lines.reversed().joined(separator: "\n")
    }

    // MARK: - Long-term memory

    /// Folds messages that have aged out of the recent window into the pal's memory, in the background.
    private func updateMemoryIfNeeded() {
        guard !isSummarizing, messages.count > Self.recentWindow,
              SystemLanguageModel.default.isAvailable else { return }
        isSummarizing = true
        let cutoff = messages[messages.count - Self.recentWindow].date
        let gen = generation
        Task { [weak self] in
            await self?.runMemoryUpdate(before: cutoff, generation: gen)
        }
    }

    private func runMemoryUpdate(before cutoff: Date, generation gen: Int) async {
        defer { isSummarizing = false }

        // A few passes so a long backlog (e.g. an old conversation) is caught up in one go.
        for _ in 0..<4 {
            guard gen == generation, !isReplying else { return }

            let pending: [ChatMessage]
            do {
                pending = try await store.fetchMessages(palId: palId, after: memory.coveredUntil, before: cutoff, limit: 40)
            } catch {
                Log.chat.error("Memory fetch failed: \(error.localizedDescription)")
                return
            }
            guard pending.count >= Self.summarizeThreshold else { return }

            // Keep each pass comfortably inside the model's context window.
            var batch: [ChatMessage] = []
            var budget = 4500
            for message in pending {
                let cost = min(message.text.count, 400) + 12
                if cost > budget { break }
                budget -= cost
                batch.append(message)
            }
            guard let last = batch.last else { return }

            do {
                let update = try await summarize(batch)
                guard gen == generation else { return }
                var updated = memory
                updated.summary = String(update.summary.trimmingCharacters(in: .whitespacesAndNewlines).prefix(900))
                updated.facts = Self.cleanedFacts(update.facts, excluding: updated.pinnedFacts)
                updated.coveredUntil = last.date
                memory = updated
                await MemoryStore.shared.save(updated, for: palId)
            } catch {
                if let generationError = error as? LanguageModelSession.GenerationError,
                   case .guardrailViolation = generationError {
                    // Never let one un-summarizable message block memory forever.
                    guard gen == generation else { return }
                    memory.coveredUntil = last.date
                    await MemoryStore.shared.save(memory, for: palId)
                } else {
                    Log.chat.error("Memory update failed: \(error.localizedDescription)")
                    return
                }
            }

            if pending.count == batch.count { return }
        }
    }

    private func summarize(_ batch: [ChatMessage]) async throws -> MemoryUpdate {
        let transcript = batch.map { message -> String in
            var text = message.text.replacingOccurrences(of: "\n", with: " ")
            if text.count > 400 { text = String(text.prefix(400)) + "…" }
            return (message.role == .user ? "Person: " : "Pal: ") + text
        }.joined(separator: "\n")

        let existing = memoryBlock(shrunk: false) ?? "Nothing yet."
        let session = LanguageModelSession(instructions: """
            You maintain the long-term memory of a chat companion. Merge the new conversation into the \
            existing memory. Keep the summary short and factual. Keep only lasting facts about the person \
            (name, preferences, goals, relationships, important events); drop trivia and anything outdated \
            or contradicted. Never invent details.
            """)
        let prompt = "Existing memory:\n\(existing)\n\nNew conversation:\n\(transcript)"
        return try await session.respond(to: prompt, generating: MemoryUpdate.self).content
    }

    private static func cleanedFacts(_ facts: [String], excluding pinned: [String]) -> [String] {
        var seen = Set(pinned.map { $0.lowercased() })
        var result: [String] = []
        for fact in facts {
            let trimmed = fact.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            result.append(String(trimmed.prefix(160)))
            if result.count == 12 { break }
        }
        return result
    }

    // MARK: - Suggestions

    private func clearSuggestions() {
        suggestionTask?.cancel()
        suggestionTask = nil
        suggestions = []
    }

    /// Starters for an empty chat, follow-ups after a reply. Runs in the background and is
    /// dropped if anything changes in the conversation before it finishes.
    private func refreshSuggestions() {
        clearSuggestions()
        guard Preferences.suggestionsEnabled, !isReplying, SystemLanguageModel.default.isAvailable else { return }
        let gen = generation
        let anchor = messages.last?.id
        suggestionTask = Task { [weak self] in
            await self?.generateSuggestions(generation: gen, anchor: anchor)
        }
    }

    private func generateSuggestions(generation gen: Int, anchor: UUID?) async {
        let persona = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        var context = ["The pal's personality: \(persona.isEmpty ? "a friendly, helpful companion" : persona)"]
        if let memoryBlock = memoryBlock(shrunk: true) {
            context.append(memoryBlock)
        }

        let prompt: String
        if let recap = recap(excludingLast: false, maxMessages: 2, maxCharacters: 700) {
            context.append("Latest messages:\n\(recap)")
            prompt = "Suggest three short replies the person might send next."
        } else {
            prompt = "Suggest three short, varied ways the person could start a conversation with this pal."
        }

        let session = LanguageModelSession(instructions: """
            You suggest what a person might say next to their chat companion ("the pal"). \
            Write from the person's point of view, never the pal's.

            \(context.joined(separator: "\n\n"))
            """)
        do {
            let result = try await session.respond(to: prompt, generating: ReplySuggestions.self).content
            guard !Task.isCancelled, gen == generation, !isReplying, messages.last?.id == anchor else { return }
            var seen = Set<String>()
            suggestions = result.replies
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"\u{201C}\u{201D}"))) }
                .filter { !$0.isEmpty && $0.count <= 80 && seen.insert($0.lowercased()).inserted }
        } catch {
            if !(error is CancellationError) {
                Log.chat.debug("Suggestions failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private enum ChatError: Error { case modelUnavailable }

    private static func isContextOverflow(_ error: Error) -> Bool {
        if let generationError = error as? LanguageModelSession.GenerationError,
           case .exceededContextWindowSize = generationError {
            return true
        }
        return false
    }

    private static func describe(_ error: Error) -> String {
        if error is ChatError {
            return "Apple Intelligence isn't available right now."
        }
        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .guardrailViolation:
                return "That message was blocked by on-device safety filters. Try rephrasing it."
            case .exceededContextWindowSize:
                return "That message is too long for the on-device model. Try a shorter one."
            case .assetsUnavailable:
                return "The on-device model isn't ready yet. Please try again shortly."
            case .unsupportedLanguageOrLocale:
                return "This language isn't supported by the on-device model yet."
            default:
                break
            }
        }
        return "Something went wrong while generating a reply."
    }

    private func rebuildItems() {
        var result: [ChatItem] = []
        result.reserveCapacity(messages.count + 8)
        let calendar = Calendar.current
        var lastDay: Date?

        for message in messages {
            let day = calendar.startOfDay(for: message.date)
            if day != lastDay {
                result.append(ChatItem(id: "day-\(Int(day.timeIntervalSince1970))", kind: .day(day)))
                lastDay = day
            }
            result.append(ChatItem(id: message.id.uuidString, kind: .message(message)))
        }
        items = result
    }
}

/// Keeps one model per pal alive so a reply that's still streaming survives leaving the screen,
/// and re-entering a chat is instant.
@MainActor
final class ChatModelCache {
    static let shared = ChatModelCache()
    private var models: [UUID: ChatViewModel] = [:]

    func model(for pal: Pal) -> ChatViewModel {
        let id = pal.id ?? UUID()
        let instruction = pal.instruction ?? ""
        if let existing = models[id] {
            existing.updateInstruction(instruction)
            return existing
        }
        let model = ChatViewModel(palId: id, instruction: instruction)
        models[id] = model
        return model
    }

    func reset(palId: UUID) { models[palId]?.reset() }
    func resetAll() { models.values.forEach { $0.reset() } }
    func forgetMemory(palId: UUID) { models[palId]?.forgetMemory() }
    func memoryDidChange(palId: UUID, to memory: PalMemory) { models[palId]?.memoryDidChange(to: memory) }
    func discard(palId: UUID) { models[palId] = nil }
}
