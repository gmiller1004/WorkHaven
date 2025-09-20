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
    @StateObject private var cloudKitManager: CloudKitManager
    @State private var showingClearAlert = false
    @State private var selectedCity = "Boise"
    @State private var availableCities: [String] = []
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        self._dataImporter = StateObject(wrappedValue: DataImporter(context: context))
        self._cloudKitManager = StateObject(wrappedValue: CloudKitManager(context: context))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 60))
                            .foregroundColor(ThemeManager.Colors.primary)
                        
                        Text("Import Boise Work Spaces")
                            .font(ThemeManager.Typography.dynamicTitle2())
                            .fontWeight(.bold)
                            .foregroundColor(ThemeManager.Colors.textPrimary)
                        
                        Text("Import pre-configured work spaces from Boise, ID including coffee shops, parks, and co-working spaces.")
                            .font(ThemeManager.Typography.dynamicBody())
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, ThemeManager.Spacing.md)
                    
                    // Import Status
                    if dataImporter.isImporting {
                        VStack(spacing: 16) {
                            ProgressView(value: dataImporter.importProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                                .tint(ThemeManager.Colors.primary)
                            
                            Text(dataImporter.importStatus)
                                .font(ThemeManager.Typography.dynamicCaption())
                                .foregroundColor(ThemeManager.Colors.textSecondary)
                        }
                        .padding(.horizontal, ThemeManager.Spacing.md)
                    } else {
                        VStack(spacing: 16) {
                            Text(dataImporter.importStatus.isEmpty ? "Ready to import Boise work spaces" : dataImporter.importStatus)
                                .font(ThemeManager.Typography.dynamicBody())
                                .foregroundColor(dataImporter.importStatus.contains("Error") ? ThemeManager.Colors.error : ThemeManager.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, ThemeManager.Spacing.md)
                    }
                    
                    // City Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select City")
                            .font(ThemeManager.Typography.dynamicHeadline())
                            .foregroundColor(ThemeManager.Colors.textPrimary)
                        
                        Picker("City", selection: $selectedCity) {
                            ForEach(availableCities, id: \.self) { city in
                                Text(city).tag(city)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(ThemeManager.Spacing.md)
                        .background(ThemeManager.Colors.background)
                        .cornerRadius(ThemeManager.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.md)
                                .stroke(ThemeManager.Colors.border, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, ThemeManager.Spacing.md)
                    
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
                            .themedButton(style: .primary)
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
                            .themedButton(style: .secondary)
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
                            .font(ThemeManager.Typography.dynamicHeadline())
                            .foregroundColor(ThemeManager.Colors.error)
                            .frame(maxWidth: .infinity)
                            .padding(ThemeManager.Spacing.md)
                            .background(ThemeManager.Colors.error.opacity(0.1))
                            .cornerRadius(ThemeManager.CornerRadius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.lg)
                                    .stroke(ThemeManager.Colors.error, lineWidth: 1)
                            )
                        }
                        .disabled(dataImporter.isImporting)
                    }
                    .padding(.horizontal, ThemeManager.Spacing.md)
                    
                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What will be imported:")
                            .font(ThemeManager.Typography.dynamicHeadline())
                            .foregroundColor(ThemeManager.Colors.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ImportInfoRow(icon: "cup.and.saucer", text: "Coffee shops and cafes")
                            ImportInfoRow(icon: "tree", text: "Parks and outdoor spaces")
                            ImportInfoRow(icon: "building.2", text: "Co-working spaces")
                            ImportInfoRow(icon: "wifi", text: "WiFi ratings and noise levels")
                            ImportInfoRow(icon: "location", text: "Exact coordinates for mapping")
                        }
                    }
                    .padding(ThemeManager.Spacing.md)
                    .background(ThemeManager.Colors.background)
                    .cornerRadius(ThemeManager.CornerRadius.lg)
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeManager.CornerRadius.lg)
                            .stroke(ThemeManager.Colors.border, lineWidth: 1)
                    )
                    .padding(.horizontal, ThemeManager.Spacing.md)
                }
                .padding(.top, ThemeManager.Spacing.md)
                .padding(.bottom, 100) // Extra padding to avoid tab bar overlap
            }
            .background(ThemeManager.Colors.background)
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
                        await cloudKitManager.clearCloudKitRecords()
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
                .foregroundColor(ThemeManager.Colors.primary)
                .frame(width: 20)
                .font(ThemeManager.Typography.dynamicBody())
            
            Text(text)
                .font(ThemeManager.Typography.dynamicSubheadline())
                .foregroundColor(ThemeManager.Colors.textSecondary)
            
            Spacer()
        }
    }
}

#Preview {
    ImportView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
