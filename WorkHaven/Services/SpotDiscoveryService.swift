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

class SpotDiscoveryService: ObservableObject {
    @Published var isDiscovering = false
    @Published var discoveredSpots: [Spot] = []
    @Published var discoveryError: DiscoveryError?
    
    private var managedObjectContext: NSManagedObjectContext?
    private var _cachedAPIKey: String?
    private var _apiKeyChecked = false
    
    static let shared = SpotDiscoveryService()
    
    private init() {}
    
    func configure(with context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }
    
    // MARK: - Main Discovery Function
    
    func discoverSpots(near location: CLLocation, radius: Double = 32186.88) async -> [Spot] {
        guard let context = managedObjectContext else {
            print("❌ No managed object context available")
            return []
        }
        
        await MainActor.run {
            isDiscovering = true
            discoveryError = nil
        }
        
        do {
            // Check if we already have spots in the area
            let existingSpots = try await checkExistingSpots(near: location, radius: radius, context: context)
            if !existingSpots.isEmpty {
                print("📍 Found \(existingSpots.count) existing spots in area")
                await MainActor.run {
                    discoveredSpots = existingSpots
                    isDiscovering = false
                }
                return existingSpots
            }
            
            // Discover new spots using MapKit
            let searchResults = try await performMapKitSearch(near: location)
            print("🔍 Found \(searchResults.count) potential spots from MapKit")
            
            // Enrich spots with Grok API
            let enrichedSpots = await enrichSpotsWithGrokAPI(searchResults)
            print("🤖 Enriched \(enrichedSpots.count) spots with AI data")
            
            // Save to Core Data
            let savedSpots = try await saveSpotsToCoreData(enrichedSpots, context: context)
            print("💾 Saved \(savedSpots.count) spots to database")
            
            await MainActor.run {
                discoveredSpots = savedSpots
                isDiscovering = false
            }
            
            return savedSpots
            
        } catch {
            print("❌ Discovery failed: \(error)")
            await MainActor.run {
                discoveryError = .networkError(error)
                isDiscovering = false
            }
            return []
        }
    }
    
    // MARK: - MapKit Search
    
    private func performMapKitSearch(near location: CLLocation) async throws -> [MKMapItem] {
        let searchCategories = ["coffee shop", "library", "park", "co-working space"]
        var allResults: [MKMapItem] = []
        
        for category in searchCategories {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = category
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 32186.88, // 20 miles
                longitudinalMeters: 32186.88
            )
            
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            allResults.append(contentsOf: response.mapItems)
        }
        
        // Remove duplicates and limit results
        var uniqueResults: [MKMapItem] = []
        var seenCoordinates: Set<String> = []
        
        for mapItem in allResults {
            let coordinate = mapItem.placemark.coordinate
            let coordinateKey = "\(coordinate.latitude),\(coordinate.longitude)"
            
            if !seenCoordinates.contains(coordinateKey) {
                seenCoordinates.insert(coordinateKey)
                uniqueResults.append(mapItem)
                
                if uniqueResults.count >= 15 {
                    break
                }
            }
        }
        
        return Array(uniqueResults)
    }
    
    // MARK: - Grok API Enrichment
    
    private func enrichSpotsWithGrokAPI(_ mapItems: [MKMapItem]) async -> [DiscoveryResult] {
        var results: [DiscoveryResult] = []
        
        for mapItem in mapItems {
            let enrichedData = await enrichSpotWithGrokAPI(mapItem: mapItem)
            let result = DiscoveryResult(
                mapItem: mapItem,
                enrichedData: enrichedData,
                error: nil
            )
            results.append(result)
        }
        
        return results
    }
    
    private func enrichSpotWithGrokAPI(mapItem: MKMapItem) async -> EnrichedSpotData? {
        guard hasGrokAPIKey() else {
            print("⚠️ No Grok API key available")
            return createDefaultEnrichedData()
        }
        
        guard let name = mapItem.name,
              let address = mapItem.placemark.title else {
            return createDefaultEnrichedData()
        }
        
        let prompt = """
        For \(name) at \(address), estimate WiFi rating (1-5 stars), noise level (Low/Medium/High), plugs (Yes/No), and a short tip based on typical similar venues. Respond in JSON: {"wifi": number, "noise": "string", "plugs": bool, "tip": "string"}.
        """
        
        do {
            let response = try await callGrokAPI(prompt: prompt)
            return parseGrokResponse(response)
        } catch {
            print("❌ Grok API error for \(name): \(error)")
            return createDefaultEnrichedData()
        }
    }
    
    private func callGrokAPI(prompt: String) async throws -> String {
        guard let apiKey = grokAPIKeyValue else {
            throw DiscoveryError.apiFailure("No API key available")
        }
        
        let url = URL(string: "https://api.x.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "grok-4-fast-non-reasoning",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DiscoveryError.apiFailure("HTTP error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        
        let grokResponse = try JSONDecoder().decode(GrokAPIResponse.self, from: data)
        return grokResponse.choices.first?.message.content ?? ""
    }
    
    private func parseGrokResponse(_ response: String) -> EnrichedSpotData? {
        // Extract JSON from response
        let jsonStart = response.firstIndex(of: "{") ?? response.startIndex
        let jsonEnd = response.lastIndex(of: "}") ?? response.endIndex
        let jsonString = String(response[jsonStart...jsonEnd])
        
        guard let data = jsonString.data(using: .utf8) else {
            return createDefaultEnrichedData()
        }
        
        do {
            let enrichedData = try JSONDecoder().decode(EnrichedSpotData.self, from: data)
            return enrichedData
        } catch {
            print("❌ Failed to parse Grok response: \(error)")
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
    
    // MARK: - Core Data Operations
    
    private func checkExistingSpots(near location: CLLocation, radius: Double, context: NSManagedObjectContext) async throws -> [Spot] {
        let fetchRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
        let spots = try context.fetch(fetchRequest)
        
        return spots.filter { spot in
            let spotLocation = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
            return location.distance(from: spotLocation) <= radius
        }
    }
    
    private func saveSpotsToCoreData(_ results: [DiscoveryResult], context: NSManagedObjectContext) async throws -> [Spot] {
        var savedSpots: [Spot] = []
        
        for result in results {
            let spot = createSpotFromDiscoveryResult(result, context: context)
            savedSpots.append(spot)
        }
        
        try context.save()
        return savedSpots
    }
    
    private func createSpotFromDiscoveryResult(_ result: DiscoveryResult, context: NSManagedObjectContext) -> Spot {
        let spot = Spot(context: context)
        let mapItem = result.mapItem
        let enrichedData = result.enrichedData ?? createDefaultEnrichedData()
        
        // Basic info from MapKit
        spot.name = mapItem.name ?? "Unknown"
        spot.address = mapItem.placemark.title ?? "Unknown Address"
        spot.latitude = mapItem.placemark.coordinate.latitude
        spot.longitude = mapItem.placemark.coordinate.longitude
        
        // Business info from MapKit (reliable data only)
        if let phoneNumber = mapItem.phoneNumber, !phoneNumber.isEmpty {
            spot.phoneNumber = phoneNumber
        }
        if let url = mapItem.url, !url.absoluteString.isEmpty {
            spot.websiteURL = url.absoluteString
        }
        
        // Only use Grok for WiFi, noise, and outlets (not hours/images)
        spot.wifiRating = Int16(enrichedData.wifi)
        spot.noiseRating = enrichedData.noise
        spot.outlets = enrichedData.plugs
        spot.tips = enrichedData.tip
        
        // Don't use Grok for hours and images - they're unreliable
        // spot.businessHours = enrichedData.hours
        // spot.businessImageURL = enrichedData.image_url
        
        spot.lastModified = Date()
        
        return spot
    }
    
    // MARK: - Data Migration
    
    func migrateExistingSpots() async {
        guard let context = managedObjectContext else { return }
        
        let fetchRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "phoneNumber == nil OR websiteURL == nil")
        
        do {
            let spotsToMigrate = try context.fetch(fetchRequest)
            print("🔄 Migrating \(spotsToMigrate.count) existing spots with new business fields...")
            
            // Process in smaller batches to avoid overwhelming the system
            let batchSize = 10
            let batches = spotsToMigrate.chunked(into: batchSize)
            
            for (batchIndex, batch) in batches.enumerated() {
                print("📦 Processing batch \(batchIndex + 1)/\(batches.count) (\(batch.count) spots)")
                
                for (index, spot) in batch.enumerated() {
                    // Add delay to avoid rate limiting (50 requests per 60 seconds)
                    if index > 0 {
                        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds delay
                    }
                    
                    // Try to find the spot using MKLocalSearch to get fresh business data
                    if let name = spot.name, let address = spot.address {
                        let searchRequest = MKLocalSearch.Request()
                        searchRequest.naturalLanguageQuery = "\(name) \(address)"
                        searchRequest.region = MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                            latitudinalMeters: 1000,
                            longitudinalMeters: 1000
                        )
                        
                        let search = MKLocalSearch(request: searchRequest)
                        let response = try await search.start()
                        
                        if let mapItem = response.mapItems.first {
                            // Update spot with fresh business data from MKMapItem
                            if let phoneNumber = mapItem.phoneNumber, !phoneNumber.isEmpty {
                                spot.phoneNumber = phoneNumber
                            }
                            if let url = mapItem.url, !url.absoluteString.isEmpty {
                                spot.websiteURL = url.absoluteString
                            }
                            
                            // Note: Not using Grok for hours/images as they're unreliable
                            // Apple Maps doesn't provide these directly through MKMapItem
                            
                            print("✅ Migrated business data for: \(name)")
                        }
                    }
                }
                
                // Save after each batch
                try context.save()
                print("✅ Batch \(batchIndex + 1) completed and saved")
                
                // Longer delay between batches
                if batchIndex < batches.count - 1 {
                    try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds between batches
                }
            }
            
            print("✅ Migration completed successfully!")
            
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    
    func clearDiscoveryError() {
        discoveryError = nil
    }
    
    // MARK: - API Key Management
    
    private var grokAPIKeyValue: String? {
        if _apiKeyChecked {
            return _cachedAPIKey
        }
        
        _apiKeyChecked = true
        
        // Try to get from xcconfig first
        if let xcconfigKey = Bundle.main.object(forInfoDictionaryKey: "GROK_API_KEY") as? String,
           !xcconfigKey.isEmpty && xcconfigKey != "YOUR_GROK_API_KEY_HERE" {
            _cachedAPIKey = xcconfigKey
            print("✅ Found Grok API key in xcconfig: \(String(xcconfigKey.prefix(10)))...")
            return _cachedAPIKey
        }
        
        // Fallback to Info.plist
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "GROK_API_KEY") as? String,
           !plistKey.isEmpty && plistKey != "YOUR_GROK_API_KEY_HERE" {
            _cachedAPIKey = plistKey
            print("✅ Found Grok API key in Info.plist: \(String(plistKey.prefix(10)))...")
            return _cachedAPIKey
        }
        
        print("❌ Grok API key not found in xcconfig or Info.plist")
        return nil
    }
    
    func hasGrokAPIKey() -> Bool {
        return grokAPIKeyValue != nil
    }
    
    var apiKeyStatus: String {
        if hasGrokAPIKey() {
            return "API key configured"
        } else {
            return "API key not configured - add GROK_API_KEY to secrets.xcconfig"
        }
    }
}

// MARK: - Array Extension for Batching

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - SpotDiscoveryService Extensions

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