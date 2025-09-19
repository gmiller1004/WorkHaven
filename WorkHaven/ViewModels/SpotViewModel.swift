//
//  SpotViewModel.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import Foundation
import CoreData
import SwiftUI

@MainActor
class SpotViewModel: ObservableObject {
    @Published var spots: [Spot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let viewContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        fetchSpots()
    }
    
    // MARK: - Fetch Operations
    func fetchSpots() {
        isLoading = true
        errorMessage = nil
        
        let request: NSFetchRequest<Spot> = Spot.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Spot.name, ascending: true)]
        
        do {
            spots = try viewContext.fetch(request)
        } catch {
            errorMessage = "Failed to fetch spots: \(error.localizedDescription)"
            print("Fetch error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - CRUD Operations
    func addSpot(name: String, address: String, latitude: Double, longitude: Double, 
                wifiRating: Int16, noiseRating: String, outlets: Bool, tips: String?, photoURL: String?) {
        let newSpot = Spot(context: viewContext)
        newSpot.name = name
        newSpot.address = address
        newSpot.latitude = latitude
        newSpot.longitude = longitude
        newSpot.wifiRating = wifiRating
        newSpot.noiseRating = noiseRating
        newSpot.outlets = outlets
        newSpot.tips = tips
        newSpot.photoURL = photoURL
        
        saveContext()
    }
    
    func updateSpot(_ spot: Spot) {
        saveContext()
    }
    
    func deleteSpot(_ spot: Spot) {
        viewContext.delete(spot)
        saveContext()
    }
    
    func deleteSpots(at offsets: IndexSet) {
        offsets.forEach { index in
            let spot = spots[index]
            viewContext.delete(spot)
        }
        saveContext()
    }
    
    // MARK: - Search and Filter
    func searchSpots(query: String) -> [Spot] {
        if query.isEmpty {
            return spots
        }
        
        return spots.filter { spot in
            (spot.name?.localizedCaseInsensitiveContains(query) ?? false) ||
            (spot.address?.localizedCaseInsensitiveContains(query) ?? false) ||
            (spot.tips?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    
    func filterSpotsByNoiseRating(_ rating: NoiseRating) -> [Spot] {
        return spots.filter { $0.noiseRating == rating.rawValue }
    }
    
    func filterSpotsByWifiRating(minRating: Int16) -> [Spot] {
        return spots.filter { $0.wifiRating >= minRating }
    }
    
    func filterSpotsWithOutlets() -> [Spot] {
        return spots.filter { $0.outlets }
    }
    
    // MARK: - Public Methods
    func saveContext() {
        do {
            try viewContext.save()
            fetchSpots() // Refresh the list
        } catch {
            errorMessage = "Failed to save spot: \(error.localizedDescription)"
            print("Save error: \(error)")
        }
    }
}
