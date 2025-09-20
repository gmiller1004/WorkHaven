//
//  SpotDetailView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//  Updated with comprehensive rating breakdown, progress bars, and enhanced user rating functionality
//

import SwiftUI
import MapKit

struct SpotDetailView: View {
    let spot: Spot
    let viewModel: SpotViewModel
    @StateObject private var locationService = LocationService()
    @State private var showingEditView = false
    @State private var showingRatingForm = false
    @State private var showingShareView = false
    @State private var userRating: Int16 = 0
    @State private var userTips: String = ""
    @State private var isEditingTips = false
    @State private var showingSaveAlert = false
    @State private var saveMessage = ""
    
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
                AverageRatingsView(spot: spot)
                
                // Action Buttons
                ActionButtonsSection(
                    showingRatingForm: $showingRatingForm,
                    showingShareView: $showingShareView
                )
                
                // User Tips Section
                UserTipsSection(
                    userTips: $userTips,
                    isEditingTips: $isEditingTips,
                    saveUserTips: saveUserTips
                )
                
                // Original Tips Section (if exists)
                if let tips = spot.tips, !tips.isEmpty {
                    OriginalTipsSection(tips: tips)
                }
                
                // Map Section
                MapSection(spot: spot, openInAppleMaps: openInAppleMaps)
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
        .onAppear {
            locationService.requestLocationPermission()
            loadUserData()
        }
        .alert("Saved", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text(saveMessage)
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
    
    private func openInAppleMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = spot.name ?? "Work Spot"
        
        // Open in Apple Maps with navigation
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    private func saveUserTips() {
        // Append user tips to existing tips
        let existingTips = spot.tips ?? ""
        let newTips = userTips.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !newTips.isEmpty {
            if existingTips.isEmpty {
                spot.tips = newTips
            } else {
                spot.tips = "\(existingTips)\n\n--- User Tip ---\n\(newTips)"
            }
            
            viewModel.saveContext()
            isEditingTips = false
            saveMessage = "Tips saved successfully!"
            showingSaveAlert = true
        }
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
            
            HStack(spacing: ThemeManager.Spacing.sm) {
                // Large 5-star display
                HStack(spacing: 4) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: starImageName(for: index))
                            .font(.system(size: 32))
                            .foregroundColor(ThemeManager.Colors.accent) // #F28C38
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Overall rating: \(String(format: "%.1f", viewModel.overallRating(for: spot))) out of 5 stars")
                
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
    
    private func starImageName(for index: Int) -> String {
        let rating = viewModel.overallRating(for: spot)
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
            
            VStack(spacing: ThemeManager.Spacing.md) {
                // Aggregate Rating (Default)
                RatingBreakdownRow(
                    title: "Default Quality",
                    subtitle: "Based on WiFi, Noise, and Outlets",
                    rating: spot.aggregateRating,
                    color: ThemeManager.Colors.primary
                )
                
                // User Average Rating
                if let userRating = spot.averageUserRating {
                    RatingBreakdownRow(
                        title: "Community Rating",
                        subtitle: "Based on \(spot.userRatingCount) user rating\(spot.userRatingCount == 1 ? "" : "s")",
                        rating: userRating,
                        color: ThemeManager.Colors.accent
                    )
                } else {
                    RatingBreakdownRow(
                        title: "Community Rating",
                        subtitle: "No user ratings yet",
                        rating: 0,
                        color: ThemeManager.Colors.textSecondary,
                        showStars: false
                    )
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

// MARK: - Rating Breakdown Row
struct RatingBreakdownRow: View {
    let title: String
    let subtitle: String
    let rating: Double
    let color: Color
    var showStars: Bool = true
    
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
                            .fill(ThemeManager.Colors.border)
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(color)
                            .frame(width: geometry.size.width * (rating / 5.0), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
                .accessibilityLabel("\(title): \(String(format: "%.1f", rating)) out of 5")
                
                // Star display
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: starImageName(for: index))
                            .font(.caption)
                            .foregroundColor(color)
                    }
                }
                .accessibilityLabel("\(title): \(String(format: "%.1f", rating)) out of 5 stars")
            }
        }
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
            
            VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                // WiFi Rating
                DetailRow(
                    title: "WiFi",
                    value: spot.wifiRatingStars,
                    icon: "wifi",
                    color: ThemeManager.Colors.primary
                )
                .accessibilityLabel("WiFi: \(spot.wifiRating) out of 5 stars")
                
                // Noise Rating
                DetailRow(
                    title: "Noise",
                    value: spot.noiseRating ?? "Low",
                    icon: "speaker.wave.2",
                    color: noiseColor
                )
                .accessibilityLabel("Noise level: \(spot.noiseRating ?? "Low")")
                
                // Outlets
                DetailRow(
                    title: "Outlets",
                    value: spot.outlets ? "Available" : "Not Available",
                    icon: "powerplug",
                    color: spot.outlets ? ThemeManager.Colors.success : ThemeManager.Colors.error
                )
                .accessibilityLabel("Outlets: \(spot.outlets ? "Available" : "Not Available")")
                
                // Distance
                if let distance = locationService.getFormattedDistance(from: spot) {
                    DetailRow(
                        title: "Distance",
                        value: distance,
                        icon: "location",
                        color: ThemeManager.Colors.textSecondary
                    )
                    .accessibilityLabel("Distance: \(distance)")
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
}

// MARK: - Detail Row
struct DetailRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(ThemeManager.Typography.dynamicBody())
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

// MARK: - Action Buttons Section
struct ActionButtonsSection: View {
    @Binding var showingRatingForm: Bool
    @Binding var showingShareView: Bool
    
    var body: some View {
        VStack(spacing: ThemeManager.Spacing.md) {
            // Rate This Spot Button
            Button(action: {
                showingRatingForm = true
            }) {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Rate This Spot")
                }
                .themedButton(style: .primary)
            }
            .accessibilityLabel("Rate this spot")
            .accessibilityHint("Double tap to open rating form")
            
            // Share This Spot Button
            Button(action: {
                showingShareView = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share This Spot")
                }
                .themedButton(style: .secondary)
            }
            .accessibilityLabel("Share this spot")
            .accessibilityHint("Double tap to open sharing options")
        }
    }
}

// MARK: - User Tips Section
struct UserTipsSection: View {
    @Binding var userTips: String
    @Binding var isEditingTips: Bool
    let saveUserTips: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
            HStack {
                Text("Your Tips")
                    .font(ThemeManager.Typography.dynamicHeadline())
                    .fontWeight(.semibold)
                    .foregroundColor(ThemeManager.Colors.textPrimary)
                
                Spacer()
                
                Button(isEditingTips ? "Save" : "Add Tips") {
                    if isEditingTips {
                        saveUserTips()
                    } else {
                        isEditingTips = true
                    }
                }
                .font(ThemeManager.Typography.dynamicCaption())
                .foregroundColor(ThemeManager.Colors.primary)
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

// MARK: - Map Section
struct MapSection: View {
    let spot: Spot
    let openInAppleMaps: () -> Void
    @State private var region: MKCoordinateRegion
    @State private var hasInitialized = false
    
    init(spot: Spot, openInAppleMaps: @escaping () -> Void) {
        self.spot = spot
        self.openInAppleMaps = openInAppleMaps
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
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let spot = Spot.createSampleSpot(in: context)
    return SpotDetailView(spot: spot, viewModel: SpotViewModel(context: context))
}