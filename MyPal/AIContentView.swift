//
//  AIContentView.swift
//  MyBuddy
//
//  Created by Chidume Nnamdi on 13/07/2025.
//

import SwiftUI

struct AIContentView: View {
    var body: some View {
        TabView {
            
            Tab("My Pals", systemImage: "message") {
                MyPalsView()
            }
            
            Tab("Check-in", systemImage: "sun.max") {
                CheckInView()
            }
            
            Tab("Reminders", systemImage: "clock") {
                ReminderView()
            }
            
            Tab("Reflect", systemImage: "brain.head.profile") {
                DiscussionView()
            }
            
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
            
        }
    }
}

#Preview {
    NavigationStack {
        AIContentView()
    }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
