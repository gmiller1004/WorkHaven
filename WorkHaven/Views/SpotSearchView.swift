//
//  SpotSearchView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import CoreData

struct SpotSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var selectedWifiRating: Int16 = 1
    @State private var selectedNoiseRating: NoiseRating? = nil
    @State private var outletsOnly = false
    @State private var showingFilters = false
    @State private var filteredSpots: [Spot] = []
    
    // Dynamic fetch request that updates based on filters
    private var fetchRequest: NSFetchRequest<Spot> {
        let request: NSFetchRequest<Spot> = Spot.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
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
        
        // Sort by name
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Spot.name, ascending: true)]
        
        return request
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Filter Toggle Bar
                FilterToggleBar(
                    selectedWifiRating: $selectedWifiRating,
                    selectedNoiseRating: $selectedNoiseRating,
                    outletsOnly: $outletsOnly,
                    showingFilters: $showingFilters
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Results List
                SpotSearchResultsView(spots: filteredSpots)
            }
            .navigationTitle("Search Spots")
            .onAppear {
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
            .sheet(isPresented: $showingFilters) {
                FilterDetailView(
                    selectedWifiRating: $selectedWifiRating,
                    selectedNoiseRating: $selectedNoiseRating,
                    outletsOnly: $outletsOnly
                )
            }
        }
    }
    
    private func updateFilteredSpots() {
        do {
            filteredSpots = try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching spots: \(error)")
            filteredSpots = []
        }
    }
}

// MARK: - Search Bar Component
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search spots...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Filter Toggle Bar
struct FilterToggleBar: View {
    @Binding var selectedWifiRating: Int16
    @Binding var selectedNoiseRating: NoiseRating?
    @Binding var outletsOnly: Bool
    @Binding var showingFilters: Bool
    
    var body: some View {
        HStack(spacing: 12) {
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
                    isActive: selectedWifiRating > 1
                )
            }
            
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
                    isActive: selectedNoiseRating != nil
                )
            }
            
            // Outlets Filter
            Button(action: { outletsOnly.toggle() }) {
                FilterChip(
                    title: "Outlets",
                    icon: "powerplug",
                    isActive: outletsOnly
                )
            }
            
            Spacer()
            
            // Advanced Filters Button
            Button(action: { showingFilters = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let icon: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isActive ? Color.blue.opacity(0.2) : Color(.systemGray5))
        .foregroundColor(isActive ? .blue : .primary)
        .cornerRadius(8)
    }
}

// MARK: - Search Results View
struct SpotSearchResultsView: View {
    let spots: [Spot]
    
    var body: some View {
        List {
            ForEach(spots, id: \.objectID) { spot in
                SpotSearchResultRow(spot: spot)
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Search Result Row
struct SpotSearchResultRow: View {
    let spot: Spot
    @StateObject private var locationService = LocationService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(spot.name ?? "")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(spot.address ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // WiFi Rating
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= Int(spot.wifiRating) ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                    }
                    
                    // Distance
                    if let distance = locationService.getFormattedDistance(from: spot) {
                        Text(distance)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Tags
            HStack(spacing: 8) {
                // Noise Level
                Label(spot.noiseRating ?? "Low", systemImage: "speaker.wave.2")
                    .font(.caption)
                    .foregroundColor(noiseColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(noiseColor.opacity(0.2))
                    .cornerRadius(4)
                
                // Outlets
                if spot.outlets {
                    Label("Outlets", systemImage: "powerplug")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            locationService.requestLocationPermission()
        }
    }
    
    private var noiseColor: Color {
        switch spot.noiseRating {
        case "Low":
            return .green
        case "Medium":
            return .orange
        case "High":
            return .red
        default:
            return .gray
        }
    }
}

// MARK: - Filter Detail View
struct FilterDetailView: View {
    @Binding var selectedWifiRating: Int16
    @Binding var selectedNoiseRating: NoiseRating?
    @Binding var outletsOnly: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("WiFi Rating") {
                    Picker("Minimum WiFi Rating", selection: $selectedWifiRating) {
                        ForEach(1...5, id: \.self) { rating in
                            Text("\(rating) Star\(rating == 1 ? "" : "s")")
                                .tag(Int16(rating))
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Noise Level") {
                    Picker("Noise Level", selection: $selectedNoiseRating) {
                        Text("All Levels").tag(NoiseRating?.none)
                        ForEach(NoiseRating.allCases) { rating in
                            Text(rating.displayName).tag(NoiseRating?.some(rating))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Amenities") {
                    Toggle("Outlets Available", isOn: $outletsOnly)
                }
                
                Section {
                    Button("Reset Filters") {
                        selectedWifiRating = 1
                        selectedNoiseRating = nil
                        outletsOnly = false
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SpotSearchView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
