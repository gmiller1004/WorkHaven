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
                
                // Tips Section
                if let tips = spot.tips, !tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tips")
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
        .onAppear {
            locationService.requestLocationPermission()
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let spot = Spot.createSampleSpot(in: context)
    return SpotDetailView(spot: spot, viewModel: SpotViewModel(context: context))
}
