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
    
    @FetchRequest(sortDescriptors: [
        SortDescriptor(\.timestamp, order: .forward)
    ], animation: .default)
    var messages: FetchedResults<Message>
    
    let openAIViewModel = OpenAIViewModel.shared;
    let coreDataUtils = CoreDataUtils.shared;
    let session = LanguageModelSession()
    let options = GenerationOptions(temperature: 2.0)
    let model = SystemLanguageModel.default
    
    var pal: Pal

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
                    Text("AI Check: ")
                    switch model.availability {
                    case .available:
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                    case .unavailable(_):
                        Image(systemName: "xmark").foregroundStyle(.red)
                    }
                }.padding(.horizontal)

            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        
    }

    func sendMessage() {
        
        guard !inputText.isEmpty else { return }

        coreDataUtils.insertResponse(reply: inputText)

        Task {

            let response = try await session.respond(to: inputText, options: options)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                coreDataUtils.insertAsAiResponse(reply: response.content)
            }
            
        }

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
