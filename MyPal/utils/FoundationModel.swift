//
//  FoundationModel.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 09/08/2025.
//

import Foundation
import FoundationModels

class FoundationModel: ObservableObject {

    static let shared = FoundationModel()

    let coreDataUtils = CoreDataUtils.shared;
    
    var model: SystemLanguageModel {
        return SystemLanguageModel.default
    }
    
    var options: GenerationOptions {
        return GenerationOptions(temperature: 2.0)
    }

    func sendMessage(to inputText: String, instruction: String?, palId: String?) {

        let options = GenerationOptions(temperature: 2.0)

        coreDataUtils.insertResponse(reply: inputText, palId: palId!)

        Task {

            let session = LanguageModelSession(instructions: instruction)

            let response = try await session.respond(to: inputText, options: options)
            
            self.coreDataUtils.insertAsAiResponse(reply: response.content, palId: palId!)
                        
        }

    }
    
    func sendMessage(_ content: String, instruction: String?, palId: String?) {
        
        coreDataUtils.insertResponse(reply: content, palId: palId!)
        
        Task {
            
            do {
                
                let session = LanguageModelSession(instructions: instruction)
                
                let stream = session.streamResponse(to: content)
                
                let message = coreDataUtils.streamAiMessage(palId: palId ?? "")
                
                for try await response in stream {
                                        
                    message.content = response.content
                    
                }
                
                message.isPartial = false
                                
                // try coreDataUtils.managedObjectContext.save()
                
            } catch {
                
                
            }
            
        }
        
    }
    
}
