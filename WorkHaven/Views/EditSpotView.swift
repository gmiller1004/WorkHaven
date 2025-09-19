//
//  EditSpotView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI

struct EditSpotView: View {
    let spot: Spot
    let viewModel: SpotViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var address: String
    @State private var latitude: String
    @State private var longitude: String
    @State private var wifiRating: Int16
    @State private var noiseRating: NoiseRating
    @State private var outlets: Bool
    @State private var tips: String
    @State private var photoURL: String
    
    init(spot: Spot, viewModel: SpotViewModel) {
        self.spot = spot
        self.viewModel = viewModel
        
        _name = State(initialValue: spot.name ?? "")
        _address = State(initialValue: spot.address ?? "")
        _latitude = State(initialValue: String(spot.latitude))
        _longitude = State(initialValue: String(spot.longitude))
        _wifiRating = State(initialValue: spot.wifiRating)
        _noiseRating = State(initialValue: NoiseRating(rawValue: spot.noiseRating ?? "Low") ?? .medium)
        _outlets = State(initialValue: spot.outlets)
        _tips = State(initialValue: spot.tips ?? "")
        _photoURL = State(initialValue: spot.photoURL ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                }
                
                Section("Location") {
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
            .navigationTitle("Edit Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!isFormValid)
                }
            }
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
    
    private func saveChanges() {
        spot.name = name
        spot.address = address
        spot.latitude = Double(latitude) ?? spot.latitude
        spot.longitude = Double(longitude) ?? spot.longitude
        spot.wifiRating = wifiRating
        spot.noiseRating = noiseRating.rawValue
        spot.outlets = outlets
        spot.tips = tips.isEmpty ? nil : tips
        spot.photoURL = photoURL.isEmpty ? nil : photoURL
        
        viewModel.updateSpot(spot)
        dismiss()
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let spot = Spot.createSampleSpot(in: context)
    return EditSpotView(spot: spot, viewModel: SpotViewModel(context: context))
}
