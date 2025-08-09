//
//  MyPalsView.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 09/08/2025.
//

import SwiftUI

struct MyPalsView: View {
        
    @FetchRequest(sortDescriptors: [
        SortDescriptor(\.timestamp, order: .forward)
    ], animation: .default)
    var pals: FetchedResults<Pal>

    var body: some View {
        
        List(pals) { pal in

            NavigationLink {
                AIChatView(pal: pal)
            } label: {
                Text(pal.name ?? "")
            }
            
        }
        .navigationTitle(Text("My Pals"))
        
    }
}

#Preview {
    NavigationStack {
        MyPalsView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
