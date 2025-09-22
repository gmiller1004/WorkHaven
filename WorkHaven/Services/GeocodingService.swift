//
//  GeocodingService.swift
//  WorkHaven
//
//  Created by AI Assistant on 2024
//  Geocoding service for converting addresses to accurate lat/long coordinates
//
//  This service provides geocoding functionality using Core Location's CLGeocoder
//  to convert spot addresses to precise latitude and longitude coordinates.
//  Includes rate limiting, error handling, and Core Data integration.
//

import Foundation
import CoreLocation
import CoreData

/// Service for geocoding addresses to accurate latitude and longitude coordinates
/// Uses Core Location's CLGeocoder with rate limiting and error handling
@MainActor
class GeocodingService: ObservableObject {
    
    // MARK: - Properties
    
    /// Shared singleton instance
    static let shared = GeocodingService()
    
    /// Core Data managed object context
    private var viewContext: NSManagedObjectContext?
    
    /// Geocoding queue for rate limiting
    private let geocodingQueue = DispatchQueue(label: "com.workhaven.geocoding", qos: .userInitiated)
    
    /// Rate limiting properties
    private var lastGeocodingTime: Date = Date.distantPast
    private let minimumInterval: TimeInterval = 1.0 // 1 second between requests
    private var pendingRequests: [GeocodingRequest] = []
    
    /// Published properties for UI updates
    @Published var isGeocoding = false
    @Published var geocodingError: String?
    @Published var geocodingProgress: Double = 0.0
    
    // MARK: - Initialization
    
    private init() {}
    
    /// Configure the service with Core Data context
    /// - Parameter context: Core Data managed object context
    func configure(with context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    // MARK: - Public Geocoding Methods
    
    /// Geocode an address string to latitude and longitude coordinates
    /// - Parameters:
    ///   - address: The address string to geocode
    ///   - region: Optional region hint for better results
    /// - Returns: Array of CLPlacemark objects or throws an error
    func geocodeAddress(_ address: String, region: CLRegion? = nil) async throws -> [CLPlacemark] {
        // Validate input
        guard !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw GeocodingError.invalidAddress
        }
        
        // Rate limiting
        await waitForRateLimit()
        
        // Update UI state
        isGeocoding = true
        geocodingError = nil
        
        do {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.geocodeAddressString(address, in: region)
            
            // Update UI state
            isGeocoding = false
            geocodingProgress = 1.0
            
            return placemarks
        } catch {
            // Update UI state
            isGeocoding = false
            geocodingError = error.localizedDescription
            
            throw GeocodingError.geocodingFailed(error.localizedDescription)
        }
    }
    
    /// Verify and update a spot's location using geocoding
    /// - Parameter spot: The Spot entity to verify and potentially update
    /// - Returns: True if location was updated, false otherwise
    func verifySpotLocation(_ spot: Spot) async -> Bool {
        guard let context = viewContext,
              let address = spot.address,
              !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // Check if we have existing coordinates
        let hasExistingCoords = spot.latitude != 0.0 && spot.longitude != 0.0
        
        do {
            // Geocode the address
            let placemarks = try await geocodeAddress(address)
            
            guard let bestPlacemark = placemarks.first,
                  let location = bestPlacemark.location else {
                return false
            }
            
            let newLatitude = location.coordinate.latitude
            let newLongitude = location.coordinate.longitude
            
            // Calculate distance from existing coordinates if available
            var shouldUpdate = true
            if hasExistingCoords {
                let existingLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                let distance = location.distance(from: existingLocation)
                
                // Only update if the new location is significantly different (more than 100 meters)
                shouldUpdate = distance > 100.0
            }
            
            if shouldUpdate {
                // Update the spot's coordinates
                spot.latitude = newLatitude
                spot.longitude = newLongitude
                spot.lastModified = Date()
                
                // Save to Core Data
                try context.save()
                
                print("📍 Updated coordinates for \(spot.name ?? "Unknown"): \(newLatitude), \(newLongitude)")
                return true
            } else {
                print("📍 Coordinates for \(spot.name ?? "Unknown") are already accurate")
                return false
            }
            
        } catch {
            print("❌ Geocoding failed for \(spot.name ?? "Unknown"): \(error.localizedDescription)")
            return false
        }
    }
    
    /// Batch geocode multiple spots
    /// - Parameter spots: Array of Spot entities to geocode
    /// - Returns: Number of spots successfully updated
    func batchGeocodeSpots(_ spots: [Spot]) async -> Int {
        guard !spots.isEmpty else { return 0 }
        
        var updatedCount = 0
        let totalSpots = spots.count
        
        for (index, spot) in spots.enumerated() {
            // Update progress
            geocodingProgress = Double(index) / Double(totalSpots)
            
            // Geocode this spot
            let wasUpdated = await verifySpotLocation(spot)
            if wasUpdated {
                updatedCount += 1
            }
            
            // Small delay between requests to respect rate limits
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Reset progress
        geocodingProgress = 1.0
        isGeocoding = false
        
        return updatedCount
    }
    
    // MARK: - Private Methods
    
    /// Wait for rate limit to be satisfied
    private func waitForRateLimit() async {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastGeocodingTime)
        
        if timeSinceLastRequest < minimumInterval {
            let waitTime = minimumInterval - timeSinceLastRequest
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        lastGeocodingTime = Date()
    }
    
    /// Create a region hint based on existing coordinates
    /// - Parameter spot: The spot to create a region hint for
    /// - Returns: Optional CLRegion for better geocoding results
    private func createRegionHint(for spot: Spot) -> CLRegion? {
        guard spot.latitude != 0.0 && spot.longitude != 0.0 else { return nil }
        
        let center = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        return CLCircularRegion(center: center, radius: 10000, identifier: "spot_region") // 10km radius
    }
}

// MARK: - Supporting Types

/// Geocoding request structure for queue management
private struct GeocodingRequest {
    let address: String
    let region: CLRegion?
    let completion: (Result<[CLPlacemark], Error>) -> Void
}

/// Geocoding errors
enum GeocodingError: LocalizedError {
    case invalidAddress
    case geocodingFailed(String)
    case noResults
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid address provided"
        case .geocodingFailed(let message):
            return "Geocoding failed: \(message)"
        case .noResults:
            return "No results found for the provided address"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        }
    }
}

// MARK: - Extensions

extension GeocodingService {
    
    /// Get formatted address from a placemark
    /// - Parameter placemark: The CLPlacemark to format
    /// - Returns: Formatted address string
    func formattedAddress(from placemark: CLPlacemark) -> String {
        var addressComponents: [String] = []
        
        if let name = placemark.name { addressComponents.append(name) }
        if let thoroughfare = placemark.thoroughfare { addressComponents.append(thoroughfare) }
        if let locality = placemark.locality { addressComponents.append(locality) }
        if let administrativeArea = placemark.administrativeArea { addressComponents.append(administrativeArea) }
        if let country = placemark.country { addressComponents.append(country) }
        
        return addressComponents.joined(separator: ", ")
    }
    
    /// Calculate distance between two coordinates
    /// - Parameters:
    ///   - lat1: First latitude
    ///   - lon1: First longitude
    ///   - lat2: Second latitude
    ///   - lon2: Second longitude
    /// - Returns: Distance in meters
    func distanceBetween(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let location1 = CLLocation(latitude: lat1, longitude: lon1)
        let location2 = CLLocation(latitude: lat2, longitude: lon2)
        return location1.distance(from: location2)
    }
    
    /// Check if coordinates are valid
    /// - Parameters:
    ///   - latitude: Latitude to validate
    ///   - longitude: Longitude to validate
    /// - Returns: True if coordinates are valid
    func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        return latitude >= -90.0 && latitude <= 90.0 && longitude >= -180.0 && longitude <= 180.0
    }
}

// MARK: - UI Integration

extension GeocodingService {
    
    /// Show geocoding error alert using ThemeManager
    /// - Parameter error: The error to display
    func showGeocodingError(_ error: Error) {
        geocodingError = error.localizedDescription
        
        // Clear error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.geocodingError = nil
        }
    }
    
    /// Clear geocoding error
    func clearError() {
        geocodingError = nil
    }
    
    /// Reset geocoding progress
    func resetProgress() {
        geocodingProgress = 0.0
        isGeocoding = false
    }
}
