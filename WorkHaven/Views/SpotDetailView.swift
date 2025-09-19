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
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(spot.name ?? "")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(spot.address ?? "")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // Photo Section
                if spot.hasPhoto, let photoURL = spot.photoURL {
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            )
                    }
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                }
                
                // Ratings and Info
                VStack(alignment: .leading, spacing: 12) {
                    // WiFi Rating
                    HStack {
                        Text("WiFi Rating:")
                            .fontWeight(.semibold)
                        Text(spot.wifiRatingStars)
                            .foregroundColor(.yellow)
                        Spacer()
                    }
                    
                    // Noise Rating
                    HStack {
                        Text("Noise Level:")
                            .fontWeight(.semibold)
                        Text(spot.noiseRating ?? "Low")
                        Spacer()
                    }
                    
                    // Outlets
                    HStack {
                        Text("Outlets:")
                            .fontWeight(.semibold)
                        Image(systemName: spot.outlets ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(spot.outlets ? .green : .red)
                        Text(spot.outlets ? "Available" : "Not Available")
                        Spacer()
                    }
                    
                    // Distance
                    if let distance = locationService.getFormattedDistance(from: spot) {
                        HStack {
                            Text("Distance:")
                                .fontWeight(.semibold)
                            Text(distance)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Community Ratings Section
                AverageRatingsView(spot: spot)
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Rate This Spot Button
                    Button(action: {
                        showingRatingForm = true
                    }) {
                        HStack {
                            Image(systemName: "star.fill")
                            Text("Rate This Spot")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Share This Spot Button
                    Button(action: {
                        showingShareView = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share This Spot")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.pink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
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
                        HStack {
                            ShareButton(spot: spot)
                            
                            Button("Edit") {
                                showingEditView = true
                            }
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
