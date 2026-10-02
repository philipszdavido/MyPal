import SwiftUI

struct SettingsView: View {
    @Environment(ModelAvailability.self) private var availability
    @State private var showClearAll = false

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section("Pals") {
                NavigationLink {
                    ManagePalsView()
                } label: {
                    Label("Manage Pals", systemImage: "person.2")
                }
            }

            Section {
                AvailabilityBanner(availability: availability)
            } header: {
                Text("Apple Intelligence")
            } footer: {
                Text("Conversations are generated and stored on this device. Nothing is sent to a server.")
            }

            Section("Data") {
                Button("Delete All Conversations", role: .destructive) { showClearAll = true }
            }

            Section("About") {
                LabeledContent("Version", value: versionString)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete all conversations?", isPresented: $showClearAll, titleVisibility: .visible) {
            Button("Delete All Conversations", role: .destructive) {
                Task { await PalActions.clearAllConversations() }
            }
        } message: {
            Text("Messages with every pal will be deleted. Your pals are kept. This can't be undone.")
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(ModelAvailability())
}
