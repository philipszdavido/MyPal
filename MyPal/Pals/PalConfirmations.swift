import SwiftUI

private struct PalDeleteConfirmation: ViewModifier {
    @Binding var pal: Pal?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete \u{201C}\(pal?.name ?? "Pal")\u{201D}?",
            isPresented: Binding(get: { pal != nil }, set: { if !$0 { pal = nil } }),
            titleVisibility: .visible,
            presenting: pal
        ) { target in
            Button("Delete Pal", role: .destructive) {
                Task { await PalActions.delete(target) }
            }
        } message: { _ in
            Text("Its conversation will be deleted too. This can't be undone.")
        }
    }
}

private struct PalClearConfirmation: ViewModifier {
    @Binding var pal: Pal?

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Clear conversation?",
            isPresented: Binding(get: { pal != nil }, set: { if !$0 { pal = nil } }),
            titleVisibility: .visible,
            presenting: pal
        ) { target in
            Button("Clear Conversation", role: .destructive) {
                Task { await PalActions.clearMessages(of: target) }
            }
        } message: { target in
            Text("All messages with \(target.name ?? "this pal") and its memory will be deleted. This can't be undone.")
        }
    }
}

extension View {
    func confirmPalDeletion(_ pal: Binding<Pal?>) -> some View {
        modifier(PalDeleteConfirmation(pal: pal))
    }

    func confirmPalClear(_ pal: Binding<Pal?>) -> some View {
        modifier(PalClearConfirmation(pal: pal))
    }
}
