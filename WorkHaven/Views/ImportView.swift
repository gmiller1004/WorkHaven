//
//  ImportView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import CoreData

struct ImportView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var dataImporter: DataImporter
    @State private var showingClearAlert = false
    @State private var selectedCity = "Boise"
    @State private var availableCities: [String] = []
    
    init() {
        self._dataImporter = StateObject(wrappedValue: DataImporter(context: PersistenceController.shared.container.viewContext))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Import Boise Work Spaces")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Import pre-configured work spaces from Boise, ID including coffee shops, parks, and co-working spaces.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Import Status
                if dataImporter.isImporting {
                    VStack(spacing: 16) {
                        ProgressView(value: dataImporter.importProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .scaleEffect(x: 1, y: 2, anchor: .center)
                        
                        Text(dataImporter.importStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 16) {
                        Text(dataImporter.importStatus.isEmpty ? "Ready to import Boise work spaces" : dataImporter.importStatus)
                            .font(.body)
                            .foregroundColor(dataImporter.importStatus.contains("Error") ? .red : .secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // City Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select City")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Picker("City", selection: $selectedCity) {
                        ForEach(availableCities, id: \.self) { city in
                            Text(city).tag(city)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Import Button
                    Button(action: {
                        Task {
                            await dataImporter.importWorkSpaces(for: selectedCity)
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Import \(selectedCity) Work Spaces")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(dataImporter.isImporting ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(dataImporter.isImporting)
                    
                    // Import All Button
                    Button(action: {
                        Task {
                            await dataImporter.importAllAvailableCities()
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.on.square")
                            Text("Import All Cities")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(dataImporter.isImporting)
                    
                    // Clear All Button
                    Button(action: {
                        showingClearAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Spots")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .disabled(dataImporter.isImporting)
                }
                .padding(.horizontal)
                
                // Info Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("What will be imported:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ImportInfoRow(icon: "cup.and.saucer", text: "Coffee shops and cafes")
                        ImportInfoRow(icon: "tree", text: "Parks and outdoor spaces")
                        ImportInfoRow(icon: "building.2", text: "Co-working spaces")
                        ImportInfoRow(icon: "wifi", text: "WiFi ratings and noise levels")
                        ImportInfoRow(icon: "location", text: "Exact coordinates for mapping")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 20)
            .onAppear {
                availableCities = dataImporter.getAvailableCities()
                if availableCities.isEmpty {
                    availableCities = ["Boise"] // Fallback
                }
            }
            .navigationTitle("Data Import")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Clear All Spots", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    Task {
                        await dataImporter.clearAllSpots()
                    }
                }
            } message: {
                Text("This will permanently delete all existing spots. This action cannot be undone.")
            }
        }
    }
}

struct ImportInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

#Preview {
    ImportView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
