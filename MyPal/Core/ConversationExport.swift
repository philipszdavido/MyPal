import CoreTransferable
import UniformTypeIdentifiers

/// A whole conversation as a Markdown file, built only when the person actually shares it.
struct ConversationExport: Transferable {
    let palId: UUID
    let palName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .plainText) { export in
            let messages = try await MessageStore.shared.fetchMessages(
                palId: export.palId, after: .distantPast, before: .distantFuture, limit: 0
            )
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(export.fileName).md")
            try export.markdown(for: messages).write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }

    private var fileName: String {
        let safe = palName.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
        return "Conversation with \(safe.isEmpty ? "Pal" : safe)"
    }

    func markdown(for messages: [ChatMessage]) -> String {
        var lines = ["# Conversation with \(palName)", "", "_Exported \(Date.now.formatted(date: .long, time: .shortened))_"]
        let calendar = Calendar.current
        var lastDay: Date?
        for message in messages {
            let day = calendar.startOfDay(for: message.date)
            if day != lastDay {
                lines += ["", "## \(message.date.formatted(date: .complete, time: .omitted))"]
                lastDay = day
            }
            let author = message.role == .user ? "You" : palName
            lines += ["", "**\(author)** · \(message.date.formatted(date: .omitted, time: .shortened))", "", message.text]
        }
        if messages.isEmpty { lines += ["", "No messages yet."] }
        return lines.joined(separator: "\n") + "\n"
    }
}
