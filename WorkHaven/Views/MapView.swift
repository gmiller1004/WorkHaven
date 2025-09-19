//
//  MapView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import MapKit
import CoreData

struct MapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Spot.name, ascending: true)],
        animation: .default
    )
    private var spots: FetchedResults<Spot>
    
    @StateObject private var locationService = LocationService()
    @State private var region: MKCoordinateRegion
    @State private var selectedSpot: Spot?
    @State private var showingLocationAlert = false
    
    // Boise, ID coordinates as default
    private let boiseCoordinates = CLLocationCoordinate2D(latitude: 43.6150, longitude: -116.2023)
    
    init() {
        // Initialize with Boise, ID as default center
        self._region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 43.6150, longitude: -116.2023),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        ))
    }
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: Array(spots)) { spot in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)) {
                    SpotAnnotationView(spot: spot) {
                        selectedSpot = spot
                    }
                }
            }
            .onAppear {
                setupLocation()
            }
            .onChange(of: locationService.currentLocation) { location in
                if let location = location {
                    updateRegionToUserLocation(location)
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: centerOnUserLocation) {
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding(.trailing)
                }
                .padding(.top)
                
                Spacer()
            }
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot, viewModel: SpotViewModel(context: viewContext))
        }
        .alert("Location Access", isPresented: $showingLocationAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Location access is required to center the map on your current location. Please enable location access in Settings.")
        }
    }
    
    private func setupLocation() {
        locationService.requestLocationPermission()
        if locationService.authorizationStatus == .authorizedWhenInUse || 
           locationService.authorizationStatus == .authorizedAlways {
            locationService.startLocationUpdates()
        }
    }
    
    private func centerOnUserLocation() {
        if let location = locationService.currentLocation {
            updateRegionToUserLocation(location)
        } else if locationService.authorizationStatus == .denied || 
                  locationService.authorizationStatus == .restricted {
            showingLocationAlert = true
        } else {
            locationService.requestLocationPermission()
            locationService.startLocationUpdates()
        }
    }
    
    private func updateRegionToUserLocation(_ location: CLLocation) {
        withAnimation(.easeInOut(duration: 1.0)) {
            region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
}

// MARK: - Spot Annotation View
struct SpotAnnotationView: View {
    let spot: Spot
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(spotColor)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                
                Image(systemName: "wifi")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(spot.name ?? "")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 2)
                .lineLimit(1)
                .frame(maxWidth: 80)
        }
        .onTapGesture {
            onTap()
        }
    }
    
    private var spotColor: Color {
        switch spot.wifiRating {
        case 5:
            return .green
        case 4:
            return .blue
        case 3:
            return .yellow
        case 2:
            return .orange
        default:
            return .red
        }
    }
}

#Preview {
    MapView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
