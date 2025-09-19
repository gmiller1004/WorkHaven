//
//  MapView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import MapKit

struct MapView: View {
    let spots: [Spot]
    @State private var region: MKCoordinateRegion
    @State private var selectedSpot: Spot?
    
    init(spots: [Spot], center: CLLocationCoordinate2D? = nil) {
        self.spots = spots
        
        if let center = center {
            self._region = State(initialValue: MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else if let firstSpot = spots.first {
            self._region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: firstSpot.latitude, longitude: firstSpot.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            // Default to San Francisco
            self._region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: spots) { spot in
            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)) {
                VStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    
                    Text(spot.name ?? "")
                        .font(.caption)
                        .padding(4)
                        .background(Color.white)
                        .cornerRadius(4)
                        .shadow(radius: 2)
                }
                .onTapGesture {
                    selectedSpot = spot
                }
            }
        }
        .sheet(item: $selectedSpot) { spot in
            SpotDetailView(spot: spot, viewModel: SpotViewModel(context: PersistenceController.shared.container.viewContext))
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let spots = [
        Spot.createSampleSpot(in: context)
    ]
    return MapView(spots: spots)
}
