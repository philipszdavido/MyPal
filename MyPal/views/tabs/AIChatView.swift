//
//  ChatView.swift
//  MyBuddy
//
//  Created by Chidume Nnamdi on 26/06/2025.
//

import SwiftUI
import FoundationModels

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}

struct AIChatView: View {

    @State private var inputText = "";
    
    @FetchRequest private var messages: FetchedResults<Message>
    
    let foundationModel = FoundationModel.shared
    let coreDataUtils = CoreDataUtils.shared

    var pal: Pal;

    var body: some View {
        
        ScrollViewReader { proxy in
            
            ScrollView {
                
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageItemView(message: message)
                    }
                }
            }
            .onChange(of: messages.count) { _ in
                withAnimation {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            
        }.onTapGesture {
            UIApplication.shared.endEditing()
        }
        
        Divider()
        HStack(spacing: 12) {
            TextField("Type a message", text: $inputText)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(20)
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .navigationTitle("Chat")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                
                HStack {
                    Text(pal.name ?? "")
                    
                    Button {
                        coreDataUtils.deleteAll(entityName: "Pal")
                    } label: {
                        Text("Delete")
                    }
                    
                }.padding(.horizontal)

            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        
    }
    
    init(pal: Pal) {
        
        self.pal = pal
        
        var predicate: NSPredicate? = nil
        
        if let id = pal.id?.uuidString {
            
            predicate = NSPredicate(format: "palId == %@", id)
        }
        
        _messages = FetchRequest<Message>(
            entity: Message.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Message.timestamp, ascending: true)],
            predicate: predicate
        )
        
    }

    func sendMessage() {
        
        guard !inputText.isEmpty else { return }

        foundationModel
            .sendMessage(
                to: inputText,
                instruction: pal.instruction ?? "",
                palId: pal.id?.uuidString
            )

        inputText = "";
        
    }
}

#Preview {
    NavigationStack {
        AIChatView(pal: Pal())
    }
        .environment(
            \.managedObjectContext,
             PersistenceController.preview.container.viewContext)
}


struct MessageItemView: View {
    
    @ObservedObject var message: Message;
    
    var body: some View {
        HStack {

            if message.isAi == false { Spacer() }

            if let content = message.content {
                Text(content)
                    .padding()
                    .background(message.isAi ? Color.gray.opacity(0.5) : Color.blue )
                    .cornerRadius(16)
                    .frame(alignment: message.isAi ? .trailing : .leading)
                    .foregroundStyle(.white)
            }
            
            if message.isAi == true { Spacer() }
            
        }
        .padding(.horizontal)
        .id(message.id)

    }
}
