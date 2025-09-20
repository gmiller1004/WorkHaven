//
//  MapView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import MapKit
import CoreData
import CoreLocation

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
    @State private var hasUserInteracted = false
    @State private var hasInitialized = false
    
    // Boise, ID coordinates as default
    private let boiseCoordinates = CLLocationCoordinate2D(latitude: 43.6150, longitude: -116.2023)
    
    init() {
        // Initialize with Boise, ID as default center
        let boiseCenter = CLLocationCoordinate2D(latitude: 43.6150, longitude: -116.2023)
        print("🗺️ MapView initializing with Boise coordinates: \(boiseCenter)")
        self._region = State(initialValue: MKCoordinateRegion(
            center: boiseCenter,
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
            .accessibilityLabel("Map showing work spots")
            .accessibilityHint("Double tap to explore spots, pinch to zoom")
            .onAppear {
                setupLocation()
            }
            .onChange(of: locationService.currentLocation) { location in
                // Only auto-center on user location if user hasn't interacted with the map yet
                if let location = location, !hasUserInteracted {
                    print("📍 User location updated: \(location.coordinate)")
                    updateRegionToUserLocation(location)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { _ in
                        // Track when user starts dragging the map
                        hasUserInteracted = true
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { _ in
                        // Track when user starts zooming the map
                        hasUserInteracted = true
                    }
            )
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: centerOnUserLocation) {
                        Image(systemName: "location.fill")
                            .font(ThemeManager.Typography.dynamicTitle3())
                            .foregroundColor(ThemeManager.Colors.secondary)
                            .frame(width: 44, height: 44)
                            .background(ThemeManager.Colors.primary)
                            .clipShape(Circle())
                            .shadow(
                                color: ThemeManager.Shadows.md.color,
                                radius: ThemeManager.Shadows.md.radius,
                                x: ThemeManager.Shadows.md.x,
                                y: ThemeManager.Shadows.md.y
                            )
                    }
                    .accessibilityLabel("Center map on current location")
                    .accessibilityHint("Double tap to center the map on your current location")
                    .padding(.trailing, ThemeManager.Spacing.md)
                }
                .padding(.top, ThemeManager.Spacing.md)
                
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
            .accessibilityLabel("Open Settings")
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Location access is required to center the map on your current location. Please enable location access in Settings.")
                .font(ThemeManager.Typography.dynamicBody())
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
            // Reset user interaction flag when explicitly centering
            hasUserInteracted = false
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
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(ThemeManager.Colors.secondary, lineWidth: 2)
                    )
                
                Image(systemName: wifiIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(ThemeManager.Colors.secondary)
            }
            
            Text(spot.name ?? "Unknown Spot")
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
                .lineLimit(1)
                .frame(maxWidth: 100)
        }
        .onTapGesture {
            onTap()
        }
        .accessibilityLabel("\(spot.name ?? "Unknown spot"), WiFi rating \(spot.wifiRating) out of 5")
        .accessibilityHint("Double tap to view details")
    }
    
    private var spotColor: Color {
        switch spot.wifiRating {
        case 5:
            return ThemeManager.Colors.success
        case 4:
            return ThemeManager.Colors.primary
        case 3:
            return ThemeManager.Colors.warning
        case 2:
            return Color.orange
        default:
            return ThemeManager.Colors.error
        }
    }
    
    private var wifiIcon: String {
        switch spot.wifiRating {
        case 5:
            return "wifi"
        case 4:
            return "wifi"
        case 3:
            return "wifi"
        case 2:
            return "wifi.exclamationmark"
        default:
            return "wifi.slash"
        }
    }
}

#Preview {
    MapView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
