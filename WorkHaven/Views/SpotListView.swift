//
//  SpotListView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
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
                                SpotRowView(spot: spot, locationService: locationService)
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
            }
        }
    }
}

struct SpotRowView: View {
    let spot: Spot
    let locationService: LocationService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(spot.name ?? "")
                    .font(.headline)
                Spacer()
                Text(spot.wifiRatingStars)
                    .foregroundColor(.yellow)
            }
            
            Text(spot.address ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Label(spot.noiseRating ?? "Low", systemImage: "speaker.wave.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if spot.outlets {
                    Label("Outlets", systemImage: "powerplug")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                if let distance = locationService.getFormattedDistance(from: spot) {
                    Text(distance)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    SpotListView(context: PersistenceController.preview.container.viewContext)
}
