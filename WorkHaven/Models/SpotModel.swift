//
//  SpotModel.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import Foundation
import CoreData

// MARK: - Noise Rating Enum
enum NoiseRating: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Spot Extensions
extension Spot {
    
    // MARK: - Computed Properties
    var coordinate: (latitude: Double, longitude: Double) {
        return (latitude: latitude, longitude: longitude)
    }
    
    var hasPhoto: Bool {
        return photoURL != nil && !photoURL!.isEmpty
    }
    
    var wifiRatingStars: String {
        return String(repeating: "★", count: Int(wifiRating)) + String(repeating: "☆", count: 5 - Int(wifiRating))
    }
    
    // MARK: - Aggregate Rating System
    
    /// Computed property that calculates an aggregate rating (1-5) based on WiFi, noise, and outlet availability
    /// Normalizes different rating systems into a unified 1-5 scale
    var aggregateRating: Double {
        let wifiScore = normalizedWifiRating
        let noiseScore = normalizedNoiseRating
        let outletScore = normalizedOutletRating
        
        let average = (wifiScore + noiseScore + outletScore) / 3.0
        
        // Round to nearest 0.5
        return round(average * 2) / 2
    }
    
    /// Normalizes WiFi rating to 1-5 scale
    /// Maps 'Fast/Strong/Open' to 5/5/4, 'Available' to 3, 'Free' to 2, direct 1-5 ratings as-is
    private var normalizedWifiRating: Double {
        // If wifiRating is already a 1-5 scale, use it directly
        if wifiRating >= 1 && wifiRating <= 5 {
            return Double(wifiRating)
        }
        
        // Handle text-based WiFi ratings (if any)
        // For now, default to neutral rating if invalid
        return 3.0
    }
    
    /// Normalizes noise rating to 1-5 scale (inverted)
    /// 'Low' = 5, 'Medium' = 3, 'High' = 1
    private var normalizedNoiseRating: Double {
        guard let noise = noiseRating else { return 3.0 }
        
        switch noise.lowercased() {
        case "low":
            return 5.0
        case "medium":
            return 3.0
        case "high":
            return 1.0
        default:
            return 3.0 // Default neutral rating
        }
    }
    
    /// Normalizes outlet availability to 1-5 scale
    /// Yes = 5, No = 1
    private var normalizedOutletRating: Double {
        return outlets ? 5.0 : 1.0
    }
    
    /// Calculates average user rating from UserRating entities
    /// Returns nil if no user ratings exist
    var averageUserRating: Double? {
        guard let ratings = userRatings as? Set<UserRating>, !ratings.isEmpty else {
            return nil
        }
        
        let totalRating = ratings.reduce(0.0) { sum, rating in
            let wifiScore = Double(rating.wifiRating)
            let noiseScore = rating.noiseRating == "Low" ? 5.0 : (rating.noiseRating == "Medium" ? 3.0 : 1.0)
            let outletScore = rating.outlets ? 5.0 : 1.0
            return sum + (wifiScore + noiseScore + outletScore) / 3.0
        }
        
        return totalRating / Double(ratings.count)
    }
    
    /// Returns the number of user ratings
    var userRatingCount: Int {
        return userRatings?.count ?? 0
    }
    
    /// Formatted aggregate rating string for display
    var aggregateRatingString: String {
        let rating = aggregateRating
        let stars = String(repeating: "★", count: Int(rating)) + String(repeating: "☆", count: 5 - Int(rating))
        return "\(stars) (\(String(format: "%.1f", rating)))"
    }
    
    /// Formatted overall rating string (50% aggregate + 50% user ratings)
    var overallRatingString: String {
        let rating = overallRating
        let stars = String(repeating: "★", count: Int(rating)) + String(repeating: "☆", count: 5 - Int(rating))
        return "\(stars) (\(String(format: "%.1f", rating)))"
    }
    
    /// Calculates overall rating for a spot (50% aggregate + 50% user ratings)
    /// Falls back to aggregate rating if no user ratings exist
    var overallRating: Double {
        let aggregateRating = self.aggregateRating
        
        // If no user ratings, return aggregate rating
        guard let userRating = averageUserRating else {
            return aggregateRating
        }
        
        // Calculate weighted average: 50% aggregate + 50% user ratings
        return (aggregateRating * 0.5) + (userRating * 0.5)
    }
    
    // MARK: - Validation
    func isValid() -> Bool {
        return !(name?.isEmpty ?? true) && !(address?.isEmpty ?? true) && wifiRating >= 1 && wifiRating <= 5
    }
    
    // MARK: - Static Methods
    static func createSampleSpot(in context: NSManagedObjectContext) -> Spot {
        let spot = Spot(context: context)
        spot.name = "Sample Coffee Shop"
        spot.address = "123 Main St, City, State"
        spot.latitude = 37.7749
        spot.longitude = -122.4194
        spot.wifiRating = 4
        spot.noiseRating = NoiseRating.medium.rawValue
        spot.outlets = true
        spot.tips = "Great coffee and fast wifi"
        spot.photoURL = nil
        return spot
    }
}
