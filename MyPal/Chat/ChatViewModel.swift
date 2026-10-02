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

struct ChatFailure: Equatable {
    let message: String
    let retryPrompt: String?
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

    @ObservationIgnored private let store: MessageStore
    @ObservationIgnored private var session: LanguageModelSession?
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var isLoadingInitial = false
    @ObservationIgnored private var isLoadingOlder = false
    @ObservationIgnored private let pageSize = 30

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

        do {
            let page = try await store.fetchPage(palId: palId, before: nil, limit: pageSize)
            messages = page
            hasMoreHistory = page.count == pageSize
        } catch {
            Log.chat.error("Initial load failed: \(error.localizedDescription)")
        }
        rebuildItems()
        didLoad = true
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
        rebuildItems()
        store.delete(id: message.id)
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
        rebuildItems()
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
    }

    // MARK: - Session

    private func makeSession(excludingLastMessage: Bool, shrinkRecap: Bool) -> LanguageModelSession {
        var parts = [
            instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "You are a friendly, helpful companion."
                : instruction,
            "Reply in plain text with light Markdown only (bold, lists, code blocks)."
        ]
        if let recap = recap(
            excludingLast: excludingLastMessage,
            maxMessages: shrinkRecap ? 2 : 6,
            maxCharacters: shrinkRecap ? 400 : 1200
        ) {
            parts.append("Earlier in this conversation:\n\(recap)")
        }
        return LanguageModelSession(instructions: parts.joined(separator: "\n\n"))
    }

    /// The on-device model has a small context window, so a rebuilt session only gets a compact recap.
    private func recap(excludingLast: Bool, maxMessages: Int, maxCharacters: Int) -> String? {
        let history = excludingLast ? Array(messages.dropLast()) : messages
        guard !history.isEmpty else { return nil }

        var lines: [String] = []
        var budget = maxCharacters
        for message in history.suffix(maxMessages).reversed() {
            var text = message.text.replacingOccurrences(of: "\n", with: " ")
            if text.count > 300 { text = String(text.prefix(300)) + "…" }
            let line = (message.role == .user ? "User: " : "You: ") + text
            guard line.count <= budget else { break }
            budget -= line.count
            lines.append(line)
        }
        return lines.isEmpty ? nil : lines.reversed().joined(separator: "\n")
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
    func discard(palId: UUID) { models[palId] = nil }
}
