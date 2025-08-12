//
//  MessageItemView.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 10/08/2025.
//

import SwiftUI

struct MessageItemView: View {
    
    @ObservedObject var message: Message;
    
    let coreDataUtils = CoreDataUtils.shared;
    let parser = MarkdownParser.shared

    var body: some View {
        
        HStack {

            if message.isAi == false { Spacer() }

            if let content = message.content {
                
                parser.parse(text: content).enumerated().reduce(Text("")) { result, pair in
                    
                    let (_, markdownToken) = pair
                    
                    let textPart = markdownToken.type == .bold ? Text(markdownToken.value).bold() : Text(
                        markdownToken.value
                    )
                    
                    return result + textPart;
                    
                }
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
        .opacity(message.isPartial ? 0.85 : 1.0)
        .animation(.smooth(duration: 0.4), value: message.isPartial)
        .scaleEffect(message.isPartial ? 0.98 : 1.0)
        .animation(.smooth(duration: 0.3), value: message.isPartial)
        
        .contextMenu {
            Button(action: {
                
                if let id = message.id {
                    coreDataUtils.deleteMessage(id: id)
                }
                
            }) {
                HStack {
                    Text("Delete")
                    Image(systemName: "trash")
                }
            }
        }

    }
}

#Preview {
    MessageItemView(
        message: Message(
            context: PersistenceController.preview.container.viewContext
        )
    )
}
