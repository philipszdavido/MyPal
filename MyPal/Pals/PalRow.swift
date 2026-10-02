import SwiftUI
import CoreData

struct PalRow: View {
    @ObservedObject private var pal: Pal
    @FetchRequest private var latest: FetchedResults<Message>

    init(pal: Pal) {
        _pal = ObservedObject(wrappedValue: pal)

        let request = Message.fetchRequest()
        request.predicate = NSPredicate(format: "palId == %@", pal.id?.uuidString ?? "")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Message.timestamp, ascending: false)]
        request.fetchLimit = 1
        _latest = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        HStack(spacing: 12) {
            PalAvatar(name: pal.name ?? "", size: 48)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(pal.name ?? "Untitled")
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let date = latest.first?.timestamp {
                        Text(DateLabel.listStamp(date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if let last = latest.first, let content = last.content, !content.isEmpty {
            let preview = content.markdownStripped
            return last.isAi ? preview : "You: \(preview)"
        }
        let instruction = pal.instruction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return instruction.isEmpty ? "No messages yet" : instruction
    }
}
