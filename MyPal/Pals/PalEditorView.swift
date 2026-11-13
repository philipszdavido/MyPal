import SwiftUI
import CoreData

struct PalEditorView: View {
    enum Mode {
        case create
        case edit(Pal)
    }

    private enum Field { case name, instruction, emoji, newFact }

    static let instructionLimit = 1200

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var name: String
    @State private var instruction: String
    @State private var emoji: String
    @State private var color: PalColor?
    @State private var newFact = ""
    @State private var errorMessage: String?
    @State private var showClearConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showForgetConfirmation = false
    @State private var memory = PalMemory()
    @FocusState private var focusedField: Field?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _instruction = State(initialValue: "")
            _emoji = State(initialValue: "")
            _color = State(initialValue: nil)
        case .edit(let pal):
            _name = State(initialValue: pal.name ?? "")
            _instruction = State(initialValue: pal.instruction ?? "")
            _emoji = State(initialValue: pal.emoji ?? "")
            _color = State(initialValue: pal.colorName.flatMap(PalColor.init(rawValue:)))
        }
    }

    private var existingPal: Pal? {
        if case .edit(let pal) = mode { return pal }
        return nil
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { !trimmedName.isEmpty }

    private var hasChanges: Bool {
        if let pal = existingPal {
            return trimmedName != (pal.name ?? "") || instruction != (pal.instruction ?? "")
                || emoji != (pal.emoji ?? "") || color?.rawValue != pal.colorName
        }
        return !trimmedName.isEmpty || !instruction.isEmpty || !emoji.isEmpty || color != nil
    }

    private var resolvedColor: PalColor { color ?? PalColor.resolve(nil, fallbackFor: trimmedName) }

    private var appearanceSection: some View {
        Section {
            HStack(spacing: 16) {
                PalAvatar(name: trimmedName, emoji: emoji, color: resolvedColor.color, size: 64)
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Emoji (optional)", text: $emoji)
                        .focused($focusedField, equals: .emoji)
                        .font(.title3)
                    Text("Shown instead of initials.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(PalColor.allCases) { option in
                        Button { color = option } label: {
                            Circle()
                                .fill(option.color.gradient)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if option == resolvedColor {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.rawValue.capitalized)
                        .accessibilityAddTraits(option == resolvedColor ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        } header: {
            Text("Appearance")
        }
    }

    @ViewBuilder
    private var memorySection: some View {
        Section {
            if memory.isEmpty {
                Text("Nothing yet. As you chat, this pal remembers what matters and brings it up later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(memory.pinnedFacts, id: \.self) { fact in
                Label(fact, systemImage: "pin.fill")
                    .font(.subheadline)
            }
            .onDelete { offsets in
                let facts = offsets.map { memory.pinnedFacts[$0] }
                editMemory { memory in memory.pinnedFacts.removeAll { facts.contains($0) } }
            }
            ForEach(memory.facts, id: \.self) { fact in
                Label(fact, systemImage: "sparkle")
                    .font(.subheadline)
            }
            .onDelete { offsets in
                let facts = offsets.map { memory.facts[$0] }
                editMemory { memory in memory.facts.removeAll { facts.contains($0) } }
            }
            HStack {
                TextField("Add something to remember", text: $newFact)
                    .focused($focusedField, equals: .newFact)
                    .submitLabel(.done)
                    .onSubmit(addFact)
                if !newFact.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: addFact)
                }
            }
            if !memory.summary.isEmpty {
                Text(memory.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if !memory.isEmpty {
                Button("Forget What This Pal Knows", role: .destructive) {
                    showForgetConfirmation = true
                }
            }
        } header: {
            Text("Memory")
        } footer: {
            Text("Pinned facts are kept until you remove them; swipe to delete any fact. Memory is built on your device and never leaves it.")
        }
    }

    private func addFact() {
        let fact = newFact
        newFact = ""
        editMemory { _ = $0.pin(fact) }
    }

    private func editMemory(_ change: @escaping @Sendable (inout PalMemory) -> Void) {
        guard let id = existingPal?.id else { return }
        Task { memory = await PalActions.editMemory(palId: id, change) }
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .instruction }
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Name")
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }

            Section {
                TextEditor(text: $instruction)
                    .focused($focusedField, equals: .instruction)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
            } header: {
                Text("Instructions")
            } footer: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Describe who this pal is and how it should respond.")
                    Spacer()
                    Text("\(instruction.count)/\(Self.instructionLimit)").monospacedDigit()
                }
            }

            appearanceSection

            if existingPal != nil {
                memorySection

                Section {
                    Button("Clear Conversation", role: .destructive) { showClearConfirmation = true }
                    Button("Delete Pal", role: .destructive) { showDeleteConfirmation = true }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(existingPal == nil ? "New Pal" : "Edit Pal")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(hasChanges)
        .onChange(of: instruction) { _, newValue in
            if newValue.count > Self.instructionLimit {
                instruction = String(newValue.prefix(Self.instructionLimit))
            }
        }
        .onChange(of: name) { _, _ in errorMessage = nil }
        .onChange(of: emoji) { _, newValue in
            // Keep a single emoji (the last one typed); drop anything that isn't one.
            let last = newValue.last.map(String.init) ?? ""
            let cleaned = last.unicodeScalars.contains { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && last.unicodeScalars.count > 1) } ? last : ""
            if cleaned != newValue { emoji = cleaned }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(!isValid)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .task {
            if let id = existingPal?.id {
                memory = await MemoryStore.shared.load(id)
            }
        }
        .task {
            guard existingPal == nil else { return }
            try? await Task.sleep(for: .milliseconds(400))
            focusedField = .name
        }
        .confirmationDialog("Forget what this pal knows?", isPresented: $showForgetConfirmation, titleVisibility: .visible) {
            Button("Forget Memory", role: .destructive) {
                guard let pal = existingPal else { return }
                memory = PalMemory()
                Task { await PalActions.forgetMemory(of: pal) }
            }
        } message: {
            Text("Your messages stay, but the pal will no longer remember facts from earlier conversations.")
        }
        .confirmationDialog("Clear conversation?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear Conversation", role: .destructive) {
                guard let pal = existingPal else { return }
                Task { await PalActions.clearMessages(of: pal) }
            }
        } message: {
            Text("All messages and this pal's memory will be deleted. This can't be undone.")
        }
        .confirmationDialog("Delete this pal?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Pal", role: .destructive) {
                guard let pal = existingPal else { return }
                dismiss()
                Task { await PalActions.delete(pal) }
            }
        } message: {
            Text("Its conversation will be deleted too. This can't be undone.")
        }
    }

    private func save() {
        guard isValid else { return }
        if nameIsTaken(trimmedName) {
            errorMessage = "You already have a pal named \u{201C}\(trimmedName)\u{201D}."
            focusedField = .name
            return
        }

        let pal: Pal
        if let existingPal {
            pal = existingPal
        } else {
            pal = Pal(context: context)
            pal.id = UUID()
            pal.timestamp = Date.now
        }
        pal.name = trimmedName
        pal.instruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        pal.emoji = emoji.isEmpty ? nil : emoji
        pal.colorName = color?.rawValue

        do {
            try context.save()
            MyPalShortcuts.updateAppShortcutParameters()
            dismiss()
        } catch {
            Log.data.error("Pal save failed: \(error.localizedDescription)")
            context.rollback()
            errorMessage = "Couldn't save this pal. Please try again."
        }
    }

    private func nameIsTaken(_ candidate: String) -> Bool {
        let request = Pal.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", candidate)
        let matches = (try? context.fetch(request)) ?? []
        return matches.contains { $0 !== existingPal }
    }
}

#Preview {
    NavigationStack { PalEditorView(mode: .create) }
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
