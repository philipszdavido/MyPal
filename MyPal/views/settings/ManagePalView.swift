//
//  ManagePalView.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 09/08/2025.
//

import SwiftUI

struct ManagePalView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext
    @Environment(\.dismiss) var dismiss;
    
    let coreDataUtils = CoreDataUtils.shared

    @ObservedObject var pal: Pal

    var body: some View {
        
        VStack(alignment: .leading) {
            
            VStack(alignment: .leading) {
                
                Text("Name")
                
                TextField("Name", text: Binding(get: {
                    pal.name ?? ""
                }, set: { value in
                    pal.name = value
                }))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.vertical)
                
            }.padding()

            VStack(alignment: .leading) {
                
                Text("Instruction")
                
                TextEditor(text: Binding(get: {
                    pal.instruction ?? ""
                }, set: { value in
                    pal.instruction = value
                }))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(height: 100)
                    .cornerRadius(8)
                    .border(Color.gray, width: 1)
                
                
            }.padding()
            
            Spacer()

        }.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                
                HStack {

                    Button {
                        managedObjectContext.delete(pal)
                        dismiss()
                    } label: {
                        Text("Delete").foregroundStyle(.red)
                    }

                    Button {
                        coreDataUtils.clearPalMessage(pal: pal)
                        dismiss()
                    } label: {
                        Text("Delete Messages").foregroundStyle(.red)
                    }

                    Button {
                        try? managedObjectContext.save()
                        dismiss()
                    } label: {
                        Text("Save")
                    }
                    
                }
                
            }
        }
        
    }
}

#Preview {
    NavigationView {
        ManagePalView(pal: Pal(context: PersistenceController.preview.container.viewContext))
    }.environment(
        \.managedObjectContext,
         PersistenceController.preview.container.viewContext)
}
