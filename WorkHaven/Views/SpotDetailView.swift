//
//  SpotDetailView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//  Updated with comprehensive rating breakdown, progress bars, enhanced user rating functionality,
//  and location verification using GeocodingService for accurate coordinates
//

import SwiftUI
import MapKit

struct SpotDetailView: View {
    let spot: Spot
    let viewModel: SpotViewModel
    @StateObject private var locationService = LocationService()
    @StateObject private var geocodingService = GeocodingService.shared
    @State private var showingEditView = false
    @State private var showingRatingForm = false
    @State private var showingShareView = false
    @State private var userRating: Int16 = 0
    @State private var userTips: String = ""
    @State private var isEditingTips = false
    @State private var showingSaveAlert = false
    @State private var saveMessage = ""
    
    // Location verification states
    @State private var isVerifyingLocation = false
    @State private var showingLocationPicker = false
    @State private var geocodedPlacemarks: [CLPlacemark] = []
    @State private var showingLocationError = false
    @State private var locationErrorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
                // Header
                VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                    Text(spot.name ?? "Unknown Spot")
                        .font(ThemeManager.Typography.dynamicTitle2())
                        .fontWeight(.bold)
                        .foregroundColor(ThemeManager.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .accessibilityLabel("Spot name: \(spot.name ?? "Unknown Spot")")
                    
                    Text(spot.address ?? "No address")
                        .font(ThemeManager.Typography.dynamicTitle3())
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .accessibilityLabel("Address: \(spot.address ?? "No address")")
                }
                
                // Overall Rating Section
                OverallRatingSection(spot: spot, viewModel: viewModel)
                
                // Rating Breakdown Section
                RatingBreakdownSection(spot: spot, viewModel: viewModel)
                
                // Photo Section
                if spot.hasPhoto, let photoURL = spot.photoURL {
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .fill(ThemeManager.Colors.background)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(ThemeManager.Typography.dynamicTitle2())
                                    .foregroundColor(ThemeManager.Colors.textSecondary)
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: 200)
                    .clipped()
                    .cornerRadius(ThemeManager.CornerRadius.lg)
                    .accessibilityLabel("Spot photo")
                }
                
                // Basic Info Section
                BasicInfoSection(spot: spot, locationService: locationService)
                
                // Community Ratings Section
                if spot.userRatingCount > 0 {
                    CommunityRatingsSection(spot: spot, viewModel: viewModel)
                }
                
                // User Rating Section
                UserRatingSection(
                    spot: spot,
                    userRating: $userRating,
                    userTips: $userTips,
                    isEditingTips: $isEditingTips,
                    showingRatingForm: $showingRatingForm
                )
                
                // Original Tips Section (if exists)
                if let tips = spot.tips, !tips.isEmpty {
                    OriginalTipsSection(tips: tips)
                }
                
                // Map Section with Location Verification
                MapSectionWithVerification(
                    spot: spot,
                    openInAppleMaps: openInAppleMaps,
                    isVerifyingLocation: $isVerifyingLocation,
                    showingLocationPicker: $showingLocationPicker,
                    geocodedPlacemarks: $geocodedPlacemarks,
                    verifyLocation: verifyLocation
                )
            }
            .padding(.horizontal, ThemeManager.Spacing.md)
            .padding(.vertical, ThemeManager.Spacing.sm)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditView = true
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            EditSpotView(spot: spot, viewModel: viewModel)
        }
        .sheet(isPresented: $showingRatingForm) {
            UserRatingForm(spot: spot, viewModel: viewModel)
        }
        .sheet(isPresented: $showingShareView) {
            SpotShareView(spot: spot)
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerSheet(
                placemarks: geocodedPlacemarks,
                onSelect: selectLocation,
                onCancel: { showingLocationPicker = false }
            )
        }
        .onAppear {
            locationService.requestLocationPermission()
            loadUserData()
            configureGeocodingService()
        }
        .alert("Saved", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text(saveMessage)
        }
        .alert("Location Verification Failed", isPresented: $showingLocationError) {
            Button("OK") { }
        } message: {
            Text(locationErrorMessage)
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadUserData() {
        // Load existing user rating and tips from Core Data
        // For now, we'll initialize with empty values
        // In a real app, you might want to store user-specific data
        userRating = 0
        userTips = ""
    }
    
    private func configureGeocodingService() {
        Task {
            await geocodingService.configure(with: spot.managedObjectContext!)
        }
    }
    
    private func verifyLocation() {
        guard let address = spot.address, !address.isEmpty else {
            locationErrorMessage = "No address available for verification"
            showingLocationError = true
            return
        }
        
        isVerifyingLocation = true
        
        Task {
            do {
                let placemarks = try await geocodingService.geocodeAddress(address)
                
                await MainActor.run {
                    isVerifyingLocation = false
                    
                    if placemarks.count == 1 {
                        // Single result - update directly
                        selectLocation(placemarks[0])
                    } else if placemarks.count > 1 {
                        // Multiple results - show picker
                        geocodedPlacemarks = placemarks
                        showingLocationPicker = true
                    } else {
                        // No results
                        locationErrorMessage = "No location found for this address. Using approximate location."
                        showingLocationError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isVerifyingLocation = false
                    locationErrorMessage = "Verification failed—using approximate location"
                    showingLocationError = true
                }
            }
        }
    }
    
    private func selectLocation(_ placemark: CLPlacemark) {
        guard let location = placemark.location else { return }
        
        // Update spot coordinates
        spot.latitude = location.coordinate.latitude
        spot.longitude = location.coordinate.longitude
        spot.lastModified = Date()
        
        // Save to Core Data
        do {
            try spot.managedObjectContext?.save()
            
            // Trigger CloudKit sync
            Task {
                // Note: CloudKit sync will be handled by the app's CloudKitManager instance
                // This is a placeholder for future CloudKit integration
            }
            
            saveMessage = "Location updated successfully"
            showingSaveAlert = true
        } catch {
            locationErrorMessage = "Failed to save updated location"
            showingLocationError = true
        }
    }
    
    private func openInAppleMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = spot.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - Map Section with Location Verification

struct MapSectionWithVerification: View {
    let spot: Spot
    let openInAppleMaps: () -> Void
    @Binding var isVerifyingLocation: Bool
    @Binding var showingLocationPicker: Bool
    @Binding var geocodedPlacemarks: [CLPlacemark]
    let verifyLocation: () -> Void
    
    @State private var region: MKCoordinateRegion
    @State private var hasInitialized = false
    
    init(spot: Spot, openInAppleMaps: @escaping () -> Void, isVerifyingLocation: Binding<Bool>, showingLocationPicker: Binding<Bool>, geocodedPlacemarks: Binding<[CLPlacemark]>, verifyLocation: @escaping () -> Void) {
        self.spot = spot
        self.openInAppleMaps = openInAppleMaps
        self._isVerifyingLocation = isVerifyingLocation
        self._showingLocationPicker = showingLocationPicker
        self._geocodedPlacemarks = geocodedPlacemarks
        self.verifyLocation = verifyLocation
        // Initialize with spot coordinates
        self._region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
            Text("Location")
                .font(ThemeManager.Typography.dynamicHeadline())
                .fontWeight(.semibold)
                .foregroundColor(ThemeManager.Colors.textPrimary)
            
            Map(coordinateRegion: $region, annotationItems: [spot]) { spot in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)) {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(ThemeManager.Colors.accent)
                        
                        Text(spot.name ?? "Work Spot")
                            .font(ThemeManager.Typography.dynamicCaption())
                            .fontWeight(.semibold)
                            .padding(.horizontal, ThemeManager.Spacing.sm)
                            .padding(.vertical, ThemeManager.Spacing.xs)
                            .background(ThemeManager.Colors.surface)
                            .cornerRadius(ThemeManager.CornerRadius.sm)
                            .shadow(
                                color: ThemeManager.Shadows.sm.color,
                                radius: ThemeManager.Shadows.sm.radius,
                                x: ThemeManager.Shadows.sm.x,
                                y: ThemeManager.Shadows.sm.y
                            )
                    }
                }
            }
            .frame(height: 200)
            .cornerRadius(ThemeManager.CornerRadius.lg)
            .onAppear {
                if !hasInitialized {
                    // Set initial region to spot location
                    region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    hasInitialized = true
                }
            }
            .accessibilityLabel("Map showing spot location")
            .accessibilityHint("Pinch to zoom, drag to pan around the area")
            
            // Action Buttons
            VStack(spacing: ThemeManager.Spacing.sm) {
                // Navigate to Spot Button
                Button(action: openInAppleMaps) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Navigate to Spot")
                    }
                    .themedButton(style: .primary)
                }
                .accessibilityLabel("Navigate to spot")
                .accessibilityHint("Double tap to open Apple Maps with navigation to this spot")
                
                // Verify Location Button
                Button(action: verifyLocation) {
                    HStack {
                        if isVerifyingLocation {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.Colors.surface))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "location.magnifyingglass")
                        }
                        Text(isVerifyingLocation ? "Verifying..." : "Verify Location")
                    }
                    .font(ThemeManager.Typography.dynamicBody())
                    .foregroundColor(ThemeManager.Colors.surface)
                    .padding(.horizontal, ThemeManager.Spacing.lg)
                    .padding(.vertical, ThemeManager.Spacing.md)
                    .background(ThemeManager.Colors.primary)
                    .cornerRadius(ThemeManager.CornerRadius.md)
                    .shadow(
                        color: ThemeManager.Shadows.sm.color,
                        radius: ThemeManager.Shadows.sm.radius,
                        x: ThemeManager.Shadows.sm.x,
                        y: ThemeManager.Shadows.sm.y
                    )
                }
                .disabled(isVerifyingLocation)
                .accessibilityLabel("Verify spot location on map")
                .accessibilityHint("Double tap to geocode the address and update coordinates")
            }
        }
    }
}

// MARK: - Location Picker Sheet

struct LocationPickerSheet: View {
    let placemarks: [CLPlacemark]
    let onSelect: (CLPlacemark) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
                Text("Multiple locations found for this address. Please select the correct one:")
                    .font(ThemeManager.Typography.dynamicBody())
                    .foregroundColor(ThemeManager.Colors.textSecondary)
                    .padding(.horizontal, ThemeManager.Spacing.md)
                
                List(placemarks.indices, id: \.self) { index in
                    LocationPickerRow(
                        placemark: placemarks[index],
                        onSelect: {
                            onSelect(placemarks[index])
                        }
                    )
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

// MARK: - Location Picker Row

struct LocationPickerRow: View {
    let placemark: CLPlacemark
    let onSelect: () -> Void
    
    private var formattedAddress: String {
        var components: [String] = []
        
        if let name = placemark.name { components.append(name) }
        if let thoroughfare = placemark.thoroughfare { components.append(thoroughfare) }
        if let locality = placemark.locality { components.append(locality) }
        if let administrativeArea = placemark.administrativeArea { components.append(administrativeArea) }
        if let country = placemark.country { components.append(country) }
        
        return components.joined(separator: ", ")
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
                    Text(formattedAddress)
                        .font(ThemeManager.Typography.dynamicBody())
                        .foregroundColor(ThemeManager.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    if let location = placemark.location {
                        Text("Lat: \(String(format: "%.4f", location.coordinate.latitude)), Lng: \(String(format: "%.4f", location.coordinate.longitude))")
                            .font(ThemeManager.Typography.dynamicCaption())
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(ThemeManager.Typography.dynamicCaption())
                    .foregroundColor(ThemeManager.Colors.accent)
            }
            .padding(.vertical, ThemeManager.Spacing.sm)
            .padding(.horizontal, ThemeManager.Spacing.md)
            .background(ThemeManager.Colors.surface)
            .cornerRadius(ThemeManager.CornerRadius.sm)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Overall Rating Section

struct OverallRatingSection: View {
    let spot: Spot
    let viewModel: SpotViewModel
    
    var body: some View {
        VStack(spacing: ThemeManager.Spacing.sm) {
            Text("Overall Quality")
                .font(ThemeManager.Typography.dynamicTitle2())
                .fontWeight(.bold)
                .foregroundColor(ThemeManager.Colors.textPrimary)
            
            HStack(spacing: ThemeManager.Spacing.md) {
                // Star Rating
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(viewModel.overallRating(for: spot)) ? "star.fill" : 
                              (star == Int(viewModel.overallRating(for: spot)) + 1 && viewModel.overallRating(for: spot) - Double(Int(viewModel.overallRating(for: spot))) >= 0.5) ? "star.lefthalf.fill" : "star")
                            .foregroundColor(ThemeManager.Colors.accent)
                            .font(.title2)
                    }
                }
                
                // Rating Value and Description
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.1f", viewModel.overallRating(for: spot)))
                        .font(ThemeManager.Typography.dynamicTitle1())
                        .fontWeight(.bold)
                        .foregroundColor(ThemeManager.Colors.textPrimary)
                    
                    Text(viewModel.ratingDescription(for: viewModel.overallRating(for: spot)))
                        .font(ThemeManager.Typography.dynamicSubheadline())
                        .foregroundColor(viewModel.ratingColor(for: viewModel.overallRating(for: spot)))
                }
            }
            
            if spot.userRatingCount > 0 {
                Text("Based on \(spot.userRatingCount) user rating\(spot.userRatingCount == 1 ? "" : "s")")
                    .font(ThemeManager.Typography.dynamicCaption())
                    .foregroundColor(ThemeManager.Colors.textSecondary)
            }
        }
        .padding(ThemeManager.Spacing.lg)
        .background(ThemeManager.Colors.surface)
        .cornerRadius(ThemeManager.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.lg)
                .stroke(ThemeManager.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Rating Breakdown Section

struct RatingBreakdownSection: View {
    let spot: Spot
    let viewModel: SpotViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
            Text("Rating Breakdown")
                .font(ThemeManager.Typography.dynamicTitle3())
                .fontWeight(.bold)
                .foregroundColor(ThemeManager.Colors.textPrimary)
            
            // Default Quality
            RatingBreakdownRow(
                title: "Default Quality",
                subtitle: "Based on WiFi, Noise, and Outlets",
                rating: spot.aggregateRating,
                showStars: true,
                color: ThemeManager.Colors.primary
            )
            
            // Community Rating
            RatingBreakdownRow(
                title: "Community Rating",
                subtitle: spot.userRatingCount > 0 ? "Based on \(spot.userRatingCount) user rating\(spot.userRatingCount == 1 ? "" : "s")" : "No user ratings yet",
                rating: spot.userRatingCount > 0 ? (spot.averageUserRating ?? 0) : 0,
                showStars: spot.userRatingCount > 0,
                color: ThemeManager.Colors.accent
            )
        }
        .padding(ThemeManager.Spacing.md)
        .background(ThemeManager.Colors.surface)
        .cornerRadius(ThemeManager.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.lg)
                .stroke(ThemeManager.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Rating Breakdown Row

struct RatingBreakdownRow: View {
    let title: String
    let subtitle: String
    let rating: Double
    let showStars: Bool
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
            HStack {
                Text(title)
                    .font(ThemeManager.Typography.dynamicHeadline())
                    .foregroundColor(ThemeManager.Colors.textPrimary)
                
                Spacer()
                
                if showStars {
                    Text(String(format: "%.1f", rating))
                        .font(ThemeManager.Typography.dynamicTitle3())
                        .fontWeight(.bold)
                        .foregroundColor(color)
                }
            }
            
            Text(subtitle)
                .font(ThemeManager.Typography.dynamicCaption())
                .foregroundColor(ThemeManager.Colors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            if showStars {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(ThemeManager.Colors.background)
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(color)
                            .frame(width: geometry.size.width * (rating / 5.0), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
                
                // Star display
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(rating) ? "star.fill" : 
                              (star == Int(rating) + 1 && rating - Double(Int(rating)) >= 0.5) ? "star.lefthalf.fill" : "star")
                            .foregroundColor(ThemeManager.Colors.accent)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

// MARK: - Basic Info Section

struct BasicInfoSection: View {
    let spot: Spot
    let locationService: LocationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
            Text("Spot Details")
                .font(ThemeManager.Typography.dynamicTitle3())
                .fontWeight(.bold)
                .foregroundColor(ThemeManager.Colors.textPrimary)
            
            VStack(spacing: ThemeManager.Spacing.sm) {
                DetailRow(title: "WiFi", value: spot.wifiRatingStars, icon: "wifi")
                DetailRow(title: "Noise", value: spot.noiseRating ?? "Unknown", icon: "speaker.wave.2")
                DetailRow(title: "Outlets", value: spot.outlets ? "Available" : "Not Available", icon: "powerplug")
            }
        }
        .padding(ThemeManager.Spacing.md)
        .background(ThemeManager.Colors.surface)
        .cornerRadius(ThemeManager.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.lg)
                .stroke(ThemeManager.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(ThemeManager.Colors.primary)
                .frame(width: 20)
            
            Text(title + ":")
                .font(ThemeManager.Typography.dynamicHeadline())
                .fontWeight(.semibold)
                .foregroundColor(ThemeManager.Colors.textPrimary)
            
            Text(value)
                .font(ThemeManager.Typography.dynamicBody())
                .foregroundColor(ThemeManager.Colors.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Community Ratings Section

struct CommunityRatingsSection: View {
    let spot: Spot
    let viewModel: SpotViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
            Text("Community Ratings")
                .font(ThemeManager.Typography.dynamicTitle3())
                .fontWeight(.bold)
                .foregroundColor(ThemeManager.Colors.textPrimary)
            
            Text("Average ratings from \(spot.userRatingCount) user\(spot.userRatingCount == 1 ? "" : "s")")
                .font(ThemeManager.Typography.dynamicCaption())
                .foregroundColor(ThemeManager.Colors.textSecondary)
        }
        .padding(ThemeManager.Spacing.md)
        .background(ThemeManager.Colors.surface)
        .cornerRadius(ThemeManager.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.lg)
                .stroke(ThemeManager.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - User Rating Section

struct UserRatingSection: View {
    let spot: Spot
    @Binding var userRating: Int16
    @Binding var userTips: String
    @Binding var isEditingTips: Bool
    @Binding var showingRatingForm: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
            HStack {
                Text("Your Experience")
                    .font(ThemeManager.Typography.dynamicHeadline())
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeManager.Colors.textPrimary)
                
                Spacer()
                
                Button("Rate This Spot") {
                    showingRatingForm = true
                }
                .themedButton(style: .primary)
            }
            
            // Tips Section
            VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                HStack {
                    Text("Your Tips")
                        .font(ThemeManager.Typography.dynamicHeadline())
                        .fontWeight(.semibold)
                        .foregroundColor(ThemeManager.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(isEditingTips ? "Save" : "Add Tips") {
                        if isEditingTips {
                            // Save tips logic here
                            isEditingTips = false
                        } else {
                            isEditingTips = true
                        }
                    }
                    .themedButton(style: .secondary)
                }
                
                if isEditingTips {
                    TextField("Share your experience at this spot...", text: $userTips, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                        .font(ThemeManager.Typography.dynamicBody())
                } else if !userTips.isEmpty {
                    Text(userTips)
                        .font(ThemeManager.Typography.dynamicBody())
                        .foregroundColor(ThemeManager.Colors.textPrimary)
                        .padding(.vertical, 4)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Tap 'Add Tips' to share your experience")
                        .font(ThemeManager.Typography.dynamicBody())
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                        .italic()
                }
            }
        }
        .padding(ThemeManager.Spacing.md)
        .background(ThemeManager.Colors.surface)
        .cornerRadius(ThemeManager.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.lg)
                .stroke(ThemeManager.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Original Tips Section

struct OriginalTipsSection: View {
    let tips: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
            Text("Original Tips")
                .font(ThemeManager.Typography.dynamicHeadline())
                .fontWeight(.semibold)
                .foregroundColor(ThemeManager.Colors.textPrimary)
            
            Text(tips)
                .font(ThemeManager.Typography.dynamicBody())
                .foregroundColor(ThemeManager.Colors.textPrimary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ThemeManager.Spacing.md)
        .background(ThemeManager.Colors.surface)
        .cornerRadius(ThemeManager.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.lg)
                .stroke(ThemeManager.Colors.border, lineWidth: 1)
        )
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let spot = Spot(context: context)
    spot.name = "Sample Coffee Shop"
    spot.address = "123 Main St, Boise, ID"
    spot.latitude = 43.6150
    spot.longitude = -116.2023
    spot.wifiRating = 4
    spot.noiseRating = "Low"
    spot.outlets = true
    
    return SpotDetailView(spot: spot, viewModel: SpotViewModel(context: context))
}