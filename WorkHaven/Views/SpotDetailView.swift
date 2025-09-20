//
//  SpotDetailView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
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
                        .font(ThemeManager.Typography.dynamicLargeTitle())
                        .fontWeight(.bold)
                        .foregroundColor(ThemeManager.Colors.textPrimary)
                        .accessibilityLabel("Spot name: \(spot.name ?? "Unknown Spot")")
                    
                    Text(spot.address ?? "No address")
                        .font(ThemeManager.Typography.dynamicTitle3())
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                        .accessibilityLabel("Address: \(spot.address ?? "No address")")
                }
                
                // Photo Section
                if spot.hasPhoto, let photoURL = spot.photoURL {
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(ThemeManager.Colors.background)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(ThemeManager.Typography.dynamicLargeTitle())
                                    .foregroundColor(ThemeManager.Colors.textSecondary)
                            )
                    }
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(ThemeManager.CornerRadius.lg)
                    .accessibilityLabel("Spot photo")
                }
                
                // Ratings and Info
                VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
                    // WiFi Rating
                    HStack {
                        Text("WiFi Rating:")
                            .font(ThemeManager.Typography.dynamicHeadline())
                            .fontWeight(.semibold)
                            .foregroundColor(ThemeManager.Colors.textPrimary)
                        Text(spot.wifiRatingStars)
                            .font(ThemeManager.Typography.dynamicBody())
                            .foregroundColor(ThemeManager.Colors.warning)
                        Spacer()
                    }
                    .accessibilityLabel("WiFi rating: \(spot.wifiRating) out of 5 stars")
                    
                    // Noise Rating
                    HStack {
                        Text("Noise Level:")
                            .font(ThemeManager.Typography.dynamicHeadline())
                            .fontWeight(.semibold)
                            .foregroundColor(ThemeManager.Colors.textPrimary)
                        Text(spot.noiseRating ?? "Low")
                            .font(ThemeManager.Typography.dynamicBody())
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                        Spacer()
                    }
                    .accessibilityLabel("Noise level: \(spot.noiseRating ?? "Low")")
                    
                    // Outlets
                    HStack {
                        Text("Outlets:")
                            .font(ThemeManager.Typography.dynamicHeadline())
                            .fontWeight(.semibold)
                            .foregroundColor(ThemeManager.Colors.textPrimary)
                        Image(systemName: spot.outlets ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(spot.outlets ? ThemeManager.Colors.success : ThemeManager.Colors.error)
                            .font(ThemeManager.Typography.dynamicBody())
                        Text(spot.outlets ? "Available" : "Not Available")
                            .font(ThemeManager.Typography.dynamicBody())
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                        Spacer()
                    }
                    .accessibilityLabel("Outlets: \(spot.outlets ? "Available" : "Not Available")")
                    
                    // Distance
                    if let distance = locationService.getFormattedDistance(from: spot) {
                        HStack {
                            Text("Distance:")
                                .font(ThemeManager.Typography.dynamicHeadline())
                                .fontWeight(.semibold)
                                .foregroundColor(ThemeManager.Colors.textPrimary)
                            Text(distance)
                                .font(ThemeManager.Typography.dynamicBody())
                                .foregroundColor(ThemeManager.Colors.textSecondary)
                            Spacer()
                        }
                        .accessibilityLabel("Distance: \(distance)")
                    }
                }
                .padding(ThemeManager.Spacing.md)
                .background(ThemeManager.Colors.surface)
                .cornerRadius(ThemeManager.CornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.lg)
                        .stroke(ThemeManager.Colors.border, lineWidth: 1)
                )
                
                // Community Ratings Section
                AverageRatingsView(spot: spot)
                
                // Action Buttons
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
                
                // User Tips Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your Tips")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(isEditingTips ? "Save" : "Add Tips") {
                            if isEditingTips {
                                saveUserTips()
                            } else {
                                isEditingTips = true
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    if isEditingTips {
                        TextField("Share your experience at this spot...", text: $userTips, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    } else if !userTips.isEmpty {
                        Text(userTips)
                            .font(.body)
                            .padding(.vertical, 4)
                    } else {
                        Text("Tap 'Add Tips' to share your experience")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Original Tips Section (if exists)
                if let tips = spot.tips, !tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Original Tips")
                            .font(.headline)
                        Text(tips)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Map Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location")
                        .font(.headline)
                    
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )), annotationItems: [spot]) { spot in
                        MapPin(coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude))
                    }
                    .frame(height: 200)
                    .cornerRadius(12)
                }
            }
            .padding()
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
            UserRatingForm(spot: spot)
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

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let spot = Spot.createSampleSpot(in: context)
    return SpotDetailView(spot: spot, viewModel: SpotViewModel(context: context))
}
