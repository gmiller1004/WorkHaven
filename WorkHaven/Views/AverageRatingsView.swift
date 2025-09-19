//
//  AverageRatingsView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI

struct AverageRatingsView: View {
    let spot: Spot
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Community Ratings")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if spot.hasUserRatings {
                    Text("\(spot.totalUserRatings) rating\(spot.totalUserRatings == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if spot.hasUserRatings {
                // Average WiFi Rating
                HStack {
                    Text("WiFi:")
                        .fontWeight(.medium)
                    Text(spot.averageWifiRatingStars)
                        .foregroundColor(.yellow)
                    Text("(\(String(format: "%.1f", spot.averageWifiRating)) avg)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                // Average Noise Rating
                HStack {
                    Text("Noise:")
                        .fontWeight(.medium)
                    Text(spot.averageNoiseRating)
                    Text(noiseIcon(for: spot.averageNoiseRating))
                    Spacer()
                }
                
                // Average Outlets
                HStack {
                    Text("Outlets:")
                        .fontWeight(.medium)
                    Image(systemName: spot.averageOutlets ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(spot.averageOutlets ? .green : .red)
                    Text(spot.averageOutlets ? "Available" : "Not Available")
                    Spacer()
                }
            } else {
                Text("No community ratings yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func noiseIcon(for level: String) -> String {
        switch level {
        case "Low": return "🔇"
        case "Medium": return "🔉"
        case "High": return "🔊"
        default: return "🔇"
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let spot = Spot.createSampleSpot(in: context)
    return AverageRatingsView(spot: spot)
        .padding()
}
