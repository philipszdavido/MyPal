import SwiftUI
import CoreData

struct PalsListView: View {
    @FetchRequest private var pals: FetchedResults<Pal>
    @Environment(ModelAvailability.self) private var availability

    @State private var searchText = ""
    @State private var showNewPal = false
    @State private var palToEdit: Pal?
    @State private var palToDelete: Pal?
    @State private var palToClear: Pal?

    init() {
        let request = Pal.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Pal.timestamp, ascending: true)]
        request.fetchBatchSize = 40
        _pals = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        List {
            if !availability.isAvailable {
                Section { AvailabilityBanner(availability: availability) }
            }

            Section {
                ForEach(pals) { pal in
                    NavigationLink(value: pal) {
                        PalRow(pal: pal)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { palToDelete = pal } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { palToClear = pal } label: {
                            Label("Clear", systemImage: "eraser")
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button { palToEdit = pal } label: { Label("Edit", systemImage: "pencil") }
                        Button { palToClear = pal } label: { Label("Clear Conversation", systemImage: "eraser") }
                        Button(role: .destructive) { palToDelete = pal } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .navigationTitle("My Pals")
        .navigationDestination(for: Pal.self) { ChatView(pal: $0) }
        .searchable(text: $searchText, prompt: "Search pals")
        .onChange(of: searchText) { _, newValue in
            let query = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            pals.nsPredicate = query.isEmpty
                ? nil
                : NSPredicate(format: "name CONTAINS[cd] %@ OR instruction CONTAINS[cd] %@", query, query)
        }
        .overlay {
            if pals.isEmpty {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Pals Yet", systemImage: "person.2")
                    } description: {
                        Text("Create a pal with its own personality to start chatting.")
                    } actions: {
                        Button("Create a Pal") { showNewPal = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNewPal = true } label: {
                    Label("New Pal", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewPal) {
            NavigationStack { PalEditorView(mode: .create) }
        }
        .sheet(item: $palToEdit) { pal in
            NavigationStack { PalEditorView(mode: .edit(pal)) }
        }
        .confirmPalDeletion($palToDelete)
        .confirmPalClear($palToClear)
    }
}

#Preview {
    NavigationStack { PalsListView() }
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        .environment(ModelAvailability())
}
