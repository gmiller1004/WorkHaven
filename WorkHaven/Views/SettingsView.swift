//
//  SettingsView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import CoreLocation
import CoreData

struct SettingsView: View {
    @StateObject private var notificationManager: NotificationManager
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    @State private var notificationRadius: Double = 5000
    @State private var showingRadiusPicker = false
    
    init(context: NSManagedObjectContext) {
        _notificationManager = StateObject(wrappedValue: NotificationManager(context: context))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Notification Status Section
                Section {
                    HStack {
                        Image(systemName: notificationManager.isAuthorized ? "bell.fill" : "bell.slash")
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                        
                        VStack(alignment: .leading) {
                            Text("Notifications")
                                .font(.headline)
                            Text(notificationManager.isAuthorized ? "Enabled" : "Disabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !notificationManager.isAuthorized {
                            Button("Enable") {
                                requestNotificationPermission()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                } header: {
                    Text("Status")
                } footer: {
                    if !notificationManager.isAuthorized {
                        Text("Enable notifications to receive alerts about new work spots and hot spots in your area.")
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
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                    Text("Nearby Spots")
                                        .font(.headline)
                                }
                                Text("Get notified when new spots are added near you")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.blue)
                        
                        // Hot spot notifications
                        Toggle(isOn: Binding(
                            get: { notificationManager.hotSpotNotificationsEnabled },
                            set: { notificationManager.updateHotSpotNotifications($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                    Text("Hot Spots")
                                        .font(.headline)
                                }
                                Text("Alerts for highly-rated spots (4+ stars)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.orange)
                        
                        // New spot notifications
                        Toggle(isOn: Binding(
                            get: { notificationManager.newSpotNotificationsEnabled },
                            set: { notificationManager.updateNewSpotNotifications($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                    Text("New Spots")
                                        .font(.headline)
                                }
                                Text("Notifications when any new spot is added")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(.green)
                    } header: {
                        Text("Notification Types")
                    } footer: {
                        Text("Customize which types of notifications you'd like to receive.")
                    }
                }
                
                // Location Settings Section
                if notificationManager.isAuthorized && notificationManager.locationNotificationsEnabled {
                    Section {
                        HStack {
                            Image(systemName: "location.circle")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notification Radius")
                                    .font(.headline)
                                Text("\(Int(notificationRadius / 1000))km")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Change") {
                                showingRadiusPicker = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        // Radius slider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("1km")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("10km")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: $notificationRadius,
                                in: 1000...10000,
                                step: 500
                            ) {
                                Text("Radius")
                            } minimumValueLabel: {
                                Text("1km")
                                    .font(.caption)
                            } maximumValueLabel: {
                                Text("10km")
                                    .font(.caption)
                            }
                            .onChange(of: notificationRadius) { newValue in
                                notificationManager.updateNotificationRadius(newValue)
                            }
                        }
                    } header: {
                        Text("Location Settings")
                    } footer: {
                        Text("Choose how far from your location you want to receive notifications about new spots.")
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
                                    .foregroundColor(.blue)
                                Text("Send Test Notification")
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                        
                        Button(action: {
                            clearAllNotifications()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("Clear All Notifications")
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    } header: {
                        Text("Manage Notifications")
                    }
                }
                
                // App Information Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.blue)
                        Text("Help & Support")
                        Spacer()
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
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
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(permissionAlertMessage)
            }
            .sheet(isPresented: $showingRadiusPicker) {
                RadiusPickerView(
                    radius: $notificationRadius,
                    isPresented: $showingRadiusPicker
                )
            }
        }
    }
    
    // MARK: - Helper Functions
    
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
                        Spacer()
                        if abs(radius - option.0) < 100 {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
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
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    SettingsView(context: context)
}
