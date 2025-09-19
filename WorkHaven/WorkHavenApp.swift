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
    @StateObject private var cloudKitManager: CloudKitManager
    @StateObject private var notificationManager: NotificationManager

    init() {
        let context = PersistenceController.shared.container.viewContext
        self._dataImporter = StateObject(wrappedValue: DataImporter(context: context))
        self._cloudKitManager = StateObject(wrappedValue: CloudKitManager(context: context))
        self._notificationManager = StateObject(wrappedValue: NotificationManager(context: context))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        .onAppear {
            checkAndImportData()
            Task {
                await cloudKitManager.syncWithCloudKit()
            }
        }
        }
    }
    
    private func checkAndImportData() {
        // Connect notification manager to data importer
        dataImporter.setNotificationManager(notificationManager)
        
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
