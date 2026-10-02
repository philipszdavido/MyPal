import SwiftUI

extension View {
    /// Shared bubble chrome: accent for the person, secondary fill for the pal, with a tighter "tail" corner.
    func chatBubble(isUser: Bool) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isUser ? Color.white : Color.primary)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 20,
                    bottomLeadingRadius: isUser ? 20 : 6,
                    bottomTrailingRadius: isUser ? 6 : 20,
                    topTrailingRadius: 20,
                    style: .continuous
                )
                .fill(isUser ? Color.accentColor : Color(.secondarySystemBackground))
            )
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let onDelete: (ChatMessage) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let isUser = message.role == .user
        let gap: CGFloat = sizeClass == .regular ? 120 : 48

        HStack(spacing: 0) {
            if isUser { Spacer(minLength: gap) }

            Group {
                if isUser {
                    Text(verbatim: message.text)
                } else {
                    MarkdownView(blocks: MarkdownCache.blocks(for: message.text, key: message.id.uuidString))
                }
            }
            .chatBubble(isUser: isUser)

            if !isUser { Spacer(minLength: gap) }
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: (isUser ? "You: " : "Reply: ") + message.text.markdownStripped))
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.text
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            ShareLink(item: message.text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button(role: .destructive) {
                onDelete(message)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// Live bubble for the reply that's currently streaming. It's the only view that reads `streamingText`.
struct StreamingBubble: View {
    let model: ChatViewModel
    let onGrow: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let text = model.streamingText

        HStack(spacing: 0) {
            Group {
                if text.isEmpty {
                    TypingDots()
                } else {
                    MarkdownView(blocks: MarkdownParser.parse(text))
                }
            }
            .chatBubble(isUser: false)

            Spacer(minLength: sizeClass == .regular ? 120 : 48)
        }
        .padding(.horizontal, 12)
        .onChange(of: text.count) { _, _ in onGrow() }
        .accessibilityLabel(text.isEmpty ? Text("Typing") : Text(verbatim: text.markdownStripped))
    }
}

struct TypingDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Dot(delay: Double(index) * 0.15, animates: !reduceMotion)
            }
        }
        .frame(height: 20)
    }

    private struct Dot: View {
        let delay: Double
        let animates: Bool
        @State private var raised = false

        var body: some View {
            Circle()
                .fill(.secondary)
                .frame(width: 7, height: 7)
                .offset(y: raised ? -3 : 3)
                .animation(
                    animates ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(delay) : nil,
                    value: raised
                )
                .onAppear { raised = animates }
        }
    }
}

struct DayHeader: View {
    let date: Date

    var body: some View {
        Text(DateLabel.day(date))
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
    }
}

struct FailureRow: View {
    let failure: ChatFailure
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(failure.message).font(.footnote)
            Spacer(minLength: 8)
            if failure.retryPrompt != nil {
                Button("Retry", action: onRetry)
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}

struct EmptyChatView: View {
    @ObservedObject var pal: Pal

    var body: some View {
        VStack(spacing: 12) {
            PalAvatar(name: pal.name ?? "", size: 72)
            Text(pal.name ?? "").font(.title2.bold())
            if let instruction = pal.instruction, !instruction.isEmpty {
                Text(instruction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            Text("Say hello to get started.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
        .allowsHitTesting(false)
    }
}
