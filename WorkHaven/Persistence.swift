//
//  Persistence.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample spots
        let sampleSpots: [(name: String, address: String, latitude: Double, longitude: Double, wifiRating: Int16, noiseRating: String, outlets: Bool, tips: String?, photoURL: String?)] = [
            (name: "Blue Bottle Coffee", address: "66 Mint St, San Francisco, CA", latitude: 37.7749, longitude: -122.4194, wifiRating: 4, noiseRating: "Low", outlets: true, tips: "Great coffee and fast wifi", photoURL: nil),
            (name: "Philz Coffee", address: "3101 24th St, San Francisco, CA", latitude: 37.7521, longitude: -122.4180, wifiRating: 5, noiseRating: "Medium", outlets: true, tips: "Amazing coffee blends", photoURL: nil),
            (name: "Ritual Coffee", address: "1026 Valencia St, San Francisco, CA", latitude: 37.7575, longitude: -122.4219, wifiRating: 3, noiseRating: "High", outlets: false, tips: "Popular spot, can get crowded", photoURL: nil),
            (name: "Sightglass Coffee", address: "270 7th St, San Francisco, CA", latitude: 37.7749, longitude: -122.4194, wifiRating: 4, noiseRating: "Low", outlets: true, tips: "Great for remote work", photoURL: nil),
            (name: "Four Barrel Coffee", address: "375 Valencia St, San Francisco, CA", latitude: 37.7611, longitude: -122.4219, wifiRating: 3, noiseRating: "Medium", outlets: true, tips: "Good coffee, limited seating", photoURL: nil)
        ]
        
        for spotData in sampleSpots {
            let spot = Spot(context: viewContext)
            spot.name = spotData.name
            spot.address = spotData.address
            spot.latitude = spotData.latitude
            spot.longitude = spotData.longitude
            spot.wifiRating = spotData.wifiRating
            spot.noiseRating = spotData.noiseRating
            spot.outlets = spotData.outlets
            spot.tips = spotData.tips
            spot.photoURL = spotData.photoURL
        }
        
        // Keep the original Item creation for compatibility
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "WorkHaven")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
