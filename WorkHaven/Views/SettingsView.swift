//
//  SettingsView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//  Updated with auto-discovery controls, location-based spot seeding, and ThemeManager styling
//

import SwiftUI
import CoreLocation
import CoreData

struct SettingsView: View {
    @StateObject private var notificationManager: NotificationManager
    @StateObject private var spotDiscoveryService = SpotDiscoveryService.shared
    @StateObject private var locationService = LocationService()
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    @State private var notificationRadius: Double = 5000
    @State private var showingRadiusPicker = false
    @State private var isAutoDiscoverEnabled = false
    @State private var isSeeding = false
    @State private var seedingStatus = ""
    @State private var showingSeedingAlert = false
    @State private var seedingAlertMessage = ""
    #if DEBUG
    @State private var showingDatabaseReset = false
    #endif
    
    init(context: NSManagedObjectContext) {
        _notificationManager = StateObject(wrappedValue: NotificationManager(context: context))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Auto-Discovery Section
                Section {
                    VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
                        // Auto-Discover Toggle
                        Toggle(isOn: $isAutoDiscoverEnabled) {
                            HStack(spacing: ThemeManager.Spacing.sm) {
                                Image(systemName: "location.magnifyingglass")
                                    .foregroundColor(ThemeManager.Colors.primary)
                                    .font(ThemeManager.Typography.dynamicHeadline())
                                
                                VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
                                    Text("Auto-Discover Spots")
                                        .font(ThemeManager.Typography.dynamicHeadline())
                                        .fontWeight(.semibold)
                                        .foregroundColor(ThemeManager.Colors.textPrimary)
                                    
                                    Text("Find nearby spots using Apple Maps and AI (requires location/internet)")
                                        .font(ThemeManager.Typography.dynamicCaption())
                                        .foregroundColor(ThemeManager.Colors.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .tint(ThemeManager.Colors.primary)
                        .onChange(of: isAutoDiscoverEnabled) { enabled in
                            handleAutoDiscoverToggle(enabled: enabled)
                        }
                        .accessibilityLabel("Toggle auto-discover spots")
                        .accessibilityHint("Double tap to enable or disable automatic spot discovery using your location and AI")
                        
                        // Regenerate Now Button
                        if isAutoDiscoverEnabled {
                            Button(action: {
                                Task {
                                    await regenerateSpots()
                                }
                            }) {
                                HStack {
                                    if isSeeding {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.Colors.surface))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    
                                    Text(isSeeding ? "Discovering..." : "Regenerate Now")
                                        .font(ThemeManager.Typography.dynamicBody())
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(ThemeManager.Colors.surface)
                                .padding(.horizontal, ThemeManager.Spacing.lg)
                                .padding(.vertical, ThemeManager.Spacing.md)
                                .background(ThemeManager.Colors.primary)
                                .cornerRadius(ThemeManager.CornerRadius.md)
                                .shadow(
                                    color: ThemeManager.Shadows.sm.color,
                                    radius: ThemeManager.Shadows.sm.radius,
                                    x: ThemeManager.Shadows.sm.x,
                                    y: ThemeManager.Shadows.sm.y
                                )
                            }
                            .disabled(isSeeding)
                            .accessibilityLabel("Regenerate spots now")
                            .accessibilityHint("Double tap to discover new work spots in your area")
                            
                            // Seeding Status
                            if !seedingStatus.isEmpty {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(ThemeManager.Colors.accent)
                                        .font(ThemeManager.Typography.dynamicCaption())
                                    
                                    Text(seedingStatus)
                                        .font(ThemeManager.Typography.dynamicCaption())
                                        .foregroundColor(ThemeManager.Colors.textSecondary)
                                }
                                .padding(.horizontal, ThemeManager.Spacing.sm)
                                .padding(.vertical, ThemeManager.Spacing.xs)
                                .background(ThemeManager.Colors.background)
                                .cornerRadius(ThemeManager.CornerRadius.sm)
                            }
                        }
                    }
                    .padding(.vertical, ThemeManager.Spacing.sm)
                } header: {
                    Text("Spot Discovery")
                } footer: {
                    VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
                        Text("When enabled, WorkHaven will automatically discover nearby work spots using your location and AI-powered enrichment.")
                        
                        if !spotDiscoveryService.hasGrokAPIKey() {
                            Text("⚠️ API key not configured. Add GROK_API_KEY to secrets.xcconfig for AI enrichment.")
                                .foregroundColor(ThemeManager.Colors.warning)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                // Notification Status Section
                Section {
                    HStack {
                        Image(systemName: notificationManager.isAuthorized ? "bell.fill" : "bell.slash")
                            .foregroundColor(notificationManager.isAuthorized ? ThemeManager.Colors.success : ThemeManager.Colors.error)
                        
                        VStack(alignment: .leading) {
                            Text("Notifications")
                                .font(ThemeManager.Typography.dynamicHeadline())
                                .foregroundColor(ThemeManager.Colors.textPrimary)
                            Text(notificationManager.isAuthorized ? "Enabled" : "Disabled")
                                .font(ThemeManager.Typography.dynamicCaption())
                                .foregroundColor(ThemeManager.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        if !notificationManager.isAuthorized {
                            Button("Enable") {
                                requestNotificationPermission()
                            }
                            .themedButton(style: .primary)
                        }
                    }
                } header: {
                    Text("Status")
                } footer: {
                    if !notificationManager.isAuthorized {
                        Text("Enable notifications to receive alerts about new work spots and hot spots in your area.")
                            .font(ThemeManager.Typography.dynamicCaption())
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                    }
                }
                
                // Notification Types Section
                if notificationManager.isAuthorized {
                    Section {
                        // Location-based notifications
                        Toggle(isOn: Binding(
                            get: { notificationManager.locationNotificationsEnabled },
                            set: { notificationManager.updateLocationNotifications($0) }
                        )) {
                            VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(ThemeManager.Colors.accent)
                                    Text("Nearby Spots")
                                        .font(ThemeManager.Typography.dynamicHeadline())
                                        .foregroundColor(ThemeManager.Colors.textPrimary)
                                }
                                Text("Get notified when new spots are added near you")
                                    .font(ThemeManager.Typography.dynamicCaption())
                                    .foregroundColor(ThemeManager.Colors.textSecondary)
                            }
                        }
                        .tint(ThemeManager.Colors.accent)
                        
                        // Hot spot notifications
                        Toggle(isOn: Binding(
                            get: { notificationManager.hotSpotNotificationsEnabled },
                            set: { notificationManager.updateHotSpotNotifications($0) }
                        )) {
                            VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(ThemeManager.Colors.warning)
                                    Text("Hot Spots")
                                        .font(ThemeManager.Typography.dynamicHeadline())
                                        .foregroundColor(ThemeManager.Colors.textPrimary)
                                }
                                Text("Alerts for highly-rated spots (4+ stars)")
                                    .font(ThemeManager.Typography.dynamicCaption())
                                    .foregroundColor(ThemeManager.Colors.textSecondary)
                            }
                        }
                        .tint(ThemeManager.Colors.warning)
                        
                        // New spot notifications
                        Toggle(isOn: Binding(
                            get: { notificationManager.newSpotNotificationsEnabled },
                            set: { notificationManager.updateNewSpotNotifications($0) }
                        )) {
                            VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(ThemeManager.Colors.success)
                                    Text("New Spots")
                                        .font(ThemeManager.Typography.dynamicHeadline())
                                        .foregroundColor(ThemeManager.Colors.textPrimary)
                                }
                                Text("Notifications when any new spot is added")
                                    .font(ThemeManager.Typography.dynamicCaption())
                                    .foregroundColor(ThemeManager.Colors.textSecondary)
                            }
                        }
                        .tint(ThemeManager.Colors.success)
                    } header: {
                        Text("Notification Types")
                    } footer: {
                        Text("Customize which types of notifications you'd like to receive.")
                            .font(ThemeManager.Typography.dynamicCaption())
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                    }
                }
                
                // Location Settings Section
                if notificationManager.isAuthorized && notificationManager.locationNotificationsEnabled {
                    Section {
                        HStack {
                            Image(systemName: "location.circle")
                                .foregroundColor(ThemeManager.Colors.accent)
                            
                            VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
                                Text("Notification Radius")
                                    .font(ThemeManager.Typography.dynamicHeadline())
                                    .foregroundColor(ThemeManager.Colors.textPrimary)
                                Text("\(Int(notificationRadius / 1000))km")
                                    .font(ThemeManager.Typography.dynamicCaption())
                                    .foregroundColor(ThemeManager.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Button("Change") {
                                showingRadiusPicker = true
                            }
                            .themedButton(style: .secondary)
                        }
                        
                        // Radius slider
                        VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                            HStack {
                                Text("1km")
                                    .font(ThemeManager.Typography.dynamicCaption())
                                    .foregroundColor(ThemeManager.Colors.textSecondary)
                                Spacer()
                                Text("10km")
                                    .font(ThemeManager.Typography.dynamicCaption())
                                    .foregroundColor(ThemeManager.Colors.textSecondary)
                            }
                            
                            Slider(
                                value: $notificationRadius,
                                in: 1000...10000,
                                step: 500
                            ) {
                                Text("Radius")
                            } minimumValueLabel: {
                                Text("1km")
                                    .font(ThemeManager.Typography.dynamicCaption())
                            } maximumValueLabel: {
                                Text("10km")
                                    .font(ThemeManager.Typography.dynamicCaption())
                            }
                            .tint(ThemeManager.Colors.accent)
                            .onChange(of: notificationRadius) { newValue in
                                notificationManager.updateNotificationRadius(newValue)
                            }
                        }
                    } header: {
                        Text("Location Settings")
                    } footer: {
                        Text("Choose how far from your location you want to receive notifications about new spots.")
                            .font(ThemeManager.Typography.dynamicCaption())
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                    }
                }
                
                // Notification Management Section
                if notificationManager.isAuthorized {
                    Section {
                        Button(action: {
                            testNotification()
                        }) {
                            HStack {
                                Image(systemName: "bell.badge")
                                    .foregroundColor(ThemeManager.Colors.accent)
                                Text("Send Test Notification")
                                    .font(ThemeManager.Typography.dynamicBody())
                                    .foregroundColor(ThemeManager.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundColor(ThemeManager.Colors.textSecondary)
                            }
                        }
                        
                        Button(action: {
                            clearAllNotifications()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(ThemeManager.Colors.error)
                                Text("Clear All Notifications")
                                    .font(ThemeManager.Typography.dynamicBody())
                                    .foregroundColor(ThemeManager.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundColor(ThemeManager.Colors.textSecondary)
                            }
                        }
                    } header: {
                        Text("Manage Notifications")
                    }
                }
                
                // Debug Tools Section (Debug Only)
                #if DEBUG
                Section {
                    Button(action: {
                        Task {
                            await testCloudKitConnection()
                        }
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(ThemeManager.Colors.accent)
                            Text("Test CloudKit Connection")
                                .font(ThemeManager.Typography.dynamicBody())
                                .foregroundColor(ThemeManager.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(ThemeManager.Colors.textSecondary)
                        }
                    }
                    .accessibilityLabel("Test CloudKit Connection")
                    .accessibilityHint("Double tap to test CloudKit connectivity")
                    
                    Button(action: {
                        Task {
                            await wipeDatabase()
                        }
                    }) {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                                .foregroundColor(ThemeManager.Colors.error)
                            Text("Wipe Database (Debug)")
                                .font(ThemeManager.Typography.dynamicBody())
                                .foregroundColor(ThemeManager.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(ThemeManager.Colors.textSecondary)
                        }
                    }
                    .accessibilityLabel("Wipe Database Debug")
                    .accessibilityHint("Double tap to completely wipe all data (debug only)")
                    
                    Button(action: {
                        Task {
                            await completeReset()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(ThemeManager.Colors.warning)
                            Text("Complete Reset (Debug)")
                                .font(ThemeManager.Typography.dynamicBody())
                                .foregroundColor(ThemeManager.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(ThemeManager.Colors.textSecondary)
                        }
                    }
                    .accessibilityLabel("Complete Reset Debug")
                    .accessibilityHint("Double tap to completely reset app and discover new spots")
                    
                    Button(action: {
                        showingDatabaseReset = true
                    }) {
                        HStack {
                            Image(systemName: "trash.circle")
                                .foregroundColor(ThemeManager.Colors.error)
                            Text("Reset Database (Debug)")
                                .font(ThemeManager.Typography.dynamicBody())
                                .foregroundColor(ThemeManager.Colors.textPrimary)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundColor(ThemeManager.Colors.textSecondary)
                        }
                    }
                    .accessibilityLabel("Reset Database Debug")
                    .accessibilityHint("Double tap to open database reset options (debug only)")
                } header: {
                    Text("Debug Tools")
                } footer: {
                    Text("Development tools for testing and debugging. Not available in production builds.")
                        .font(ThemeManager.Typography.dynamicCaption())
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                }
                #endif
                
                // App Information Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(ThemeManager.Colors.accent)
                        Text("App Version")
                            .font(ThemeManager.Typography.dynamicBody())
                            .foregroundColor(ThemeManager.Colors.textPrimary)
                        Spacer()
                        Text("1.0.0")
                            .font(ThemeManager.Typography.dynamicBody())
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                    }
                    
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(ThemeManager.Colors.accent)
                        Text("Help & Support")
                            .font(ThemeManager.Typography.dynamicBody())
                            .foregroundColor(ThemeManager.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                    }
                    .onTapGesture {
                        // Handle help action
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadSettings()
                configureServices()
            }
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(permissionAlertMessage)
            }
            .alert("Spot Discovery", isPresented: $showingSeedingAlert) {
                Button("OK") { }
            } message: {
                Text(seedingAlertMessage)
            }
            .sheet(isPresented: $showingRadiusPicker) {
                RadiusPickerView(
                    radius: $notificationRadius,
                    isPresented: $showingRadiusPicker
                )
            }
            #if DEBUG
            .sheet(isPresented: $showingDatabaseReset) {
                DatabaseResetView(
                    context: PersistenceController.shared.container.viewContext,
                    cloudKitManager: CloudKitManager(context: PersistenceController.shared.container.viewContext)
                )
            }
            #endif
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadSettings() {
        isAutoDiscoverEnabled = UserDefaults.standard.bool(forKey: "AutoDiscoverEnabled")
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(isAutoDiscoverEnabled, forKey: "AutoDiscoverEnabled")
    }
    
    private func configureServices() {
        spotDiscoveryService.configure(with: PersistenceController.shared.container.viewContext)
    }
    
    private func handleAutoDiscoverToggle(enabled: Bool) {
        saveSettings()
        
        if enabled {
            // Request location permission when enabling auto-discover
            locationService.requestLocationPermission()
            
            // Check if we have location permission
            if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                permissionAlertMessage = "Location permission is required for auto-discovery. Please enable location access in Settings."
                showingPermissionAlert = true
                isAutoDiscoverEnabled = false
                saveSettings()
            }
        }
    }
    
    private func regenerateSpots() async {
        await MainActor.run {
            isSeeding = true
            seedingStatus = "Starting spot discovery..."
        }
        
        do {
            // Get current location
            let userLocation = await getCurrentUserLocation()
            
            // Discover spots
            let discoveredSpots = await spotDiscoveryService.discoverSpots(near: userLocation, radius: 32186.88) // 20 miles
            
            await MainActor.run {
                isSeeding = false
                seedingStatus = "Discovery completed"
                
                if discoveredSpots.isEmpty {
                    seedingAlertMessage = "No new work spots found in your area. Try again later or check your internet connection."
                    showingSeedingAlert = true
                } else {
                    seedingAlertMessage = "Successfully discovered \(discoveredSpots.count) new work spots!"
                    showingSeedingAlert = true
                }
            }
            
        } catch {
            await MainActor.run {
                isSeeding = false
                seedingStatus = "Discovery failed"
                seedingAlertMessage = "Failed to discover spots: \(error.localizedDescription)"
                showingSeedingAlert = true
            }
        }
    }
    
    private func getCurrentUserLocation() async -> CLLocation {
        locationService.requestLocationPermission()
        
        // Wait for location with timeout
        let timeout: TimeInterval = 10.0
        let startTime = Date()
        
        while locationService.currentLocation == nil && Date().timeIntervalSince(startTime) < timeout {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Return user location or fallback to Boise, ID
        return locationService.currentLocation ?? CLLocation(latitude: 43.6150, longitude: -116.2023)
    }
    
    private func requestNotificationPermission() {
        notificationManager.requestNotificationPermission()
    }
    
    private func testNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test Notification"
        content.body = "WorkHaven notifications are working perfectly!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "test_notification",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending test notification: \(error)")
            }
        }
    }
    
    private func clearAllNotifications() {
        notificationManager.clearAllNotifications()
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func testCloudKitConnection() async {
        let cloudKitManager = CloudKitManager(context: PersistenceController.shared.container.viewContext)
        
        await MainActor.run {
            seedingStatus = "Testing CloudKit connection..."
            isSeeding = true
        }
        
        do {
            // Test CloudKit connection by trying to sync
            await cloudKitManager.syncWithCloudKit()
            
            await MainActor.run {
                seedingStatus = "CloudKit connection successful!"
                seedingAlertMessage = "CloudKit is working properly. Your data will sync across devices."
                showingSeedingAlert = true
                isSeeding = false
            }
        } catch {
            await MainActor.run {
                seedingStatus = "CloudKit connection failed"
                seedingAlertMessage = "CloudKit connection failed: \(error.localizedDescription)"
                showingSeedingAlert = true
                isSeeding = false
            }
        }
    }
    
    private func wipeDatabase() async {
        await MainActor.run {
            seedingStatus = "Wiping database..."
            isSeeding = true
        }
        
        do {
            // Wipe local Core Data
            let context = PersistenceController.shared.container.viewContext
            
            // Delete all Spot entities
            let spotFetchRequest: NSFetchRequest<NSFetchRequestResult> = Spot.fetchRequest()
            let spotDeleteRequest = NSBatchDeleteRequest(fetchRequest: spotFetchRequest)
            
            // Delete all UserRating entities
            let ratingFetchRequest: NSFetchRequest<NSFetchRequestResult> = UserRating.fetchRequest()
            let ratingDeleteRequest = NSBatchDeleteRequest(fetchRequest: ratingFetchRequest)
            
            try context.execute(spotDeleteRequest)
            try context.execute(ratingDeleteRequest)
            try context.save()
            
            // Wipe CloudKit data
            let cloudKitManager = CloudKitManager(context: context)
            await cloudKitManager.clearCloudKitRecords()
            
            await MainActor.run {
                seedingStatus = "Database wiped successfully!"
                seedingAlertMessage = "All data has been wiped. The app will now start fresh with location-based discovery."
                showingSeedingAlert = true
                isSeeding = false
            }
            
        } catch {
            await MainActor.run {
                seedingStatus = "Database wipe failed"
                seedingAlertMessage = "Failed to wipe database: \(error.localizedDescription)"
                showingSeedingAlert = true
                isSeeding = false
            }
        }
    }
    
    private func completeReset() async {
        await MainActor.run {
            seedingStatus = "Starting complete reset..."
            isSeeding = true
        }
        
        do {
            // Step 1: Wipe local Core Data
            let context = PersistenceController.shared.container.viewContext
            
            // Delete all Spot entities
            let spotFetchRequest: NSFetchRequest<NSFetchRequestResult> = Spot.fetchRequest()
            let spotDeleteRequest = NSBatchDeleteRequest(fetchRequest: spotFetchRequest)
            
            // Delete all UserRating entities
            let ratingFetchRequest: NSFetchRequest<NSFetchRequestResult> = UserRating.fetchRequest()
            let ratingDeleteRequest = NSBatchDeleteRequest(fetchRequest: ratingFetchRequest)
            
            try context.execute(spotDeleteRequest)
            try context.execute(ratingDeleteRequest)
            try context.save()
            
            await MainActor.run {
                seedingStatus = "Local data wiped, clearing CloudKit..."
            }
            
            // Step 2: Wipe CloudKit data
            let cloudKitManager = CloudKitManager(context: context)
            await cloudKitManager.clearCloudKitRecords()
            
            await MainActor.run {
                seedingStatus = "CloudKit cleared, resetting flags..."
            }
            
            // Step 3: Reset UserDefaults flags
            UserDefaults.standard.set(false, forKey: "DataWiped")
            UserDefaults.standard.set(false, forKey: "CloudKitCleared")
            
            await MainActor.run {
                seedingStatus = "Starting fresh discovery..."
            }
            
            // Step 4: Trigger fresh discovery
            let spotViewModel = SpotViewModel(context: context)
            await spotViewModel.performFreshDiscovery()
            
            await MainActor.run {
                seedingStatus = "Complete reset successful!"
                seedingAlertMessage = "App has been completely reset. Fresh spots will be discovered based on your current location."
                showingSeedingAlert = true
                isSeeding = false
            }
            
        } catch {
            await MainActor.run {
                seedingStatus = "Complete reset failed"
                seedingAlertMessage = "Failed to complete reset: \(error.localizedDescription)"
                showingSeedingAlert = true
                isSeeding = false
            }
        }
    }
}

// MARK: - Radius Picker View

struct RadiusPickerView: View {
    @Binding var radius: Double
    @Binding var isPresented: Bool
    
    private let radiusOptions: [(Double, String)] = [
        (1000, "1 km"),
        (2000, "2 km"),
        (3000, "3 km"),
        (5000, "5 km"),
        (7500, "7.5 km"),
        (10000, "10 km")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(radiusOptions, id: \.0) { option in
                    HStack {
                        Text(option.1)
                            .font(ThemeManager.Typography.dynamicBody())
                            .foregroundColor(ThemeManager.Colors.textPrimary)
                        Spacer()
                        if abs(radius - option.0) < 100 {
                            Image(systemName: "checkmark")
                                .foregroundColor(ThemeManager.Colors.accent)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        radius = option.0
                        isPresented = false
                    }
                }
            }
            .navigationTitle("Notification Radius")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .themedButton(style: .primary)
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    SettingsView(context: context)
}