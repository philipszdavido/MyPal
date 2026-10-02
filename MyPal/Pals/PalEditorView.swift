import SwiftUI
import CoreData

struct PalEditorView: View {
    enum Mode {
        case create
        case edit(Pal)
    }

    private enum Field { case name, instruction }

    static let instructionLimit = 1200

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var name: String
    @State private var instruction: String
    @State private var errorMessage: String?
    @State private var showClearConfirmation = false
    @State private var showDeleteConfirmation = false
    @FocusState private var focusedField: Field?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _instruction = State(initialValue: "")
        case .edit(let pal):
            _name = State(initialValue: pal.name ?? "")
            _instruction = State(initialValue: pal.instruction ?? "")
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
        }
        return !trimmedName.isEmpty || !instruction.isEmpty
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

            if existingPal != nil {
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
            guard existingPal == nil else { return }
            try? await Task.sleep(for: .milliseconds(400))
            focusedField = .name
        }
        .confirmationDialog("Clear conversation?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear Conversation", role: .destructive) {
                guard let pal = existingPal else { return }
                Task { await PalActions.clearMessages(of: pal) }
            }
        } message: {
            Text("All messages with this pal will be deleted. This can't be undone.")
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

        do {
            try context.save()
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
