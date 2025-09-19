//
//  LocationService.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import Foundation
import CoreLocation
import MapKit

class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled = false
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
    
    func getDistance(from spot: Spot) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
        return currentLocation.distance(from: spotLocation)
    }
    
    func getFormattedDistance(from spot: Spot) -> String? {
        guard let distance = getDistance(from: spot) else { return nil }
        
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromDistance: distance)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        isLocationEnabled = (status == .authorizedWhenInUse || status == .authorizedAlways)
        
        if isLocationEnabled {
            startLocationUpdates()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}
