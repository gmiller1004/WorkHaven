//
//  AddSpotView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import CoreLocation

struct AddSpotView: View {
    let viewModel: SpotViewModel
    let locationService: LocationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var address = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var wifiRating: Int16 = 3
    @State private var noiseRating = NoiseRating.medium
    @State private var outlets = false
    @State private var tips = ""
    @State private var photoURL = ""
    @State private var useCurrentLocation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                }
                
                Section("Location") {
                    Toggle("Use Current Location", isOn: $useCurrentLocation)
                        .onChange(of: useCurrentLocation) { isOn in
                            if isOn {
                                if let location = locationService.currentLocation {
                                    latitude = String(location.coordinate.latitude)
                                    longitude = String(location.coordinate.longitude)
                                } else {
                                    locationService.startLocationUpdates()
                                }
                            }
                        }
                    
                    HStack {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.decimalPad)
                        TextField("Longitude", text: $longitude)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section("Ratings") {
                    VStack(alignment: .leading) {
                        Text("WiFi Rating: \(wifiRating)")
                        Slider(value: Binding(
                            get: { Double(wifiRating) },
                            set: { wifiRating = Int16($0) }
                        ), in: 1...5, step: 1)
                    }
                    
                    Picker("Noise Level", selection: $noiseRating) {
                        ForEach(NoiseRating.allCases) { rating in
                            Text(rating.displayName).tag(rating)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Amenities") {
                    Toggle("Outlets Available", isOn: $outlets)
                }
                
                Section("Additional Information") {
                    TextField("Tips (optional)", text: $tips, axis: .vertical)
                        .lineLimit(3...6)
                    
                    TextField("Photo URL (optional)", text: $photoURL)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("Add New Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSpot()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .onAppear {
            locationService.requestLocationPermission()
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && 
        !address.isEmpty && 
        !latitude.isEmpty && 
        !longitude.isEmpty &&
        Double(latitude) != nil &&
        Double(longitude) != nil
    }
    
    private func saveSpot() {
        guard let lat = Double(latitude),
              let lon = Double(longitude) else { return }
        
        viewModel.addSpot(
            name: name,
            address: address,
            latitude: lat,
            longitude: lon,
            wifiRating: wifiRating,
            noiseRating: noiseRating.rawValue,
            outlets: outlets,
            tips: tips.isEmpty ? nil : tips,
            photoURL: photoURL.isEmpty ? nil : photoURL
        )
        
        dismiss()
    }
}

#Preview {
    AddSpotView(
        viewModel: SpotViewModel(context: PersistenceController.preview.container.viewContext),
        locationService: LocationService()
    )
}
