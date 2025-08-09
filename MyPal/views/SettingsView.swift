//
//  SettingsView.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 09/08/2025.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        
        List {
            NavigationLink {
                ManageChatPals()
            } label: {
                Text("Add Chat Pals")
            }

        }.navigationTitle(Text("Settings"))
        
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    } .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
