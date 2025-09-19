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
