//
//  NotificationManager.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import Foundation
import UserNotifications
import CoreLocation
import CoreData
import SwiftUI
import UIKit

class NotificationManager: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var locationNotificationsEnabled = true
    @Published var hotSpotNotificationsEnabled = true
    @Published var newSpotNotificationsEnabled = true
    
    private let center = UNUserNotificationCenter.current()
    private let locationManager = CLLocationManager()
    private let context: NSManagedObjectContext
    
    // Notification categories
    private let locationCategory = "LOCATION_CATEGORY"
    private let hotSpotCategory = "HOTSPOT_CATEGORY"
    private let newSpotCategory = "NEWSPOT_CATEGORY"
    
    // User defaults keys
    private let locationNotificationsKey = "locationNotificationsEnabled"
    private let hotSpotNotificationsKey = "hotSpotNotificationsEnabled"
    private let newSpotNotificationsKey = "newSpotNotificationsEnabled"
    private let userRadiusKey = "notificationRadius"
    private let lastNotificationCheckKey = "lastNotificationCheck"
    
    // Default settings
    private let defaultRadius: Double = 5000 // 5km in meters
    private let hotSpotThreshold: Int16 = 4 // Minimum rating for hot spots
    
    init(context: NSManagedObjectContext) {
        self.context = context
        super.init()
        
        setupNotificationCategories()
        loadSettings()
        requestNotificationPermission()
        setupLocationManager()
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    self?.registerForRemoteNotifications()
                }
            }
        }
    }
    
    private func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // MARK: - Notification Categories Setup
    
    private func setupNotificationCategories() {
        // Location-based notifications
        let locationAction = UNNotificationAction(
            identifier: "VIEW_SPOT",
            title: "View Spot",
            options: [.foreground]
        )
        let locationCategory = UNNotificationCategory(
            identifier: locationCategory,
            actions: [locationAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Hot spot notifications
        let hotSpotAction = UNNotificationAction(
            identifier: "VIEW_HOTSPOT",
            title: "Check It Out",
            options: [.foreground]
        )
        let hotSpotCategory = UNNotificationCategory(
            identifier: hotSpotCategory,
            actions: [hotSpotAction],
            intentIdentifiers: [],
            options: []
        )
        
        // New spot notifications
        let newSpotAction = UNNotificationAction(
            identifier: "VIEW_NEWSPOT",
            title: "Discover",
            options: [.foreground]
        )
        let newSpotCategory = UNNotificationCategory(
            identifier: newSpotCategory,
            actions: [newSpotAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([locationCategory, hotSpotCategory, newSpotCategory])
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        locationNotificationsEnabled = UserDefaults.standard.bool(forKey: locationNotificationsKey)
        hotSpotNotificationsEnabled = UserDefaults.standard.bool(forKey: hotSpotNotificationsKey)
        newSpotNotificationsEnabled = UserDefaults.standard.bool(forKey: newSpotNotificationsKey)
    }
    
    func updateLocationNotifications(_ enabled: Bool) {
        locationNotificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: locationNotificationsKey)
    }
    
    func updateHotSpotNotifications(_ enabled: Bool) {
        hotSpotNotificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: hotSpotNotificationsKey)
    }
    
    func updateNewSpotNotifications(_ enabled: Bool) {
        newSpotNotificationsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: newSpotNotificationsKey)
    }
    
    func updateNotificationRadius(_ radius: Double) {
        UserDefaults.standard.set(radius, forKey: userRadiusKey)
    }
    
    func getNotificationRadius() -> Double {
        let radius = UserDefaults.standard.double(forKey: userRadiusKey)
        return radius > 0 ? radius : defaultRadius
    }
    
    // MARK: - Location Manager Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleLocationBasedNotification(for spot: Spot) {
        guard locationNotificationsEnabled && isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "📍 New Work Spot Nearby!"
        content.body = "\(spot.name ?? "A new spot") is just \(formatDistance(spot)) away"
        content.sound = .default
        content.categoryIdentifier = locationCategory
        content.userInfo = [
            "spotID": spot.objectID.uriRepresentation().absoluteString,
            "type": "location"
        ]
        
        // Schedule for immediate delivery
        let request = UNNotificationRequest(
            identifier: "location_\(spot.objectID.uriRepresentation().absoluteString)",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling location notification: \(error)")
            }
        }
    }
    
    func scheduleHotSpotNotification(for spot: Spot) {
        guard hotSpotNotificationsEnabled && isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "🔥 Hot Spot Alert!"
        content.body = "\(spot.name ?? "This spot") has a \(spot.wifiRating)/5 WiFi rating - worth checking out!"
        content.sound = .default
        content.categoryIdentifier = hotSpotCategory
        content.userInfo = [
            "spotID": spot.objectID.uriRepresentation().absoluteString,
            "type": "hotspot"
        ]
        
        let request = UNNotificationRequest(
            identifier: "hotspot_\(spot.objectID.uriRepresentation().absoluteString)",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling hot spot notification: \(error)")
            }
        }
    }
    
    func scheduleNewSpotNotification(for spot: Spot) {
        guard newSpotNotificationsEnabled && isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "✨ Fresh Spot Added!"
        content.body = "\(spot.name ?? "A new work spot") has been added to WorkHaven"
        content.sound = .default
        content.categoryIdentifier = newSpotCategory
        content.userInfo = [
            "spotID": spot.objectID.uriRepresentation().absoluteString,
            "type": "newspot"
        ]
        
        let request = UNNotificationRequest(
            identifier: "newspot_\(spot.objectID.uriRepresentation().absoluteString)",
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling new spot notification: \(error)")
            }
        }
    }
    
    // MARK: - Spot Monitoring
    
    func checkForNewSpots() {
        guard let lastCheck = UserDefaults.standard.object(forKey: lastNotificationCheckKey) as? Date else {
            UserDefaults.standard.set(Date(), forKey: lastNotificationCheckKey)
            return
        }
        
        let fetchRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "lastModified > %@", lastCheck as NSDate)
        
        do {
            let newSpots = try context.fetch(fetchRequest)
            
            for spot in newSpots {
                // Check if it's a hot spot
                if spot.wifiRating >= hotSpotThreshold {
                    scheduleHotSpotNotification(for: spot)
                }
                
                // Check if it's nearby
                if let userLocation = locationManager.location {
                    let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                    let distance = userLocation.distance(from: spotLocation)
                    
                    if distance <= getNotificationRadius() {
                        scheduleLocationBasedNotification(for: spot)
                    }
                }
                
                // Always notify about new spots if enabled
                scheduleNewSpotNotification(for: spot)
            }
            
            UserDefaults.standard.set(Date(), forKey: lastNotificationCheckKey)
            
        } catch {
            print("Error checking for new spots: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDistance(_ spot: Spot) -> String {
        guard let userLocation = locationManager.location else {
            return "nearby"
        }
        
        let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
        let distance = userLocation.distance(from: spotLocation)
        
        if distance < 1000 {
            return "\(Int(distance))m away"
        } else {
            return String(format: "%.1fkm away", distance / 1000)
        }
    }
    
    func clearAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    
    func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        center.getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension NotificationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Check for new spots when location updates
        checkForNewSpots()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied for notifications")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        if let spotIDString = userInfo["spotID"] as? String,
           let spotURL = URL(string: spotIDString),
           let spotID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: spotURL),
           let spot = try? context.existingObject(with: spotID) as? Spot {
            
            // Handle notification tap - could navigate to spot detail
            NotificationCenter.default.post(
                name: NSNotification.Name("SpotSelectedFromNotification"),
                object: spot
            )
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
    }
}
