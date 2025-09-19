//
//  UserRatingModel.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import Foundation
import CoreData

extension UserRating {
    
    // MARK: - Computed Properties
    
    var wifiRatingStars: String {
        return String(repeating: "★", count: Int(wifiRating)) + String(repeating: "☆", count: 5 - Int(wifiRating))
    }
    
    var noiseRatingIcon: String {
        switch noiseRating {
        case "Low": return "🔇"
        case "Medium": return "🔉"
        case "High": return "🔊"
        default: return "🔇"
        }
    }
    
    var outletsIcon: String {
        return outlets ? "✅" : "❌"
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp ?? Date())
    }
}

// MARK: - Average Rating Calculations

extension Spot {
    
    var averageWifiRating: Double {
        guard let ratings = userRatings as? Set<UserRating>, !ratings.isEmpty else {
            return Double(wifiRating) // Fallback to original rating
        }
        
        let sum = ratings.reduce(0) { $0 + Double($1.wifiRating) }
        return sum / Double(ratings.count)
    }
    
    var averageWifiRatingStars: String {
        let avg = averageWifiRating
        let filledStars = Int(avg.rounded())
        let emptyStars = 5 - filledStars
        return String(repeating: "★", count: filledStars) + String(repeating: "☆", count: emptyStars)
    }
    
    var averageNoiseRating: String {
        guard let ratings = userRatings as? Set<UserRating>, !ratings.isEmpty else {
            return noiseRating ?? "Low" // Fallback to original rating
        }
        
        let noiseValues = ratings.map { rating in
            switch rating.noiseRating {
            case "Low": return 1
            case "Medium": return 2
            case "High": return 3
            default: return 1
            }
        }
        
        let average = noiseValues.reduce(0, +) / noiseValues.count
        
        switch average {
        case 1: return "Low"
        case 2: return "Medium"
        case 3: return "High"
        default: return "Low"
        }
    }
    
    var averageOutlets: Bool {
        guard let ratings = userRatings as? Set<UserRating>, !ratings.isEmpty else {
            return outlets // Fallback to original value
        }
        
        let trueCount = ratings.filter { $0.outlets }.count
        return trueCount > ratings.count / 2
    }
    
    var totalUserRatings: Int {
        return (userRatings as? Set<UserRating>)?.count ?? 0
    }
    
    var hasUserRatings: Bool {
        return totalUserRatings > 0
    }
}
