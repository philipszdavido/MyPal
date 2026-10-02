import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("My Pals", systemImage: "message") {
                NavigationStack { PalsListView() }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack { SettingsView() }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        .environment(ModelAvailability())
}
