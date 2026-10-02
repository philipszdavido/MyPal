//
//  MyPalApp.swift
//  MyPal
//

import SwiftUI

@main
struct MyPalApp: App {
    private let persistence = PersistenceController.shared

    @State private var availability = ModelAvailability()
    @State private var showStoreError = PersistenceController.shared.loadError != nil
    @Environment(\.scenePhase) private var scenePhase

    init() {
        PalSeeder.run(in: PersistenceController.shared.viewContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistence.viewContext)
                .environment(availability)
                .alert("Couldn't open your data", isPresented: $showStoreError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("MyPal is running with temporary storage, so changes made now won't be kept. Your saved data hasn't been modified. Please restart the app.")
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { availability.refresh() }
        }
    }
}
