//
//  SpotSearchView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//  Updated with distance-based sorting, city filtering, and comprehensive rating integration
//

import SwiftUI
import CoreData
import CoreLocation

struct SpotSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: SpotViewModel
    @StateObject private var locationService = LocationService()
    @State private var searchText = ""
    @State private var selectedWifiRating: Int16 = 1
    @State private var selectedNoiseRating: NoiseRating? = nil
    @State private var outletsOnly = false
    @State private var selectedOverallRating: Double = 1.0
    @State private var showingFilters = false
    @State private var filteredSpots: [Spot] = []
    @State private var selectedCity = "Boise"
    @State private var sortByRatingOnly = false
    @State private var showingLocationToast = false
    
    // Default location (Boise, ID) as fallback
    private let defaultLocation = CLLocation(latitude: 43.6150, longitude: -116.2023)
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        self._viewModel = StateObject(wrappedValue: SpotViewModel(context: context))
    }
    
    // Dynamic fetch request that updates based on filters
    private var fetchRequest: NSFetchRequest<Spot> {
        let request: NSFetchRequest<Spot> = Spot.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        // City filter
        let cityPredicate = NSPredicate(format: "address CONTAINS[cd] %@", selectedCity)
        predicates.append(cityPredicate)
        
        // Search text filter
        if !searchText.isEmpty {
            let searchPredicate = NSPredicate(
                format: "name CONTAINS[cd] %@ OR address CONTAINS[cd] %@ OR tips CONTAINS[cd] %@",
                searchText, searchText, searchText
            )
            predicates.append(searchPredicate)
        }
        
        // WiFi rating filter
        let wifiPredicate = NSPredicate(format: "wifiRating >= %d", selectedWifiRating)
        predicates.append(wifiPredicate)
        
        // Noise rating filter
        if let noiseRating = selectedNoiseRating {
            let noisePredicate = NSPredicate(format: "noiseRating == %@", noiseRating.rawValue)
            predicates.append(noisePredicate)
        }
        
        // Outlets filter
        if outletsOnly {
            let outletsPredicate = NSPredicate(format: "outlets == YES")
            predicates.append(outletsPredicate)
        }
        
        // Combine all predicates
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Sort by name (will be overridden by distance/rating sort)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Spot.name, ascending: true)]
        
        return request
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText)
                    .padding(.horizontal, ThemeManager.Spacing.md)
                    .padding(.top, ThemeManager.Spacing.sm)
                
                // Filter Toggle Bar
                FilterToggleBar(
                    selectedWifiRating: $selectedWifiRating,
                    selectedNoiseRating: $selectedNoiseRating,
                    outletsOnly: $outletsOnly,
                    selectedOverallRating: $selectedOverallRating,
                    showingFilters: $showingFilters,
                    selectedCity: $selectedCity,
                    sortByRatingOnly: $sortByRatingOnly
                )
                .padding(.horizontal, ThemeManager.Spacing.md)
                .padding(.vertical, ThemeManager.Spacing.sm)
                
                // Results List
                if filteredSpots.isEmpty {
                    NoSpotsFoundView(selectedCity: selectedCity)
                } else {
                    SpotSearchResultsView(
                        spots: filteredSpots, 
                        viewModel: viewModel,
                        locationService: locationService,
                        sortByRatingOnly: sortByRatingOnly
                    )
                }
            }
            .background(ThemeManager.Colors.background)
            .navigationTitle("Search Spots")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                locationService.requestLocationPermission()
                updateFilteredSpots()
            }
            .onChange(of: searchText) { _ in
                updateFilteredSpots()
            }
            .onChange(of: selectedWifiRating) { _ in
                updateFilteredSpots()
            }
            .onChange(of: selectedNoiseRating) { _ in
                updateFilteredSpots()
            }
            .onChange(of: outletsOnly) { _ in
                updateFilteredSpots()
            }
            .onChange(of: selectedOverallRating) { _ in
                updateFilteredSpots()
            }
            .onChange(of: selectedCity) { _ in
                updateFilteredSpots()
            }
            .onChange(of: sortByRatingOnly) { _ in
                updateFilteredSpots()
            }
            .onChange(of: locationService.isLocationEnabled) { isEnabled in
                if !isEnabled && !sortByRatingOnly {
                    showingLocationToast = true
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterDetailView(
                    selectedWifiRating: $selectedWifiRating,
                    selectedNoiseRating: $selectedNoiseRating,
                    outletsOnly: $outletsOnly,
                    selectedOverallRating: $selectedOverallRating,
                    selectedCity: $selectedCity,
                    sortByRatingOnly: $sortByRatingOnly
                )
            }
            .toast(isPresented: $showingLocationToast) {
                ToastView(
                    message: "Enable location for distance sorting",
                    backgroundColor: ThemeManager.Colors.secondary // Latte beige #FFF8E7
                )
            }
        }
    }
    
    private func updateFilteredSpots() {
        do {
            let allSpots = try viewContext.fetch(fetchRequest)
            // Apply overall rating filter in memory since it's a computed property
            let ratingFilteredSpots = allSpots.filter { spot in
                viewModel.overallRating(for: spot) >= selectedOverallRating
            }
            
            // Sort by distance and rating
            filteredSpots = sortSpots(ratingFilteredSpots)
        } catch {
            print("Error fetching spots: \(error)")
            filteredSpots = []
        }
    }
    
    private func sortSpots(_ spots: [Spot]) -> [Spot] {
        if sortByRatingOnly {
            // Sort by overall rating only (descending)
            return spots.sorted { spot1, spot2 in
                viewModel.overallRating(for: spot1) > viewModel.overallRating(for: spot2)
            }
        } else {
            // Sort by distance first, then by overall rating
            return spots.sorted { spot1, spot2 in
                let distance1 = getDistanceFromUser(for: spot1)
                let distance2 = getDistanceFromUser(for: spot2)
                
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
                    return viewModel.overallRating(for: spot1) > viewModel.overallRating(for: spot2)
                }
            }
        }
    }
    
    private func getDistanceFromUser(for spot: Spot) -> CLLocationDistance? {
        if let userLocation = locationService.currentLocation {
            let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
            return userLocation.distance(from: spotLocation)
        } else {
            // Use default location (Boise) as fallback
            let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
            return defaultLocation.distance(from: spotLocation)
        }
    }
}

// MARK: - Search Bar Component
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ThemeManager.Colors.textSecondary)
                .font(ThemeManager.Typography.dynamicBody())
            
            TextField("Search spots...", text: $text)
                .font(ThemeManager.Typography.dynamicBody())
                .textFieldStyle(PlainTextFieldStyle())
                .accessibilityLabel("Search work spots")
                .accessibilityHint("Enter spot name, address, or tips to search")
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                        .font(ThemeManager.Typography.dynamicBody())
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, ThemeManager.Spacing.md)
        .padding(.vertical, ThemeManager.Spacing.sm)
        .background(ThemeManager.Colors.surface)
        .cornerRadius(ThemeManager.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.md)
                .stroke(ThemeManager.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Filter Toggle Bar
struct FilterToggleBar: View {
    @Binding var selectedWifiRating: Int16
    @Binding var selectedNoiseRating: NoiseRating?
    @Binding var outletsOnly: Bool
    @Binding var selectedOverallRating: Double
    @Binding var showingFilters: Bool
    @Binding var selectedCity: String
    @Binding var sortByRatingOnly: Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeManager.Spacing.sm) {
                // City Filter
                Menu {
                    Button("Boise") { selectedCity = "Boise" }
                    Button("Austin") { selectedCity = "Austin" }
                    Button("Seattle") { selectedCity = "Seattle" }
                } label: {
                    FilterChip(
                        title: selectedCity,
                        icon: "location",
                        isActive: true,
                        color: ThemeManager.Colors.primary
                    )
                }
                .accessibilityLabel("City filter: \(selectedCity)")
                
                // Sort Toggle
                Button(action: { sortByRatingOnly.toggle() }) {
                    FilterChip(
                        title: sortByRatingOnly ? "Rating Only" : "Distance & Rating",
                        icon: sortByRatingOnly ? "star.fill" : "location.fill",
                        isActive: true,
                        color: ThemeManager.Colors.accent
                    )
                }
                .accessibilityLabel("Sort by: \(sortByRatingOnly ? "Rating only" : "Distance and rating")")
                
                // Overall Rating Filter
                FilterChip(
                    title: "\(String(format: "%.1f", selectedOverallRating))+ Stars",
                    icon: "star.fill",
                    isActive: selectedOverallRating > 1.0,
                    color: ThemeManager.Colors.accent
                )
                .accessibilityLabel("Overall rating filter: \(String(format: "%.1f", selectedOverallRating)) or more stars")
                
                // WiFi Rating Filter
                Menu {
                    ForEach(1...5, id: \.self) { rating in
                        Button(action: { selectedWifiRating = Int16(rating) }) {
                            HStack {
                                Text("\(rating) Star\(rating == 1 ? "" : "s")")
                                if selectedWifiRating == Int16(rating) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    FilterChip(
                        title: "WiFi \(selectedWifiRating)+",
                        icon: "wifi",
                        isActive: selectedWifiRating > 1,
                        color: ThemeManager.Colors.primary
                    )
                }
                .accessibilityLabel("WiFi rating filter: \(selectedWifiRating) or more stars")
                
                // Noise Rating Filter
                Menu {
                    Button("All Noise Levels") {
                        selectedNoiseRating = nil
                    }
                    ForEach(NoiseRating.allCases) { rating in
                        Button(rating.displayName) {
                            selectedNoiseRating = rating
                        }
                    }
                } label: {
                    FilterChip(
                        title: selectedNoiseRating?.displayName ?? "Noise",
                        icon: "speaker.wave.2",
                        isActive: selectedNoiseRating != nil,
                        color: ThemeManager.Colors.warning
                    )
                }
                .accessibilityLabel("Noise level filter: \(selectedNoiseRating?.displayName ?? "All levels")")
                
                // Outlets Filter
                Button(action: { outletsOnly.toggle() }) {
                    FilterChip(
                        title: "Outlets",
                        icon: "powerplug",
                        isActive: outletsOnly,
                        color: ThemeManager.Colors.success
                    )
                }
                .accessibilityLabel("Outlets filter: \(outletsOnly ? "Only spots with outlets" : "All spots")")
                
                // Advanced Filters Button
                Button(action: { showingFilters = true }) {
                    FilterChip(
                        title: "More",
                        icon: "line.3.horizontal.decrease.circle",
                        isActive: false,
                        color: ThemeManager.Colors.textSecondary
                    )
                }
                .accessibilityLabel("Open advanced filters")
            }
            .padding(.horizontal, ThemeManager.Spacing.md)
        }
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let icon: String
    let isActive: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(ThemeManager.Typography.dynamicCaption())
                .foregroundColor(isActive ? color : ThemeManager.Colors.textSecondary)
            
            Text(title)
                .font(ThemeManager.Typography.dynamicCaption())
                .fontWeight(.medium)
                .foregroundColor(isActive ? color : ThemeManager.Colors.textSecondary)
        }
        .padding(.horizontal, ThemeManager.Spacing.sm)
        .padding(.vertical, ThemeManager.Spacing.xs)
        .background(isActive ? color.opacity(0.15) : ThemeManager.Colors.surface)
        .cornerRadius(ThemeManager.CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.sm)
                .stroke(isActive ? color : ThemeManager.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Search Results View
struct SpotSearchResultsView: View {
    let spots: [Spot]
    let viewModel: SpotViewModel
    let locationService: LocationService
    let sortByRatingOnly: Bool
    
    var body: some View {
        List {
            ForEach(spots, id: \.objectID) { spot in
                NavigationLink(destination: SpotDetailView(spot: spot, viewModel: viewModel)) {
                    SpotSearchResultRow(
                        spot: spot, 
                        viewModel: viewModel,
                        locationService: locationService,
                        sortByRatingOnly: sortByRatingOnly
                    )
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Search Result Row
struct SpotSearchResultRow: View {
    let spot: Spot
    let viewModel: SpotViewModel
    let locationService: LocationService
    let sortByRatingOnly: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
            // Header row with name and overall rating
            HStack {
                Text(spot.name ?? "Unknown Spot")
                    .font(ThemeManager.Typography.dynamicHeadline())
                    .foregroundColor(ThemeManager.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                // Overall rating stars with distance
                HStack(spacing: ThemeManager.Spacing.sm) {
                    OverallRatingStarsView(rating: viewModel.overallRating(for: spot))
                    
                    if !sortByRatingOnly, let distance = locationService.getFormattedDistance(from: spot) {
                        Text(distance)
                            .font(ThemeManager.Typography.dynamicCaption())
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                            .accessibilityLabel("Distance: \(distance)")
                    }
                }
            }
            
            // Address
            Text(spot.address ?? "No address")
                .font(ThemeManager.Typography.dynamicSubheadline())
                .foregroundColor(ThemeManager.Colors.textSecondary)
                .lineLimit(2)
            
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
            }
            
            // Detailed information row
            SpotDetailsRowView(spot: spot)
        }
        .padding(.vertical, ThemeManager.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            locationService.requestLocationPermission()
        }
    }
    
    private var accessibilityLabel: String {
        let name = spot.name ?? "Unknown Spot"
        let address = spot.address ?? "No address"
        let rating = viewModel.overallRating(for: spot)
        let ratingText = String(format: "%.1f out of 5 quality stars", rating)
        let noise = spot.noiseRating ?? "Unknown"
        let outlets = spot.outlets ? "Yes" : "No"
        let wifiStars = String(repeating: "★", count: Int(spot.wifiRating)) + String(repeating: "☆", count: 5 - Int(spot.wifiRating))
        
        var distanceText = ""
        if !sortByRatingOnly, let distance = locationService.getFormattedDistance(from: spot) {
            distanceText = ", \(distance) away"
        }
        
        return "\(name) at \(address). \(ratingText). WiFi rating: \(wifiStars). Noise level: \(noise). Outlets available: \(outlets)\(distanceText)"
    }
}


// MARK: - Filter Detail View
struct FilterDetailView: View {
    @Binding var selectedWifiRating: Int16
    @Binding var selectedNoiseRating: NoiseRating?
    @Binding var outletsOnly: Bool
    @Binding var selectedOverallRating: Double
    @Binding var selectedCity: String
    @Binding var sortByRatingOnly: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ThemeManager.Spacing.lg) {
                    // Header
                    VStack(spacing: ThemeManager.Spacing.sm) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(ThemeManager.Colors.accent)
                        
                        Text("Advanced Filters")
                            .font(ThemeManager.Typography.dynamicTitle2())
                            .foregroundColor(ThemeManager.Colors.textPrimary)
                        
                        Text("Customize your search to find the perfect work spot")
                            .font(ThemeManager.Typography.dynamicSubheadline())
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, ThemeManager.Spacing.lg)
                    
                    VStack(spacing: ThemeManager.Spacing.lg) {
                        // City Selection
                        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                            HStack {
                                Image(systemName: "location")
                                    .foregroundColor(ThemeManager.Colors.primary)
                                Text("City")
                                    .font(ThemeManager.Typography.dynamicHeadline())
                                    .foregroundColor(ThemeManager.Colors.textPrimary)
                            }
                            
                            Picker("City", selection: $selectedCity) {
                                Text("Boise").tag("Boise")
                                Text("Austin").tag("Austin")
                                Text("Seattle").tag("Seattle")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .accessibilityLabel("City picker")
                        }
                        .padding()
                        .background(ThemeManager.Colors.surface)
                        .cornerRadius(ThemeManager.CornerRadius.md)
                        
                        // Sort Options
                        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                            HStack {
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundColor(ThemeManager.Colors.accent)
                                Text("Sort By")
                                    .font(ThemeManager.Typography.dynamicHeadline())
                                    .foregroundColor(ThemeManager.Colors.textPrimary)
                            }
                            
                            VStack(spacing: ThemeManager.Spacing.sm) {
                                Button(action: { sortByRatingOnly = false }) {
                                    HStack {
                                        Image(systemName: sortByRatingOnly ? "circle" : "checkmark.circle.fill")
                                            .foregroundColor(ThemeManager.Colors.accent)
                                        Text("Distance & Rating")
                                            .font(ThemeManager.Typography.dynamicBody())
                                            .foregroundColor(ThemeManager.Colors.textPrimary)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: { sortByRatingOnly = true }) {
                                    HStack {
                                        Image(systemName: sortByRatingOnly ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(ThemeManager.Colors.accent)
                                        Text("Rating Only")
                                            .font(ThemeManager.Typography.dynamicBody())
                                            .foregroundColor(ThemeManager.Colors.textPrimary)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                        .background(ThemeManager.Colors.surface)
                        .cornerRadius(ThemeManager.CornerRadius.md)
                        
                        // Overall Rating Filter
                        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(ThemeManager.Colors.accent)
                                Text("Overall Quality Rating")
                                    .font(ThemeManager.Typography.dynamicHeadline())
                                    .foregroundColor(ThemeManager.Colors.textPrimary)
                            }
                            
                            VStack(spacing: ThemeManager.Spacing.sm) {
                                HStack {
                                    Text("Minimum Rating")
                                        .font(ThemeManager.Typography.dynamicBody())
                                        .foregroundColor(ThemeManager.Colors.textSecondary)
                                    
                                    Spacer()
                                    
                                    Text(String(format: "%.1f stars", selectedOverallRating))
                                        .font(ThemeManager.Typography.dynamicHeadline())
                                        .foregroundColor(ThemeManager.Colors.accent)
                                }
                                
                                Slider(value: $selectedOverallRating, in: 1.0...5.0, step: 0.5)
                                    .accentColor(ThemeManager.Colors.accent)
                                    .accessibilityLabel("Overall rating slider")
                                    .accessibilityValue("\(String(format: "%.1f", selectedOverallRating)) stars")
                            }
                        }
                        .padding()
                        .background(ThemeManager.Colors.surface)
                        .cornerRadius(ThemeManager.CornerRadius.md)
                        
                        // WiFi Rating Filter
                        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                            HStack {
                                Image(systemName: "wifi")
                                    .foregroundColor(ThemeManager.Colors.primary)
                                Text("WiFi Quality")
                                    .font(ThemeManager.Typography.dynamicHeadline())
                                    .foregroundColor(ThemeManager.Colors.textPrimary)
                            }
                            
                            Picker("Minimum WiFi Rating", selection: $selectedWifiRating) {
                                ForEach(1...5, id: \.self) { rating in
                                    Text("\(rating) Star\(rating == 1 ? "" : "s")")
                                        .tag(Int16(rating))
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .accessibilityLabel("WiFi rating picker")
                        }
                        .padding()
                        .background(ThemeManager.Colors.surface)
                        .cornerRadius(ThemeManager.CornerRadius.md)
                        
                        // Noise Level Filter
                        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                            HStack {
                                Image(systemName: "speaker.wave.2")
                                    .foregroundColor(ThemeManager.Colors.warning)
                                Text("Noise Level")
                                    .font(ThemeManager.Typography.dynamicHeadline())
                                    .foregroundColor(ThemeManager.Colors.textPrimary)
                            }
                            
                            Picker("Noise Level", selection: $selectedNoiseRating) {
                                Text("All Levels").tag(NoiseRating?.none)
                                ForEach(NoiseRating.allCases) { rating in
                                    Text(rating.displayName).tag(NoiseRating?.some(rating))
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .accessibilityLabel("Noise level picker")
                        }
                        .padding()
                        .background(ThemeManager.Colors.surface)
                        .cornerRadius(ThemeManager.CornerRadius.md)
                        
                        // Amenities Filter
                        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                            HStack {
                                Image(systemName: "powerplug")
                                    .foregroundColor(ThemeManager.Colors.success)
                                Text("Amenities")
                                    .font(ThemeManager.Typography.dynamicHeadline())
                                    .foregroundColor(ThemeManager.Colors.textPrimary)
                            }
                            
                            Toggle("Outlets Available", isOn: $outletsOnly)
                                .font(ThemeManager.Typography.dynamicBody())
                                .accessibilityLabel("Outlets available toggle")
                        }
                        .padding()
                        .background(ThemeManager.Colors.surface)
                        .cornerRadius(ThemeManager.CornerRadius.md)
                        
                        // Reset Button
                        Button(action: resetFilters) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Reset All Filters")
                            }
                            .font(ThemeManager.Typography.dynamicHeadline())
                            .foregroundColor(ThemeManager.Colors.error)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ThemeManager.Colors.error.opacity(0.1))
                            .cornerRadius(ThemeManager.CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.md)
                                    .stroke(ThemeManager.Colors.error, lineWidth: 1)
                            )
                        }
                        .accessibilityLabel("Reset all filters")
                        .accessibilityHint("Double tap to clear all filter selections")
                    }
                    .padding(.horizontal, ThemeManager.Spacing.md)
                }
            }
            .background(ThemeManager.Colors.background)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(ThemeManager.Typography.dynamicHeadline())
                    .foregroundColor(ThemeManager.Colors.primary)
                }
            }
        }
    }
    
    private func resetFilters() {
        selectedWifiRating = 1
        selectedNoiseRating = nil
        outletsOnly = false
        selectedOverallRating = 1.0
        selectedCity = "Boise"
        sortByRatingOnly = false
    }
}

#Preview {
    SpotSearchView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}