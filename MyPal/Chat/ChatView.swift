import SwiftUI

struct ChatView: View {
    @ObservedObject private var pal: Pal
    @State private var model: ChatViewModel

    @State private var draft = ""
    @State private var position = ScrollPosition(edge: .bottom)
    @State private var isPinnedToBottom = true
    @State private var showClearConfirmation = false
    @State private var showEditor = false
    @FocusState private var isComposerFocused: Bool
    @AppStorage(Preferences.showSuggestionsKey) private var showSuggestions = true
    @AppStorage(Preferences.readRepliesAloudKey) private var readRepliesAloud = false

    @Environment(ModelAvailability.self) private var availability
    @Environment(\.dismiss) private var dismiss

    init(pal: Pal) {
        _pal = ObservedObject(wrappedValue: pal)
        _model = State(initialValue: ChatModelCache.shared.model(for: pal))
    }

    var body: some View {
        Group {
            if model.didLoad {
                messageList
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .navigationTitle(pal.name ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .toolbarVisibility(.hidden, for: .tabBar)
        .task { await model.loadInitial() }
        .onChange(of: pal.instruction) { _, newValue in model.updateInstruction(newValue ?? "") }
        .onChange(of: pal.isDeleted) { _, deleted in if deleted { dismiss() } }
        .onChange(of: isComposerFocused) { _, focused in
            guard focused else { return }
            model.prewarm()
            if isPinnedToBottom { scrollToBottom(animated: true) }
        }
        .onDisappear {
            isComposerFocused = false
            Speaker.shared.stop()
            model.trim()
        }
        .onChange(of: model.receivedCount) { _, _ in
            if readRepliesAloud, let reply = model.messages.last, reply.role == .assistant {
                Speaker.shared.speak(reply)
            }
        }
        .overlay(alignment: .top) { noticeBanner }
        .tint(pal.tint)
        .sensoryFeedback(.impact(weight: .light), trigger: model.sentCount)
        .sensoryFeedback(.success, trigger: model.receivedCount)
        .sensoryFeedback(.selection, trigger: model.notice)
        .confirmationDialog("Clear this conversation?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear Conversation", role: .destructive) {
                Task { await PalActions.clearMessages(of: pal) }
            }
        } message: {
            Text("All messages with \(pal.name ?? "this pal") and its memory will be deleted. This can't be undone.")
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack { PalEditorView(mode: .edit(pal)) }
        }
    }

    // MARK: Message list

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                if model.hasMoreHistory {
                    ProgressView()
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .task(id: model.items.first?.id) { await loadOlder() }
                }

                ForEach(model.items) { item in
                    row(for: item)
                }

                if model.isReplying {
                    StreamingBubble(model: model) {
                        if isPinnedToBottom { scrollToBottom(animated: false) }
                    }
                }

                if let failure = model.failure {
                    FailureRow(failure: failure) { model.retry() }
                }
            }
            .scrollTargetLayout()
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollPosition($position)
        .scrollDismissesKeyboard(.interactively)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            let distanceFromBottom = geometry.contentSize.height + geometry.contentInsets.bottom
                - (geometry.contentOffset.y + geometry.containerSize.height)
            return distanceFromBottom < 160
        } action: { _, pinned in
            isPinnedToBottom = pinned
        }
        .onTapGesture { isComposerFocused = false }
        .overlay {
            if model.items.isEmpty && !model.isReplying {
                EmptyChatView(pal: pal)
            }
        }
        .overlay(alignment: .bottomTrailing) { scrollToBottomButton }
        .animation(.snappy, value: isPinnedToBottom)
        .onChange(of: model.items.last?.id) { _, _ in
            if isPinnedToBottom || model.messages.last?.role == .user {
                scrollToBottom(animated: true)
            }
        }
        .onChange(of: model.isReplying) { _, _ in
            if isPinnedToBottom { scrollToBottom(animated: true) }
        }
        .onChange(of: model.failure) { _, failure in
            if failure != nil { scrollToBottom(animated: true) }
        }
    }

    @ViewBuilder
    private func row(for item: ChatItem) -> some View {
        switch item.kind {
        case .day(let date):
            DayHeader(date: date)
        case .message(let message):
            MessageBubble(message: message, isLatest: isLatest(message)) { action in
                handle(action, on: message)
            }
        }
    }

    private func isLatest(_ message: ChatMessage) -> Bool {
        switch message.role {
        case .assistant: message.id == model.messages.last?.id && model.canRegenerate
        case .user: !model.isReplying && message.id == model.messages.last(where: { $0.role == .user })?.id
        }
    }

    private func handle(_ action: MessageAction, on message: ChatMessage) {
        switch action {
        case .delete:
            if Speaker.shared.speakingId == message.id { Speaker.shared.stop() }
            model.delete(message)
        case .remember:
            model.remember(message)
        case .readAloud:
            Speaker.shared.toggle(message)
        case .regenerate:
            Speaker.shared.stop()
            model.regenerate()
        case .editAndResend:
            if let text = model.takeBackLastPrompt() {
                draft = text
                isComposerFocused = true
            }
        }
    }

    @ViewBuilder
    private var noticeBanner: some View {
        if let notice = model.notice {
            Label(notice.text, systemImage: "pin.fill")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: notice.id) {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(.snappy) { model.clearNotice() }
                }
        }
    }

    @ViewBuilder
    private var scrollToBottomButton: some View {
        if !isPinnedToBottom && !model.items.isEmpty {
            Button {
                scrollToBottom(animated: true)
            } label: {
                Image(systemName: "arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glass)
            .padding(.trailing, 16)
            .padding(.bottom, 8)
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel("Scroll to latest message")
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if !availability.isAvailable {
                AvailabilityBanner(availability: availability)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
            }
            if showSuggestions, draft.isEmpty, !model.isReplying, !model.suggestions.isEmpty, availability.isAvailable {
                SuggestionChips(suggestions: model.suggestions) { model.send($0) }
            }
            ComposerView(
                text: $draft,
                isFocused: $isComposerFocused,
                isEnabled: availability.isAvailable,
                isReplying: model.isReplying,
                onSend: send,
                onStop: { model.stop() }
            )
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .padding(.top, 4)
        .frame(maxWidth: Theme.contentMaxWidth)
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: model.suggestions)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 8) {
                PalAvatar(pal: pal, size: 28)
                Text(pal.name ?? "Chat").font(.headline).lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { showEditor = true } label: {
                    Label("Edit Pal", systemImage: "pencil")
                }
                if let palId = pal.id {
                    ShareLink(
                        item: ConversationExport(palId: palId, palName: pal.name ?? "Pal"),
                        preview: SharePreview("Conversation with \(pal.name ?? "Pal")")
                    ) {
                        Label("Export Conversation", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.items.isEmpty)
                }
                Button(role: .destructive) { showClearConfirmation = true } label: {
                    Label("Clear Conversation", systemImage: "trash")
                }
                .disabled(model.items.isEmpty)
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("More")
        }
    }

    // MARK: Actions

    private func send() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = draft
        draft = ""
        model.send(text)
    }

    private func loadOlder() async {
        if let anchorId = await model.loadOlder() {
            position.scrollTo(id: anchorId, anchor: .top)
        }
    }

    private func scrollToBottom(animated: Bool) {
        if animated {
            withAnimation(.snappy) { position.scrollTo(edge: .bottom) }
        } else {
            position.scrollTo(edge: .bottom)
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(pal: PersistenceController.preview.samplePal)
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    .environment(ModelAvailability())
}
