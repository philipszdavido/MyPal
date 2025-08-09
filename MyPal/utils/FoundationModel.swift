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
    let options = GenerationOptions(temperature: 2.0)
    let model = SystemLanguageModel.default
    
    func sendMessage(to inputText: String, instruction: String?, palId: String?) {
        
        coreDataUtils.insertResponse(reply: inputText, palId: palId!)

        Task {

            let session = LanguageModelSession(instructions: instruction)

            let response = try await session.respond(to: inputText, options: options)

            //DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            
            self.coreDataUtils.insertAsAiResponse(reply: response.content, palId: palId!)
            
            //}
            
        }

    }
    
}
