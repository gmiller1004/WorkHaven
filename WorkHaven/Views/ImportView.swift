//
//  ImportView.swift
//  WorkHaven
//
//  Import view for work spaces with geocoding integration
//

import SwiftUI

struct ImportView: View {
    @StateObject private var dataImporter: DataImporter
    @StateObject private var cloudKitManager: CloudKitManager
    @State private var showingClearAlert = false
    @State private var selectedCity = "Boise"
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        self._dataImporter = StateObject(wrappedValue: DataImporter(context: context))
        self._cloudKitManager = StateObject(wrappedValue: CloudKitManager(context: context))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ThemeManager.Spacing.lg) {
                    // Header Section
                    headerSection
                    
                    // Import Status Section
                    statusSection
                    
                    // City Selection Section
                    citySelectionSection
                    
                    // Action Buttons Section
                    actionButtonsSection
                    
                    // Import Info Section
                    importInfoSection
                }
                .padding(.horizontal, ThemeManager.Spacing.md)
                .padding(.vertical, ThemeManager.Spacing.sm)
            }
            .navigationTitle("Import Work Spaces")
            .navigationBarTitleDisplayMode(.large)
            .alert("Clear All Spots", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    Task {
                        await dataImporter.clearAllData()
                        await cloudKitManager.clearCloudKitRecords()
                    }
                }
            } message: {
                Text("This will permanently delete all spots. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: ThemeManager.Spacing.md) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 60))
                .foregroundColor(ThemeManager.Colors.primary)
            
            Text("Import Work Spaces")
                .font(ThemeManager.Typography.dynamicTitle2())
                .fontWeight(.bold)
                .foregroundColor(ThemeManager.Colors.textPrimary)
            
            Text("Import pre-configured work spaces with accurate geocoding for precise locations.")
                .font(ThemeManager.Typography.dynamicBody())
                .foregroundColor(ThemeManager.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var statusSection: some View {
        Group {
            if dataImporter.isImporting {
                VStack(spacing: ThemeManager.Spacing.md) {
                    ProgressView(value: dataImporter.importProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                        .tint(ThemeManager.Colors.primary)
                    
                    Text(dataImporter.importStatus)
                        .font(ThemeManager.Typography.dynamicCaption())
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(ThemeManager.Spacing.md)
                .background(ThemeManager.Colors.surface)
                .cornerRadius(ThemeManager.CornerRadius.lg)
            } else {
                VStack(spacing: ThemeManager.Spacing.sm) {
                    Text(dataImporter.importStatus.isEmpty ? "Ready to import work spaces" : dataImporter.importStatus)
                        .font(ThemeManager.Typography.dynamicBody())
                        .foregroundColor(dataImporter.importStatus.contains("Error") ? ThemeManager.Colors.error : ThemeManager.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(ThemeManager.Spacing.md)
                .background(ThemeManager.Colors.surface)
                .cornerRadius(ThemeManager.CornerRadius.lg)
            }
        }
    }
    
    private var citySelectionSection: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
            Text("Select City")
                .font(ThemeManager.Typography.dynamicHeadline())
                .foregroundColor(ThemeManager.Colors.textPrimary)
            
            Picker("City", selection: $selectedCity) {
                ForEach(dataImporter.availableCities, id: \.self) { city in
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
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: ThemeManager.Spacing.md) {
            // Import Selected City Button
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
            
            // Import All Cities Button
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
            
            // Clear All Spots Button
            Button(action: {
                showingClearAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Spots")
                }
                .themedButton(style: .secondary)
                .foregroundColor(ThemeManager.Colors.error)
            }
            .disabled(dataImporter.isImporting)
        }
    }
    
    private var importInfoSection: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
            Text("What will be imported:")
                .font(ThemeManager.Typography.dynamicHeadline())
                .foregroundColor(ThemeManager.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
                ImportInfoRow(icon: "location", text: "Work spots with accurate coordinates")
                ImportInfoRow(icon: "wifi", text: "WiFi quality ratings")
                ImportInfoRow(icon: "speaker.wave.2", text: "Noise level information")
                ImportInfoRow(icon: "powerplug", text: "Power outlet availability")
                ImportInfoRow(icon: "photo", text: "Spot photos and tips")
                ImportInfoRow(icon: "location.magnifyingglass", text: "Geocoded addresses for precision")
            }
        }
        .padding(ThemeManager.Spacing.md)
        .background(ThemeManager.Colors.surface)
        .cornerRadius(ThemeManager.CornerRadius.lg)
    }
}

// MARK: - Supporting Views

struct ImportInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: ThemeManager.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(ThemeManager.Colors.primary)
                .frame(width: 20)
            
            Text(text)
                .font(ThemeManager.Typography.dynamicSubheadline())
                .foregroundColor(ThemeManager.Colors.textSecondary)
        }
    }
}

#Preview {
    ImportView()
}