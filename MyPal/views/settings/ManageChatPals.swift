//
//  ManageChatBots.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 09/08/2025.
//

import SwiftUI

struct ManageChatPals: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext

    @FetchRequest(sortDescriptors: [
        SortDescriptor(\.timestamp, order: .forward)
    ], animation: .default)
    var pals: FetchedResults<Pal>
    
    @State private var showNewPalView = false
    
    var body: some View {
        
        List (pals) { pal in
            
            NavigationLink(destination: ManagePalView(pal: pal)) {
                Text(pal.name ?? "Unknown")
            }
            
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                                
                Button {
                    showNewPalView = true
                } label: {
                    Image(systemName: "plus.app.fill")
                }

            }
        }
        .navigationDestination(isPresented: $showNewPalView) {
            AddNewPalView()
        }
        
    }
}

#Preview {
    
    NavigationStack {
        
        ManageChatPals()
    }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)

}
