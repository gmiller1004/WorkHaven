//
//  WorkHavenApp.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import CoreData

@main
struct WorkHavenApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var dataImporter: DataImporter

    init() {
        self._dataImporter = StateObject(wrappedValue: DataImporter(context: PersistenceController.shared.container.viewContext))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    checkAndImportData()
                }
        }
    }
    
    private func checkAndImportData() {
        // Check if we already have spots in the database
        let fetchRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
        fetchRequest.fetchLimit = 1
        
        do {
            let existingSpots = try persistenceController.container.viewContext.fetch(fetchRequest)
            
            // If no spots exist, import the Boise work spaces
            if existingSpots.isEmpty {
                Task {
                    await dataImporter.importBoiseWorkSpaces()
                }
            }
        } catch {
            print("Error checking for existing spots: \(error)")
        }
    }
}
