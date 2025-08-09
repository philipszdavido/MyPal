//
//  AddNewPalView.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 09/08/2025.
//

import SwiftUI

struct AddNewPalView: View {
    
    @Environment(\.managedObjectContext) var managedObjectContext
    @Environment(\.dismiss) var dismiss;

    @State var name = ""
    @State var instruction = ""
    
    var body: some View {
        
        VStack(alignment: .leading) {
            
            VStack(alignment: .leading) {
                
                Text("Name")
                
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.vertical)
                
            }.padding()

            VStack(alignment: .leading) {
                
                Text("Instruction")
                
                TextEditor(text: $instruction)
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
                        
                        let pal = Pal(context: managedObjectContext);
                        pal.instruction = instruction;
                        pal.name = name;
                        
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
    AddNewPalView()
}
