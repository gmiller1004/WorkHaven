//
//  SpotDiscoveryService.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/22/25.
//  Service for discovering nearby work spots using MapKit MKLocalSearch and enriching them with xAI Grok API
//

import Foundation
import MapKit
import CoreData
import SwiftUI

// MARK: - Discovery Result Models

struct DiscoveryResult {
    let mapItem: MKMapItem
    let enrichedData: EnrichedSpotData?
    let error: DiscoveryError?
}

struct EnrichedSpotData: Codable {
    let wifi: Int
    let noise: String
    let plugs: Bool
    let tip: String
}

enum DiscoveryError: LocalizedError {
    case noResults
    case apiFailure(String)
    case invalidResponse
    case networkError(Error)
    case parsingError(Error)
    case coreDataError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noResults:
            return "No work spots found in the area"
        case .apiFailure(let message):
            return "API enrichment failed: \(message)"
        case .invalidResponse:
            return "Invalid response from enrichment API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError(let error):
            return "Failed to parse API response: \(error.localizedDescription)"
        case .coreDataError(let error):
            return "Database error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Spot Discovery Service

@MainActor
class SpotDiscoveryService: ObservableObject {
    static let shared = SpotDiscoveryService()
    
    // MARK: - Published Properties
    
    @Published var isDiscovering = false
    @Published var discoveryProgress: Double = 0.0
    @Published var discoveryStatus = ""
    @Published var discoveredSpots: [Spot] = []
    @Published var discoveryError: String? = nil {
        didSet {
            if discoveryError != nil {
                // Clear error after 5 seconds
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    await MainActor.run {
                        self.discoveryError = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var managedObjectContext: NSManagedObjectContext?
    private let grokAPIKey = "GROK_API_KEY"
    private let grokAPIEndpoint = "https://api.x.ai/v1/chat/completions"
    private let grokModel = "grok-4-fast-non-reasoning"
    
    // Cached API key to prevent repeated lookups
    private var _cachedAPIKey: String?
    private var _apiKeyChecked = false
    
    // Get API key from xcconfig file or Info.plist (cached)
    private var grokAPIKeyValue: String? {
        // Only check once and cache the result
        if !_apiKeyChecked {
            _apiKeyChecked = true
            
            // Try to get from xcconfig first
            if let xcconfigKey = Bundle.main.object(forInfoDictionaryKey: grokAPIKey) as? String,
               !xcconfigKey.isEmpty && xcconfigKey != "YOUR_GROK_API_KEY_HERE" {
                print("✅ Found Grok API key in xcconfig: \(String(xcconfigKey.prefix(10)))...")
                _cachedAPIKey = xcconfigKey
            }
            // Fallback to Info.plist
            else if let plistKey = Bundle.main.object(forInfoDictionaryKey: grokAPIKey) as? String,
                    !plistKey.isEmpty && plistKey != "YOUR_GROK_API_KEY_HERE" {
                print("✅ Found Grok API key in Info.plist: \(String(plistKey.prefix(10)))...")
                _cachedAPIKey = plistKey
            }
            else {
                print("❌ Grok API key not found in xcconfig or Info.plist")
                print("📋 Available Info.plist keys: \(Bundle.main.infoDictionary?.keys.sorted() ?? [])")
                print("🔧 To fix this:")
                print("   1. Add secrets.xcconfig to Xcode project")
                print("   2. Configure Build Settings to use secrets.xcconfig")
                print("   3. Or add GROK_API_KEY to Info.plist manually")
                _cachedAPIKey = nil
            }
        }
        
        return _cachedAPIKey
    }
    
    // Discovery settings
    private let maxResultsPerCategory = 15
    private let minResultsPerCategory = 10
    private let discoveryCategories = [
        "coffee shop",
        "library", 
        "park",
        "co-working space"
    ]
    
    private init() {}
    
    // MARK: - Configuration
    
    func configure(with context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }
    
    // MARK: - Main Discovery Function
    
    /// Discovers nearby work spots using MapKit and enriches them with xAI Grok API
    /// - Parameters:
    ///   - location: The center location for discovery
    ///   - radius: Search radius in meters (default: 20 miles = 32,186.88 meters)
    /// - Returns: Array of discovered and enriched Spot entities
    func discoverSpots(near location: CLLocation, radius: Double = 32186.88) async -> [Spot] {
        guard let context = managedObjectContext else {
            discoveryError = "Service not configured with Core Data context"
            return []
        }
        
        await MainActor.run {
            isDiscovering = true
            discoveryProgress = 0.0
            discoveryStatus = "Starting discovery..."
            discoveredSpots = []
            discoveryError = nil
        }
        
        // Step 1: Check for existing spots within radius
        print("🔍 Checking for existing spots within \(radius) meters...")
        let existingSpots = await checkExistingSpots(near: location, radius: radius)
        print("🔍 Found \(existingSpots.count) existing spots")
        
        if !existingSpots.isEmpty {
            await MainActor.run {
                discoveryStatus = "Found \(existingSpots.count) existing spots in area"
                discoveredSpots = existingSpots
                discoveryProgress = 1.0
                isDiscovering = false
            }
            return existingSpots
        }
        
        // Step 2: Discover new spots using MapKit
        print("🔍 No existing spots found, starting MapKit discovery...")
        let mapItems = await discoverMapItems(near: location, radius: radius)
        print("🔍 MapKit discovery found \(mapItems.count) map items")
        
        if mapItems.isEmpty {
            await MainActor.run {
                discoveryStatus = "No new spots found in area"
                discoveryProgress = 1.0
                isDiscovering = false
            }
            return []
        }
        
        // Step 3: Enrich spots with Grok API
        let enrichedSpots = await enrichSpotsWithGrokAPI(mapItems: mapItems, totalCount: mapItems.count)
        
        // Step 4: Create Spot entities and save to Core Data
        let savedSpots = await saveDiscoveredSpots(enrichedSpots: enrichedSpots, context: context)
        
        await MainActor.run {
            discoveredSpots = savedSpots
            discoveryStatus = "Discovered \(savedSpots.count) new work spots"
            discoveryProgress = 1.0
            isDiscovering = false
        }
        
        return savedSpots
    }
    
    // MARK: - Private Discovery Methods
    
    private func checkExistingSpots(near location: CLLocation, radius: Double) async -> [Spot] {
        guard let context = managedObjectContext else { return [] }
        
        let fetchRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
        
        do {
            let allSpots = try context.fetch(fetchRequest)
            let nearbySpots = allSpots.filter { spot in
                let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
                return location.distance(from: spotLocation) <= radius
            }
            return nearbySpots
        } catch {
            print("❌ Error checking existing spots: \(error)")
            return []
        }
    }
    
    private func discoverMapItems(near location: CLLocation, radius: Double) async -> [MKMapItem] {
        var allMapItems: [MKMapItem] = []
        
        for (index, category) in discoveryCategories.enumerated() {
            await MainActor.run {
                discoveryStatus = "Searching for \(category)..."
                discoveryProgress = Double(index) / Double(discoveryCategories.count) * 0.5 // 50% of progress
            }
            
            let mapItems = await searchForCategory(category, near: location, radius: radius)
            allMapItems.append(contentsOf: mapItems)
        }
        
        // Remove duplicates based on coordinate proximity
        let uniqueMapItems = removeDuplicateMapItems(allMapItems)
        
        return uniqueMapItems
    }
    
    private func searchForCategory(_ category: String, near location: CLLocation, radius: Double) async -> [MKMapItem] {
        print("🔍 Searching for \(category) near \(location.coordinate) with radius \(radius)")
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = category
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: radius * 2,
            longitudinalMeters: radius * 2
        )
        request.resultTypes = [.pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            let mapItems = Array(response.mapItems.prefix(maxResultsPerCategory))
            print("🔍 Found \(mapItems.count) \(category) items")
            return mapItems
        } catch {
            print("❌ Error searching for \(category): \(error)")
            return []
        }
    }
    
    private func removeDuplicateMapItems(_ mapItems: [MKMapItem]) -> [MKMapItem] {
        var uniqueItems: [MKMapItem] = []
        let proximityThreshold: CLLocationDistance = 50 // 50 meters
        
        for mapItem in mapItems {
            let isDuplicate = uniqueItems.contains { existingItem in
                guard let existingLocation = existingItem.placemark.location,
                      let currentLocation = mapItem.placemark.location else {
                    return false
                }
                return existingLocation.distance(from: currentLocation) < proximityThreshold
            }
            
            if !isDuplicate {
                uniqueItems.append(mapItem)
            }
        }
        
        return uniqueItems
    }
    
    // MARK: - Grok API Integration
    
    private func enrichSpotsWithGrokAPI(mapItems: [MKMapItem], totalCount: Int) async -> [DiscoveryResult] {
        var results: [DiscoveryResult] = []
        
        for (index, mapItem) in mapItems.enumerated() {
            await MainActor.run {
                discoveryStatus = "Enriching spot \(index + 1) of \(totalCount)..."
                discoveryProgress = 0.5 + (Double(index) / Double(totalCount) * 0.4) // 50-90% of progress
            }
            
            let enrichedData = await enrichSpotWithGrokAPI(mapItem: mapItem)
            let result = DiscoveryResult(mapItem: mapItem, enrichedData: enrichedData, error: nil)
            results.append(result)
            
            // Add delay to respect API rate limits
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        }
        
        return results
    }
    
    private func enrichSpotWithGrokAPI(mapItem: MKMapItem) async -> EnrichedSpotData? {
        guard let apiKey = grokAPIKeyValue,
              !apiKey.isEmpty else {
            print("⚠️ Grok API key not found in xcconfig file")
            return createDefaultEnrichedData()
        }
        
        let name = mapItem.name ?? "Unknown"
        let address = formatAddress(from: mapItem.placemark)
        
        let prompt = """
        For \(name) at \(address), estimate WiFi rating (1-5 stars), noise level (Low/Medium/High), plugs (Yes/No), and a short tip based on typical similar venues. Respond in JSON: {"wifi": number, "noise": "string", "plugs": bool, "tip": "string"}.
        """
        
        let requestBody: [String: Any] = [
            "model": grokModel,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 200,
            "temperature": 0.3
        ]
        
        guard let url = URL(string: grokAPIEndpoint) else {
            print("❌ Invalid Grok API endpoint")
            return createDefaultEnrichedData()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ Grok API request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return createDefaultEnrichedData()
            }
            
            let grokResponse = try JSONDecoder().decode(GrokAPIResponse.self, from: data)
            
            if let content = grokResponse.choices.first?.message.content {
                return parseEnrichedData(from: content)
            } else {
                print("❌ No content in Grok API response")
                return createDefaultEnrichedData()
            }
            
        } catch {
            print("❌ Grok API error: \(error)")
            return createDefaultEnrichedData()
        }
    }
    
    private func parseEnrichedData(from content: String) -> EnrichedSpotData? {
        // Extract JSON from the response content
        let jsonPattern = "\\{[^}]*\\}"
        let regex = try? NSRegularExpression(pattern: jsonPattern)
        let range = NSRange(location: 0, length: content.utf16.count)
        
        guard let match = regex?.firstMatch(in: content, options: [], range: range),
              let jsonRange = Range(match.range, in: content) else {
            print("❌ No JSON found in Grok response")
            return createDefaultEnrichedData()
        }
        
        let jsonString = String(content[jsonRange])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("❌ Failed to convert JSON string to data")
            return createDefaultEnrichedData()
        }
        
        do {
            let enrichedData = try JSONDecoder().decode(EnrichedSpotData.self, from: jsonData)
            return enrichedData
        } catch {
            print("❌ Failed to parse enriched data JSON: \(error)")
            return createDefaultEnrichedData()
        }
    }
    
    private func createDefaultEnrichedData() -> EnrichedSpotData {
        return EnrichedSpotData(
            wifi: 3,
            noise: "Medium",
            plugs: false,
            tip: "Auto-discovered"
        )
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String {
        var addressComponents: [String] = []
        
        if let name = placemark.name, name != placemark.locality {
            addressComponents.append(name)
        }
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        
        return addressComponents.joined(separator: ", ")
    }
    
    // MARK: - Core Data Integration
    
    private func saveDiscoveredSpots(enrichedSpots: [DiscoveryResult], context: NSManagedObjectContext) async -> [Spot] {
        var savedSpots: [Spot] = []
        
        await MainActor.run {
            discoveryStatus = "Saving discovered spots..."
            discoveryProgress = 0.9
        }
        
        for result in enrichedSpots {
            do {
                let spot = try createSpotFromDiscoveryResult(result, context: context)
                savedSpots.append(spot)
            } catch {
                print("❌ Failed to create spot from discovery result: \(error)")
            }
        }
        
        // Save context
        do {
            try context.save()
            print("✅ Successfully saved \(savedSpots.count) discovered spots")
        } catch {
            print("❌ Failed to save discovered spots: \(error)")
        }
        
        return savedSpots
    }
    
    private func createSpotFromDiscoveryResult(_ result: DiscoveryResult, context: NSManagedObjectContext) throws -> Spot {
        let mapItem = result.mapItem
        let enrichedData = result.enrichedData ?? createDefaultEnrichedData()
        
        // Check for duplicates by address
        let address = formatAddress(from: mapItem.placemark)
        let fetchRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "address == %@", address)
        
        let existingSpots = try context.fetch(fetchRequest)
        if !existingSpots.isEmpty {
            throw DiscoveryError.coreDataError(NSError(domain: "DuplicateSpot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Spot already exists"]))
        }
        
        // Create new spot
        let spot = Spot(context: context)
        spot.name = mapItem.name ?? "Discovered Spot"
        spot.address = address
        spot.latitude = mapItem.placemark.coordinate.latitude
        spot.longitude = mapItem.placemark.coordinate.longitude
        spot.wifiRating = Int16(enrichedData.wifi)
        spot.noiseRating = enrichedData.noise
        spot.outlets = enrichedData.plugs
        spot.tips = enrichedData.tip
        spot.lastModified = Date()
        // Note: lastSeeded property would need to be added to Spot entity
        // For now, we'll use lastModified to track discovery
        
        return spot
    }
    
    // MARK: - Utility Methods
    
    func clearDiscoveryError() {
        discoveryError = nil
    }
    
    func resetDiscovery() {
        isDiscovering = false
        discoveryProgress = 0.0
        discoveryStatus = ""
        discoveredSpots = []
        discoveryError = nil
    }
    
    // MARK: - API Key Management
    
    func hasGrokAPIKey() -> Bool {
        guard let key = grokAPIKeyValue else { return false }
        return !key.isEmpty && key != "YOUR_GROK_API_KEY_HERE"
    }
    
    func getGrokAPIKeyStatus() -> String {
        if hasGrokAPIKey() {
            return "API key configured"
        } else {
            return "API key not configured - add GROK_API_KEY to secrets.xcconfig"
        }
    }
}

// MARK: - Grok API Response Models

private struct GrokAPIResponse: Codable {
    let choices: [GrokChoice]
}

private struct GrokChoice: Codable {
    let message: GrokMessage
}

private struct GrokMessage: Codable {
    let content: String
}

// MARK: - Extensions

extension SpotDiscoveryService {
    /// Convenience method to discover spots near a coordinate
    func discoverSpots(near coordinate: CLLocationCoordinate2D, radius: Double = 32186.88) async -> [Spot] {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return await discoverSpots(near: location, radius: radius)
    }
    
    /// Get discovery status for UI display
    var isReady: Bool {
        return managedObjectContext != nil && !isDiscovering
    }
    
    /// Get formatted discovery summary
    var discoverySummary: String {
        if discoveredSpots.isEmpty {
            return "No spots discovered yet"
        } else {
            return "Discovered \(discoveredSpots.count) work spots"
        }
    }
}
