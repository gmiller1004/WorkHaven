//
//  wipe_database.swift
//  WorkHaven
//
//  Database wipe utility for starting fresh
//  Run this in Xcode console or add as a debug function
//

import Foundation
import CoreData
import CloudKit

// MARK: - Database Wipe Utility

class DatabaseWipeUtility {
    static let shared = DatabaseWipeUtility()
    
    private init() {}
    
    /// Wipe all local Core Data and CloudKit data
    func wipeEverything() async {
        print("🗑️ Starting complete database wipe...")
        
        // 1. Wipe local Core Data
        await wipeLocalData()
        
        // 2. Wipe CloudKit data
        await wipeCloudKitData()
        
        print("✅ Database wipe completed!")
    }
    
    /// Wipe only local Core Data
    func wipeLocalData() async {
        print("🗑️ Wiping local Core Data...")
        
        let context = PersistenceController.shared.container.viewContext
        
        // Delete all Spot entities
        let spotFetchRequest: NSFetchRequest<NSFetchRequestResult> = Spot.fetchRequest()
        let spotDeleteRequest = NSBatchDeleteRequest(fetchRequest: spotFetchRequest)
        
        // Delete all UserRating entities
        let ratingFetchRequest: NSFetchRequest<NSFetchRequestResult> = UserRating.fetchRequest()
        let ratingDeleteRequest = NSBatchDeleteRequest(fetchRequest: ratingFetchRequest)
        
        do {
            try context.execute(spotDeleteRequest)
            try context.execute(ratingDeleteRequest)
            try context.save()
            print("✅ Local Core Data wiped successfully")
        } catch {
            print("❌ Error wiping local data: \(error)")
        }
    }
    
    /// Wipe CloudKit data
    func wipeCloudKitData() async {
        print("🗑️ Wiping CloudKit data...")
        
        let container = CKContainer.default()
        let privateDatabase = container.privateCloudDatabase
        
        do {
            // Check CloudKit availability
            let status = try await container.accountStatus()
            guard status == .available else {
                print("⚠️ CloudKit not available, skipping CloudKit wipe")
                return
            }
            
            // Query all Spot records
            let query = CKQuery(recordType: "Spot", predicate: NSPredicate(format: "name != ''"))
            let results = try await privateDatabase.records(matching: query)
            
            print("📊 Found \(results.matchResults.count) CloudKit records to delete")
            
            // Delete records in batches
            let recordIDs = results.matchResults.compactMap { (_, result) -> CKRecord.ID? in
                switch result {
                case .success(let record):
                    return record.recordID
                case .failure(let error):
                    print("⚠️ Error fetching record for deletion: \(error)")
                    return nil
                }
            }
            
            if !recordIDs.isEmpty {
                let batchSize = 10
                for i in stride(from: 0, to: recordIDs.count, by: batchSize) {
                    let batch = Array(recordIDs[i..<min(i + batchSize, recordIDs.count)])
                    
                    try await privateDatabase.modifyRecords(saving: [], deleting: batch)
                    print("✅ Deleted batch of \(batch.count) records")
                    
                    // Small delay between batches
                    try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
                
                print("✅ Successfully cleared all CloudKit records")
            } else {
                print("ℹ️ No CloudKit records found to delete")
            }
            
        } catch {
            print("❌ Error wiping CloudKit data: \(error)")
        }
    }
}

// MARK: - Usage Instructions

/*
 To use this utility:
 
 1. In Xcode, open the console (View -> Debug Area -> Debug Console)
 2. Set a breakpoint in your app or pause execution
 3. Type in the console:
 
    await DatabaseWipeUtility.shared.wipeEverything()
 
 Or to wipe only local data:
 
    await DatabaseWipeUtility.shared.wipeLocalData()
 
 Or to wipe only CloudKit:
 
    await DatabaseWipeUtility.shared.wipeCloudKitData()
 
 This will completely clear your database and start fresh!
 */
