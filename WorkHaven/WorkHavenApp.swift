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
    @State private var hasCheckedForData = false
    
    // Static flag to prevent multiple imports across app launches
    private static var hasImportedData = false

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
            if !hasCheckedForData && !Self.hasImportedData {
                hasCheckedForData = true
                Self.hasImportedData = true
                print("🚀 App launched - checking for data...")
                checkAndImportData()
                Task {
                    // Add a small delay to ensure import completes before CloudKit sync
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    await cloudKitManager.syncWithCloudKit()
                }
            } else {
                print("⚠️ App onAppear called again - skipping data check (hasCheckedForData: \(hasCheckedForData), hasImportedData: \(Self.hasImportedData))")
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
                print("📊 No spots found in database, importing Boise work spaces...")
                Task {
                    await dataImporter.importBoiseWorkSpaces()
                }
            } else {
                print("📊 Found existing spots, skipping import")
            }
        } catch {
            print("Error checking for existing spots: \(error)")
        }
    }
}
