import SwiftUI
import CoreData

struct ManagePalsView: View {
    @FetchRequest private var pals: FetchedResults<Pal>

    @State private var showNewPal = false
    @State private var palToEdit: Pal?
    @State private var palToDelete: Pal?

    init() {
        let request = Pal.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Pal.timestamp, ascending: true)]
        request.fetchBatchSize = 40
        _pals = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        List {
            ForEach(pals) { pal in
                Button { palToEdit = pal } label: {
                    HStack(spacing: 12) {
                        PalAvatar(pal: pal, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pal.name ?? "Untitled").font(.body).foregroundStyle(.primary)
                            if let instruction = pal.instruction, !instruction.isEmpty {
                                Text(instruction).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { palToDelete = pal } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Manage Pals")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if pals.isEmpty {
                ContentUnavailableView("No Pals", systemImage: "person.2", description: Text("Tap + to create your first pal."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewPal = true } label: { Label("New Pal", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $showNewPal) {
            NavigationStack { PalEditorView(mode: .create) }
        }
        .sheet(item: $palToEdit) { pal in
            NavigationStack { PalEditorView(mode: .edit(pal)) }
        }
        .confirmPalDeletion($palToDelete)
    }
}

#Preview {
    NavigationStack { ManagePalsView() }
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
