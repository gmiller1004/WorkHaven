//
//  SpotViewModel.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//  Updated with comprehensive rating system including aggregate and user ratings
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
    
    // MARK: - Rating System
    
    /// Gets overall rating for a spot (uses the computed property from SpotModel)
    func overallRating(for spot: Spot) -> Double {
        return spot.overallRating
    }
    
    /// Gets rating color based on rating value using ThemeManager colors
    func ratingColor(for rating: Double) -> Color {
        switch rating {
        case 4.5...5.0:
            return ThemeManager.Colors.success // Sage Green for excellent
        case 3.5..<4.5:
            return ThemeManager.Colors.accent // Soft Coral for good
        case 2.5..<3.5:
            return ThemeManager.Colors.warning // Warm Yellow for average
        case 1.5..<2.5:
            return ThemeManager.Colors.error // Soft Red for poor
        default:
            return ThemeManager.Colors.textSecondary // Medium Brown for very poor
        }
    }
    
    /// Gets rating description based on rating value
    func ratingDescription(for rating: Double) -> String {
        switch rating {
        case 4.5...5.0:
            return "Excellent"
        case 3.5..<4.5:
            return "Good"
        case 2.5..<3.5:
            return "Average"
        case 1.5..<2.5:
            return "Poor"
        default:
            return "Very Poor"
        }
    }
    
    /// Gets spots sorted by overall rating (highest first)
    func spotsSortedByRating() -> [Spot] {
        return spots.sorted { spot1, spot2 in
            overallRating(for: spot1) > overallRating(for: spot2)
        }
    }
    
    /// Gets top-rated spots (rating >= 4.0)
    func topRatedSpots() -> [Spot] {
        return spots.filter { overallRating(for: $0) >= 4.0 }
    }
    
    /// Gets spots with user ratings
    func spotsWithUserRatings() -> [Spot] {
        return spots.filter { $0.userRatingCount > 0 }
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
        newSpot.lastModified = Date()
        
        saveContext()
    }
    
    func updateSpot(_ spot: Spot) {
        spot.lastModified = Date()
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
    
    // MARK: - User Rating Management
    
    /// Adds a user rating to a spot
    func addUserRating(to spot: Spot, wifiRating: Int16, noiseRating: String, outlets: Bool, tips: String?) {
        let userRating = UserRating(context: viewContext)
        userRating.wifiRating = wifiRating
        userRating.noiseRating = noiseRating
        userRating.outlets = outlets
        userRating.tip = tips
        userRating.spot = spot
        userRating.timestamp = Date()
        
        spot.addToUserRatings(userRating)
        spot.lastModified = Date()
        
        saveContext()
    }
    
    /// Removes a user rating from a spot
    func removeUserRating(_ rating: UserRating, from spot: Spot) {
        spot.removeFromUserRatings(rating)
        viewContext.delete(rating)
        spot.lastModified = Date()
        
        saveContext()
    }
    
    /// Gets all user ratings for a spot
    func userRatings(for spot: Spot) -> [UserRating] {
        guard let ratings = spot.userRatings as? Set<UserRating> else { return [] }
        return Array(ratings).sorted { rating1, rating2 in
            (rating1.timestamp ?? Date.distantPast) > (rating2.timestamp ?? Date.distantPast)
        }
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
    
    /// Filters spots by overall rating range
    func filterSpotsByRating(minRating: Double, maxRating: Double = 5.0) -> [Spot] {
        return spots.filter { spot in
            let rating = overallRating(for: spot)
            return rating >= minRating && rating <= maxRating
        }
    }
    
    /// Filters spots by rating description
    func filterSpotsByRatingDescription(_ description: String) -> [Spot] {
        return spots.filter { spot in
            let rating = overallRating(for: spot)
            return ratingDescription(for: rating).lowercased() == description.lowercased()
        }
    }
    
    // MARK: - Statistics
    
    /// Gets average rating across all spots
    func averageRatingAcrossAllSpots() -> Double {
        guard !spots.isEmpty else { return 0.0 }
        
        let totalRating = spots.reduce(0.0) { sum, spot in
            sum + overallRating(for: spot)
        }
        
        return totalRating / Double(spots.count)
    }
    
    /// Gets rating distribution statistics
    func ratingDistribution() -> [String: Int] {
        var distribution: [String: Int] = [:]
        
        for spot in spots {
            let rating = overallRating(for: spot)
            let description = ratingDescription(for: rating)
            distribution[description, default: 0] += 1
        }
        
        return distribution
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