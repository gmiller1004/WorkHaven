//
//  SpotViewModel.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//  Updated with comprehensive rating system, auto-seeding, and location-based discovery
//

import Foundation
import CoreData
import SwiftUI
import CoreLocation
import MapKit

@MainActor
class SpotViewModel: ObservableObject {
    @Published var spots: [Spot] = []
    @Published var isLoading = false
    @Published var isSeeding = false
    @Published var errorMessage: String?
    @Published var seedingStatus = ""
    
    private let viewContext: NSManagedObjectContext
    private let locationService = LocationService()
    private let spotDiscoveryService = SpotDiscoveryService.shared
    private let discoveryRadius: CLLocationDistance = 32186.88 // 20 miles in meters
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
        setupInitialData()
    }
    
    // MARK: - Initial Setup and Auto-Seeding
    
    private func setupInitialData() {
        // Check if we need to wipe data (first launch)
        if !UserDefaults.standard.bool(forKey: "DataWiped") {
            wipeAllData()
            UserDefaults.standard.set(true, forKey: "DataWiped")
        }
        
        // Only start seeding if CloudKit is enabled (to prevent pulling old data)
        // For fresh start, use the Complete Reset button in Settings
        print("🚀 SpotViewModel initialized - use Complete Reset in Settings to discover fresh spots")
    }
    
    private func wipeAllData() {
        print("🗑️ Wiping all Core Data on first launch...")
        
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Spot.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(deleteRequest)
            try viewContext.save()
            print("✅ All data wiped successfully")
        } catch {
            print("❌ Error wiping data: \(error)")
            errorMessage = "Failed to reset data: \(error.localizedDescription)"
        }
    }
    
    private func performAutoSeeding() async {
        await MainActor.run {
            isSeeding = true
            seedingStatus = "Starting auto-seeding..."
            errorMessage = nil
        }
        
        do {
            // Get user location
            guard let userLocation = await getCurrentUserLocation() else {
                await MainActor.run {
                    isSeeding = false
                    seedingStatus = "Location required"
                    errorMessage = "Location access is required to find nearby work spots. Please enable location services in Settings."
                }
                return
            }
            
            // Check for existing spots within radius
            let existingSpots = await checkSpotsWithinRadius(userLocation: userLocation)
            
            if existingSpots.count >= 1 {
                await MainActor.run {
                    spots = existingSpots
                    isSeeding = false
                    seedingStatus = "Found \(existingSpots.count) existing spots"
                }
                return
            }
            
            // Discover new spots if we have less than 1
            await MainActor.run {
                seedingStatus = "Discovering nearby work spots..."
            }
            
            let discoveredSpots = await spotDiscoveryService.discoverSpots(near: userLocation, radius: discoveryRadius)
            
            await MainActor.run {
                spots = discoveredSpots
                isSeeding = false
                seedingStatus = discoveredSpots.isEmpty ? "No spots found in area" : "Discovered \(discoveredSpots.count) new spots"
                
                if discoveredSpots.isEmpty {
                    errorMessage = "No work spots found in your area. Try enabling location services or check your internet connection."
                }
            }
            
            // Recalculate overall ratings after seeding
            await recalculateOverallRatings()
            
        } catch {
            await MainActor.run {
                isSeeding = false
                seedingStatus = "Seeding failed"
                errorMessage = "Failed to seed data: \(error.localizedDescription)"
            }
        }
    }
    
    private func getCurrentUserLocation() async -> CLLocation? {
        locationService.requestLocationPermission()
        
        // Wait for location with timeout
        let timeout: TimeInterval = 15.0
        let startTime = Date()
        
        while locationService.currentLocation == nil && Date().timeIntervalSince(startTime) < timeout {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        return locationService.currentLocation
    }
    
    private func checkSpotsWithinRadius(userLocation: CLLocation) async -> [Spot] {
        let fetchRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
        
        do {
            let allSpots = try viewContext.fetch(fetchRequest)
            let nearbySpots = allSpots.filter { spot in
                let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                return userLocation.distance(from: spotLocation) <= discoveryRadius
            }
            return nearbySpots
        } catch {
            print("❌ Error checking existing spots: \(error)")
            return []
        }
    }
    
    private func recalculateOverallRatings() async {
        await MainActor.run {
            seedingStatus = "Recalculating ratings..."
        }
        
        // Force recalculation of overall ratings by touching the spots
        for spot in spots {
            spot.lastModified = Date()
        }
        
        do {
            try viewContext.save()
            await MainActor.run {
                seedingStatus = "Ratings updated successfully"
            }
        } catch {
            print("❌ Error recalculating ratings: \(error)")
        }
    }
    
    // MARK: - Public Seeding Methods
    
    func refreshSpots() async {
        await performAutoSeeding()
    }
    
    func manualSeed() async {
        await performAutoSeeding()
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
    
    /// Gets average user rating for a spot
    func averageUserRating(for spot: Spot) -> Double {
        return spot.averageUserRating ?? 0.0
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
    
    // MARK: - Distance and Location
    
    /// Calculates distance from user location to a spot
    func distanceFromUser(for spot: Spot, userLocation: CLLocation?) -> CLLocationDistance? {
        guard let userLocation = userLocation else { return nil }
        let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
        return userLocation.distance(from: spotLocation)
    }
    
    /// Gets formatted distance string for a spot
    func formattedDistance(for spot: Spot, userLocation: CLLocation?) -> String? {
        guard let distance = distanceFromUser(for: spot, userLocation: userLocation) else { return nil }
        
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
    }
    
    /// Sorts spots by distance from user location, then by overall rating
    func sortSpotsByDistanceAndRating(_ spots: [Spot], userLocation: CLLocation?) -> [Spot] {
        return spots.sorted { spot1, spot2 in
            let distance1 = distanceFromUser(for: spot1, userLocation: userLocation)
            let distance2 = distanceFromUser(for: spot2, userLocation: userLocation)
            
            // If both have distances, sort by distance
            if let dist1 = distance1, let dist2 = distance2 {
                return dist1 < dist2
            }
            // If only one has distance, prioritize it
            else if distance1 != nil {
                return true
            } else if distance2 != nil {
                return false
            }
            // If neither has distance, sort by overall rating
            else {
                return overallRating(for: spot1) > overallRating(for: spot2)
            }
        }
    }
    
    /// Sorts spots by overall rating only (descending)
    func sortSpotsByRatingOnly(_ spots: [Spot]) -> [Spot] {
        return spots.sorted { spot1, spot2 in
            overallRating(for: spot1) > overallRating(for: spot2)
        }
    }
    
    /// Filters spots by city
    func filterSpotsByCity(_ spots: [Spot], city: String) -> [Spot] {
        return spots.filter { spot in
            spot.address?.contains(city) == true
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
    
    // MARK: - Discovery Service Integration
    
    func configureDiscoveryService() {
        spotDiscoveryService.configure(with: viewContext)
    }
    
    func getDiscoveryStatus() -> String {
        return spotDiscoveryService.apiKeyStatus
    }
    
    func hasDiscoveryAPIKey() -> Bool {
        return spotDiscoveryService.hasGrokAPIKey()
    }
    
    func performFreshDiscovery() async {
        await MainActor.run {
            isSeeding = true
            seedingStatus = "Starting fresh discovery..."
            errorMessage = nil
        }
        
        do {
            // Get user location
            guard let userLocation = await getCurrentUserLocation() else {
                await MainActor.run {
                    isSeeding = false
                    seedingStatus = "Location required"
                    errorMessage = "Location access is required to find nearby work spots. Please enable location services in Settings."
                }
                return
            }
            
            // Discover new spots
            await MainActor.run {
                seedingStatus = "Discovering nearby work spots..."
            }
            
            let discoveredSpots = await spotDiscoveryService.discoverSpots(near: userLocation, radius: discoveryRadius)
            
            await MainActor.run {
                spots = discoveredSpots
                isSeeding = false
                seedingStatus = discoveredSpots.isEmpty ? "No spots found in area" : "Discovered \(discoveredSpots.count) new spots"
                
                if discoveredSpots.isEmpty {
                    errorMessage = "No work spots found in your area. Try enabling location services or check your internet connection."
                }
            }
            
            // Recalculate overall ratings after seeding
            await recalculateOverallRatings()
            
        } catch {
            await MainActor.run {
                isSeeding = false
                seedingStatus = "Discovery failed"
                errorMessage = "Failed to discover spots: \(error.localizedDescription)"
            }
        }
    }
}