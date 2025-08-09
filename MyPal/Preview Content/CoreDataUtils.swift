//
//  CoreDataUtils.swift
//  MyPal
//
//  Created by Chidume Nnamdi on 05/08/2025.
//

import Foundation
import CoreData

class CoreDataUtils {
    
    static let shared = CoreDataUtils()
    let managedObjectContext = PersistenceController.shared.container.viewContext

    func insertResponse(reply: String) {
        let response = Message(context: managedObjectContext)
        response.id = UUID()
        response.content = reply
        response.isAi = false
        response.timestamp = .now
        
        do {
            try managedObjectContext.save()
        } catch {
            print("Core Data Save Error: \(error)")
        }
    }
    
    func insertAsAiResponse(reply: String) {
        let response = Message(context: managedObjectContext)
        response.id = UUID()
        response.content = reply
        response.isAi = true
        response.timestamp = .now

        do {
            try managedObjectContext.save()
        } catch {
            print("Core Data Save Error: \(error)")
        }
    }
}
