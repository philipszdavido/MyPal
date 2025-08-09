//
//  Settings.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 09/08/2025.
//

import Foundation

class Settings: ObservableObject {
    
    let coreDataUtils = CoreDataUtils.shared
    
    static var isDarkModeEnabled: Bool = false
    
    var myPals : [(name: String, instruction: String)] {

        let pals: [(name: String, instruction: String)] = [
            (name: "Hobbies Pal", instruction: """
                Suggest related topics. Keep them concise (three to seven words) and \
                    make sure they build naturally from the person's topic.
            """),
            (name: "Movie Critic", instruction: "You are a movie critic"),
            (name: "Music Critic", instruction: "You are a music critic"),
            (name: "Mentor", instruction: "You are a mentor")
        ]
                        
        return pals;

    }
    
    init() {
     for pal in myPals {
         coreDataUtils.insertPal(name: pal.name, instruction: pal.instruction)
        }
    }
    
}
