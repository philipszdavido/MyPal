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
    
    @EnvironmentObject var settings: Settings;
    @State var searchText: String = ""
    
    var body: some View {
        
        List {

            ForEach (pals) { pal in
                NavigationLink {
                    AIChatView(pal: pal)
                } label: {
                    Text(pal.name ?? "")
                }
            }
            
        }
        .navigationTitle(Text("My Pals"))
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                
                HStack {
                    Text("AI Check: ")
                    GenerativeView()
                }.padding(.horizontal)

            }
        }
        
    }

}

#Preview {
    NavigationStack {
        MyPalsView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(Settings())
}
