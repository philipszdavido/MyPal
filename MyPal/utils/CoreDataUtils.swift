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
    let entities = ["Pal"]

    func insertResponse(reply: String, palId: String) {
        let response = Message(context: managedObjectContext)
        response.id = UUID()
        response.content = reply
        response.isAi = false
        response.timestamp = .now
        
        response.palId = palId
        
        do {
            try managedObjectContext.save()
        } catch {
            print("Core Data Save Error: \(error)")
        }
    }
    
    func insertAsAiResponse(reply: String, palId: String) {
        let response = Message(context: managedObjectContext)
        response.id = UUID()
        response.content = reply
        response.isAi = true
        response.timestamp = .now
        response.palId = palId

        do {
            try managedObjectContext.save()
        } catch {
            print("Core Data Save Error: \(error)")
        }
    }
    
    func streamAiMessage(palId: String) -> Message {
        
        let response = Message(context: managedObjectContext)
        response.id = UUID()
        response.content = ""
        response.isAi = true
        response.timestamp = .now
        response.palId = palId
        response.isPartial = true

        do {
            try managedObjectContext.save()
        } catch {
            print("Core Data Save Error: \(error)")
        }
        
        return response
    }
    
    func insertPal(name: String, instruction: String) {
        
        // check for name in Pal core data
        // if it exists then update dont add

        let fetchRequest: NSFetchRequest<Pal> = Pal.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)

        do {
            
            let existing = try managedObjectContext.fetch(fetchRequest)
            
            if existing.isEmpty {
                
                let pal = Pal(context: managedObjectContext)
                pal.name = name
                pal.instruction = instruction
                pal.id = UUID()
                pal.timestamp = Date()
                
            }

        } catch {}
    }
    
    func deleteMessage(id: UUID) {
        
        let fetchRequest: NSFetchRequest<Message> = Message.fetchRequest()
        
        fetchRequest.predicate = NSPredicate(
            format: "id == %@",
            id as CVarArg
        )
        
        do {
            
            let existing = try managedObjectContext.fetch(fetchRequest)
            
            for message in existing {
                
                managedObjectContext.delete(message)
                
            }
            
            try managedObjectContext.save();

        } catch {

            print("Error deleting: \(error)")

        }
        
    }
    
    func clearPalMessage(pal: Pal) {

        Task {
            let fetchRequest: NSFetchRequest<Message> = Message.fetchRequest()
            
            if let palId = pal.id?.uuidString {
                fetchRequest.predicate = NSPredicate(
                    format: "palId == %@",
                    palId
                )
            }
            
            do {
                
                let existing = try managedObjectContext.fetch(fetchRequest)
                
                for message in existing {
                    managedObjectContext.delete(message)
                }
                
            } catch {
                print("Error deleting \(error)")
            }
        }

    }
    
    func deleteAll(entityName: String) {

        let context: NSManagedObjectContext = managedObjectContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)

        do {
            let results = try context.fetch(fetchRequest)
            for object in results as! [NSManagedObject] {
                context.delete(object)
            }
            try context.save()
            print("All \(entityName) objects deleted.")
        } catch {
            print("Error deleting \(entityName): \(error)")
        }
    }
    
}
