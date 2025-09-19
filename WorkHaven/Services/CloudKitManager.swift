//
//  CloudKitManager.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import Foundation
import CloudKit
import CoreData
import SwiftUI

@MainActor
class CloudKitManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let context: NSManagedObjectContext
    
    // CloudKit record type
    private let recordType = "Spot"
    
    // Record field names
    private struct FieldNames {
        static let name = "name"
        static let address = "address"
        static let latitude = "latitude"
        static let longitude = "longitude"
        static let wifiRating = "wifiRating"
        static let noiseRating = "noiseRating"
        static let outlets = "outlets"
        static let tips = "tips"
        static let photoURL = "photoURL"
        static let lastModified = "lastModified"
        static let localID = "localID"
    }
    
    init(context: NSManagedObjectContext) {
        self.container = CKContainer.default()
        self.privateDatabase = container.privateCloudDatabase
        self.context = context
    }
    
    // MARK: - Public Methods
    
    func syncWithCloudKit() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Check CloudKit availability
            let status = try await container.accountStatus()
            guard status == .available else {
                throw CloudKitError.accountNotAvailable
            }
            
            // Upload local changes to CloudKit
            await uploadLocalChanges()
            
            // Download remote changes from CloudKit
            await downloadRemoteChanges()
            
            lastSyncDate = Date()
            
        } catch {
            syncError = error.localizedDescription
            print("CloudKit sync error: \(error)")
        }
        
        isSyncing = false
    }
    
    // MARK: - Upload Local Changes
    
    private func uploadLocalChanges() async {
        do {
            // Fetch spots that need to be uploaded
            let spotsToUpload = try fetchSpotsNeedingUpload()
            
            for spot in spotsToUpload {
                await uploadSpot(spot)
            }
            
        } catch {
            print("Error uploading local changes: \(error)")
        }
    }
    
    private func fetchSpotsNeedingUpload() throws -> [Spot] {
        let request: NSFetchRequest<Spot> = Spot.fetchRequest()
        // For now, upload all spots. In a real app, you'd track sync status
        return try context.fetch(request)
    }
    
    private func uploadSpot(_ spot: Spot) async {
        do {
            let record = try createCloudKitRecord(from: spot)
            
            // Try to save the record
            let savedRecord = try await privateDatabase.save(record)
            print("Successfully uploaded spot: \(spot.name ?? "Unknown")")
            
            // Update local spot with CloudKit record ID
            spot.setValue(savedRecord.recordID.recordName, forKey: "cloudKitRecordID")
            
        } catch {
            print("Error uploading spot \(spot.name ?? "Unknown"): \(error)")
        }
    }
    
    // MARK: - Download Remote Changes
    
    private func downloadRemoteChanges() async {
        do {
            // Create query for all Spot records
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "modificationDate", ascending: false)]
            
            let results = try await privateDatabase.records(matching: query)
            
            for (_, result) in results.matchResults {
                switch result {
                case .success(let record):
                    await processRemoteRecord(record)
                case .failure(let error):
                    print("Error fetching record: \(error)")
                }
            }
            
        } catch {
            print("Error downloading remote changes: \(error)")
        }
    }
    
    private func processRemoteRecord(_ record: CKRecord) async {
        do {
            // Check if we already have this spot locally
            let existingSpot = try findSpotByCloudKitID(record.recordID.recordName)
            
            if let existingSpot = existingSpot {
                // Update existing spot
                try updateSpotFromCloudKitRecord(existingSpot, record: record)
            } else {
                // Create new spot
                try createSpotFromCloudKitRecord(record)
            }
            
            // Save context
            try context.save()
            
        } catch {
            print("Error processing remote record: \(error)")
        }
    }
    
    // MARK: - Core Data to CloudKit Mapping
    
    private func createCloudKitRecord(from spot: Spot) throws -> CKRecord {
        let recordID: CKRecord.ID
        
        if let existingRecordID = spot.value(forKey: "cloudKitRecordID") as? String {
            recordID = CKRecord.ID(recordName: existingRecordID)
        } else {
            recordID = CKRecord.ID(recordName: UUID().uuidString)
        }
        
        let record = CKRecord(recordType: recordType, recordID: recordID)
        
        // Map Core Data fields to CloudKit fields
        record[FieldNames.name] = spot.name
        record[FieldNames.address] = spot.address
        record[FieldNames.latitude] = spot.latitude
        record[FieldNames.longitude] = spot.longitude
        record[FieldNames.wifiRating] = spot.wifiRating
        record[FieldNames.noiseRating] = spot.noiseRating
        record[FieldNames.outlets] = spot.outlets
        record[FieldNames.tips] = spot.tips
        record[FieldNames.photoURL] = spot.photoURL
        record[FieldNames.lastModified] = Date()
        record[FieldNames.localID] = spot.objectID.uriRepresentation().absoluteString
        
        return record
    }
    
    // MARK: - CloudKit to Core Data Mapping
    
    private func createSpotFromCloudKitRecord(_ record: CKRecord) throws {
        let spot = Spot(context: context)
        
        spot.name = record[FieldNames.name] as? String
        spot.address = record[FieldNames.address] as? String
        spot.latitude = record[FieldNames.latitude] as? Double ?? 0.0
        spot.longitude = record[FieldNames.longitude] as? Double ?? 0.0
        spot.wifiRating = record[FieldNames.wifiRating] as? Int16 ?? 1
        spot.noiseRating = record[FieldNames.noiseRating] as? String ?? "Low"
        spot.outlets = record[FieldNames.outlets] as? Bool ?? false
        spot.tips = record[FieldNames.tips] as? String
        spot.photoURL = record[FieldNames.photoURL] as? String
        
        // Store CloudKit record ID
        spot.setValue(record.recordID.recordName, forKey: "cloudKitRecordID")
    }
    
    private func updateSpotFromCloudKitRecord(_ spot: Spot, record: CKRecord) throws {
        // Check if remote record is newer
        let remoteLastModified = record[FieldNames.lastModified] as? Date ?? Date.distantPast
        let localLastModified = spot.value(forKey: "lastModified") as? Date ?? Date.distantPast
        
        if remoteLastModified > localLastModified {
            // Update with remote data
            spot.name = record[FieldNames.name] as? String
            spot.address = record[FieldNames.address] as? String
            spot.latitude = record[FieldNames.latitude] as? Double ?? 0.0
            spot.longitude = record[FieldNames.longitude] as? Double ?? 0.0
            spot.wifiRating = record[FieldNames.wifiRating] as? Int16 ?? 1
            spot.noiseRating = record[FieldNames.noiseRating] as? String ?? "Low"
            spot.outlets = record[FieldNames.outlets] as? Bool ?? false
            spot.tips = record[FieldNames.tips] as? String
            spot.photoURL = record[FieldNames.photoURL] as? String
            spot.setValue(remoteLastModified, forKey: "lastModified")
        }
    }
    
    // MARK: - Helper Methods
    
    private func findSpotByCloudKitID(_ cloudKitID: String) throws -> Spot? {
        let request: NSFetchRequest<Spot> = Spot.fetchRequest()
        request.predicate = NSPredicate(format: "cloudKitRecordID == %@", cloudKitID)
        request.fetchLimit = 1
        
        let results = try context.fetch(request)
        return results.first
    }
    
    // MARK: - Conflict Resolution
    
    private func resolveConflict(localSpot: Spot, remoteRecord: CKRecord) -> ConflictResolution {
        let localLastModified = localSpot.value(forKey: "lastModified") as? Date ?? Date.distantPast
        let remoteLastModified = remoteRecord[FieldNames.lastModified] as? Date ?? Date.distantPast
        
        if remoteLastModified > localLastModified {
            return .useRemote
        } else if localLastModified > remoteLastModified {
            return .useLocal
        } else {
            return .useRemote // Default to remote if timestamps are equal
        }
    }
}

// MARK: - Error Types

enum CloudKitError: LocalizedError {
    case accountNotAvailable
    case recordNotFound
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloud account is not available"
        case .recordNotFound:
            return "CloudKit record not found"
        case .syncFailed:
            return "CloudKit synchronization failed"
        }
    }
}

enum ConflictResolution {
    case useLocal
    case useRemote
    case merge
}

// MARK: - CloudKit Status

extension CloudKitManager {
    func checkCloudKitStatus() async -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            print("Error checking CloudKit status: \(error)")
            return .couldNotDetermine
        }
    }
    
    func requestCloudKitPermission() async -> Bool {
        // CloudKit permissions are handled automatically in iOS 17+
        // This method is kept for compatibility but always returns true
        return true
    }
}
