//
//  SpotListView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//  Updated with comprehensive aggregate rating display system featuring 5-star ratings and detailed spot information
//

import SwiftUI
import CoreData

struct SpotListView: View {
    @StateObject private var viewModel: SpotViewModel
    @StateObject private var locationService = LocationService()
    @State private var searchText = ""
    @State private var showingAddSpot = false
    @State private var selectedNoiseFilter: NoiseRating?
    @State private var minWifiRating: Int16 = 1
    @State private var showOutletsOnly = false
    
    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: SpotViewModel(context: context))
    }
    
    var filteredSpots: [Spot] {
        var spots = viewModel.spots
        
        // Apply search filter
        if !searchText.isEmpty {
            spots = spots.filter { spot in
                (spot.name?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (spot.address?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (spot.tips?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply noise rating filter
        if let noiseFilter = selectedNoiseFilter {
            spots = spots.filter { $0.noiseRating == noiseFilter.rawValue }
        }
        
        // Apply wifi rating filter
        spots = spots.filter { $0.wifiRating >= minWifiRating }
        
        // Apply outlets filter
        if showOutletsOnly {
            spots = spots.filter { $0.outlets }
        }
        
        return spots
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading spots...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredSpots) { spot in
                            NavigationLink(destination: SpotDetailView(spot: spot, viewModel: viewModel)) {
                                SpotRowView(spot: spot, viewModel: viewModel, locationService: locationService)
                            }
                        }
                        .onDelete(perform: viewModel.deleteSpots)
                    }
                    .searchable(text: $searchText, prompt: "Search spots...")
                }
            }
            .navigationTitle("WorkHaven")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSpot = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { viewModel.fetchSpots() }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("All Noise Levels") {
                            selectedNoiseFilter = nil
                        }
                        ForEach(NoiseRating.allCases) { rating in
                            Button(rating.displayName) {
                                selectedNoiseFilter = rating
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddSpot) {
                AddSpotView(viewModel: viewModel, locationService: locationService)
            }
            .onAppear {
                locationService.requestLocationPermission()
                // Only fetch if we don't have spots yet
                if viewModel.spots.isEmpty {
                    viewModel.fetchSpots()
                }
            }
        }
    }
}

struct SpotRowView: View {
    let spot: Spot
    let viewModel: SpotViewModel
    let locationService: LocationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
            // Header row with name and overall rating
            HStack {
                Text(spot.name ?? "Unknown Spot")
                    .font(ThemeManager.Typography.dynamicHeadline())
                    .foregroundColor(ThemeManager.Colors.textPrimary)
                
                Spacer()
                
                // Overall rating stars
                OverallRatingStarsView(rating: viewModel.overallRating(for: spot))
            }
            
            // Address
            Text(spot.address ?? "No address")
                .font(ThemeManager.Typography.dynamicSubheadline())
                .foregroundColor(ThemeManager.Colors.textSecondary)
            
            // Overall rating description
            HStack {
                Text(viewModel.ratingDescription(for: viewModel.overallRating(for: spot)))
                    .font(ThemeManager.Typography.dynamicCaption())
                    .foregroundColor(viewModel.ratingColor(for: viewModel.overallRating(for: spot)))
                    .padding(.horizontal, ThemeManager.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(viewModel.ratingColor(for: viewModel.overallRating(for: spot)).opacity(0.1))
                    .cornerRadius(ThemeManager.CornerRadius.sm)
                
                Spacer()
                
                // Distance
                if let distance = locationService.getFormattedDistance(from: spot) {
                    Text(distance)
                        .font(ThemeManager.Typography.dynamicCaption())
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                }
            }
            
            // Detailed information row
            SpotDetailsRowView(spot: spot)
        }
        .padding(.vertical, ThemeManager.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var accessibilityLabel: String {
        let name = spot.name ?? "Unknown Spot"
        let address = spot.address ?? "No address"
        let rating = viewModel.overallRating(for: spot)
        let ratingText = String(format: "%.1f out of 5 quality stars", rating)
        let noise = spot.noiseRating ?? "Unknown"
        let outlets = spot.outlets ? "Yes" : "No"
        let wifiStars = String(repeating: "★", count: Int(spot.wifiRating)) + String(repeating: "☆", count: 5 - Int(spot.wifiRating))
        
        return "\(name) at \(address). \(ratingText). WiFi rating: \(wifiStars). Noise level: \(noise). Outlets available: \(outlets)"
    }
}

struct OverallRatingStarsView: View {
    let rating: Double
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: starImageName(for: index))
                    .foregroundColor(ThemeManager.Colors.accent) // Soft Coral #F28C38
                    .font(.caption)
            }
            
            Text(String(format: "%.1f", rating))
                .font(ThemeManager.Typography.dynamicCaption())
                .foregroundColor(ThemeManager.Colors.textSecondary)
                .padding(.leading, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(format: "%.1f", rating)) out of 5 quality stars")
    }
    
    private func starImageName(for index: Int) -> String {
        let fullStars = Int(rating)
        let hasHalfStar = rating - Double(fullStars) >= 0.5
        
        if index < fullStars {
            return "star.fill"
        } else if index == fullStars && hasHalfStar {
            return "star.lefthalf.fill"
        } else {
            return "star"
        }
    }
}

struct SpotDetailsRowView: View {
    let spot: Spot
    
    var body: some View {
        HStack(spacing: ThemeManager.Spacing.sm) {
            // WiFi rating
            HStack(spacing: 2) {
                Image(systemName: "wifi")
                    .foregroundColor(ThemeManager.Colors.primary)
                    .font(.caption)
                
                Text(wifiStarsText)
                    .font(ThemeManager.Typography.dynamicCaption())
                    .foregroundColor(ThemeManager.Colors.textSecondary)
            }
            .accessibilityLabel("WiFi rating: \(wifiStarsText)")
            
            // Noise level
            HStack(spacing: 2) {
                Image(systemName: "speaker.wave.2")
                    .foregroundColor(noiseColor)
                    .font(.caption)
                
                Text(spot.noiseRating ?? "Unknown")
                    .font(ThemeManager.Typography.dynamicCaption())
                    .foregroundColor(ThemeManager.Colors.textSecondary)
            }
            .accessibilityLabel("Noise level: \(spot.noiseRating ?? "Unknown")")
            
            // Outlets
            HStack(spacing: 2) {
                Image(systemName: "powerplug")
                    .foregroundColor(outletColor)
                    .font(.caption)
                
                Text(spot.outlets ? "Yes" : "No")
                    .font(ThemeManager.Typography.dynamicCaption())
                    .foregroundColor(ThemeManager.Colors.textSecondary)
            }
            .accessibilityLabel("Outlets available: \(spot.outlets ? "Yes" : "No")")
            
            Spacer()
        }
    }
    
    private var wifiStarsText: String {
        let stars = String(repeating: "★", count: Int(spot.wifiRating)) + String(repeating: "☆", count: 5 - Int(spot.wifiRating))
        return stars
    }
    
    private var noiseColor: Color {
        switch spot.noiseRating?.lowercased() {
        case "low":
            return ThemeManager.Colors.success
        case "medium":
            return ThemeManager.Colors.warning
        case "high":
            return ThemeManager.Colors.error
        default:
            return ThemeManager.Colors.textSecondary
        }
    }
    
    private var outletColor: Color {
        return spot.outlets ? ThemeManager.Colors.success : ThemeManager.Colors.textSecondary
    }
}

#Preview {
    SpotListView(context: PersistenceController.preview.container.viewContext)
}