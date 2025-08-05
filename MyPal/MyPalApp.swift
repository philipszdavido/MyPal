//
//  MyPalApp.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 05/08/2025.
//

import SwiftUI

@main
struct MyPalApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
