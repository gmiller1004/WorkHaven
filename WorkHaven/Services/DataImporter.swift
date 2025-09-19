//
//  DataImporter.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import Foundation
import CoreData
import SwiftUI

class DataImporter: ObservableObject {
    @Published var isImporting = false
    @Published var importProgress: Double = 0.0
    @Published var importStatus = ""
    
    private let managedObjectContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }
    
    // MARK: - CSV Import Functions
    
    func importBoiseWorkSpaces(from fileName: String = "Boise_Work_Spots") async {
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
            importStatus = "Starting import..."
        }
        
        do {
            // Try to load from CSV file first
            var spots: [CSVSpot] = []
            
            if let csvData = try? loadCSVFile(fileName: fileName) {
                spots = try parseCSVData(csvData)
            } else {
                // Fallback to hardcoded data if CSV file not found
                await MainActor.run {
                    importStatus = "CSV file not found, using built-in data..."
                }
                spots = getHardcodedBoiseSpots()
            }
            
            await importSpotsToCoreData(spots)
            
            await MainActor.run {
                importStatus = "Import completed successfully! \(spots.count) spots imported."
                isImporting = false
                importProgress = 1.0
            }
            
        } catch {
            await MainActor.run {
                importStatus = "Import failed: \(error.localizedDescription)"
                isImporting = false
            }
        }
    }
    
    private func loadCSVFile(fileName: String) throws -> Data? {
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: "csv") else {
            // Try alternative approach - look for the file in the main bundle
            guard let path = Bundle.main.path(forResource: fileName, ofType: "csv") else {
                throw DataImporterError.fileNotFound
            }
            return try Data(contentsOf: URL(fileURLWithPath: path))
        }
        
        return try Data(contentsOf: fileURL)
    }
    
    private func parseCSVData(_ data: Data) throws -> [CSVSpot] {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw DataImporterError.invalidData
        }
        
        let lines = csvString.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            throw DataImporterError.emptyFile
        }
        
        // Skip header row
        let dataLines = Array(lines.dropFirst())
        var spots: [CSVSpot] = []
        
        for (index, line) in dataLines.enumerated() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let columns = parseCSVLine(line)
            guard columns.count >= 7 else {
                print("Warning: Skipping line \(index + 2) - insufficient columns: \(line)")
                continue
            }
            
            let spot = CSVSpot(
                name: columns[0].trimmingCharacters(in: .whitespacesAndNewlines),
                city: columns[1].trimmingCharacters(in: .whitespacesAndNewlines),
                wifiRating: columns[2].trimmingCharacters(in: .whitespacesAndNewlines),
                noiseRating: columns[3].trimmingCharacters(in: .whitespacesAndNewlines),
                photoURL: columns[4].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : columns[4].trimmingCharacters(in: .whitespacesAndNewlines),
                latitude: Double(columns[5].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0,
                longitude: Double(columns[6].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
            )
            
            spots.append(spot)
        }
        
        return spots
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        
        for character in line {
            if character == "\"" {
                insideQuotes.toggle()
            } else if character == "," && !insideQuotes {
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(character)
            }
        }
        
        // Add the last column
        columns.append(currentColumn)
        
        return columns
    }
    
    private func importSpotsToCoreData(_ csvSpots: [CSVSpot]) async {
        await MainActor.run {
            importStatus = "Importing spots to Core Data..."
        }
        
        for (index, csvSpot) in csvSpots.enumerated() {
            // Check if spot already exists
            let fetchRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", csvSpot.name)
            
            do {
                let existingSpots = try managedObjectContext.fetch(fetchRequest)
                if !existingSpots.isEmpty {
                    print("Spot '\(csvSpot.name)' already exists, skipping...")
                    continue
                }
                
                // Create new spot
                let spot = Spot(context: managedObjectContext)
                spot.name = csvSpot.name
                spot.address = csvSpot.city
                spot.latitude = csvSpot.latitude
                spot.longitude = csvSpot.longitude
                spot.wifiRating = mapWiFiRating(csvSpot.wifiRating)
                spot.noiseRating = mapNoiseRating(csvSpot.noiseRating)
                spot.outlets = determineOutletsAvailability(csvSpot.name, wifiRating: csvSpot.wifiRating)
                spot.tips = generateTips(for: csvSpot)
                spot.photoURL = csvSpot.photoURL
                
                // Update progress
                let progress = Double(index + 1) / Double(csvSpots.count)
                await MainActor.run {
                    importProgress = progress
                    importStatus = "Imported \(index + 1) of \(csvSpots.count) spots..."
                }
                
            } catch {
                print("Error creating spot '\(csvSpot.name)': \(error)")
            }
        }
        
        // Save context
        do {
            try managedObjectContext.save()
            print("Successfully saved \(csvSpots.count) spots to Core Data")
        } catch {
            print("Error saving context: \(error)")
        }
    }
    
    // MARK: - Data Mapping Functions
    
    private func mapWiFiRating(_ csvRating: String) -> Int16 {
        switch csvRating.lowercased() {
        case "fast", "strong":
            return 5
        case "available", "open":
            return 4
        case "free":
            return 3
        case "slow":
            return 2
        default:
            return 3 // Default to medium rating
        }
    }
    
    private func mapNoiseRating(_ csvRating: String) -> String {
        switch csvRating.lowercased() {
        case "low":
            return "Low"
        case "medium":
            return "Medium"
        case "high":
            return "High"
        case "variable":
            return "Medium" // Default variable to medium
        default:
            return "Low" // Default to low
        }
    }
    
    private func determineOutletsAvailability(_ name: String, wifiRating: String) -> Bool {
        // Most coffee shops and work spaces have outlets
        let outletKeywords = ["coffee", "cafe", "coffee house", "roasting", "studio", "hotel", "library"]
        let hasOutletKeyword = outletKeywords.contains { keyword in
            name.lowercased().contains(keyword)
        }
        
        // Parks typically don't have outlets
        let noOutletKeywords = ["park"]
        let hasNoOutletKeyword = noOutletKeywords.contains { keyword in
            name.lowercased().contains(keyword)
        }
        
        return hasOutletKeyword && !hasNoOutletKeyword
    }
    
    private func generateTips(for csvSpot: CSVSpot) -> String? {
        var tips: [String] = []
        
        // WiFi-specific tips
        switch csvSpot.wifiRating.lowercased() {
        case "fast", "strong":
            tips.append("Excellent WiFi speed - great for video calls")
        case "available", "open":
            tips.append("Reliable WiFi available")
        case "free":
            tips.append("Free WiFi - no purchase required")
        case "slow":
            tips.append("WiFi can be slow during peak hours")
        default:
            break
        }
        
        // Noise-specific tips
        switch csvSpot.noiseRating.lowercased() {
        case "low":
            tips.append("Quiet environment - perfect for focused work")
        case "medium":
            tips.append("Moderate noise level - bring headphones")
        case "high":
            tips.append("Can get noisy - not ideal for calls")
        case "variable":
            tips.append("Noise level varies throughout the day")
        default:
            break
        }
        
        // Location-specific tips
        if csvSpot.name.lowercased().contains("park") {
            tips.append("Outdoor workspace - weather dependent")
        }
        
        if csvSpot.name.lowercased().contains("hotel") {
            tips.append("Hotel lobby - may require purchase")
        }
        
        if csvSpot.name.lowercased().contains("library") {
            tips.append("Library environment - maintain quiet voices")
        }
        
        // Boise-specific tips
        if csvSpot.name == "Neckar Coffee" {
            tips.append("Popular local spot - can get busy")
        }
        
        if csvSpot.name == "JUMP" {
            tips.append("Modern co-working space with amenities")
        }
        
        return tips.isEmpty ? nil : tips.joined(separator: " • ")
    }
    
    // MARK: - Hardcoded Data
    
    private func getHardcodedBoiseSpots() -> [CSVSpot] {
        return [
            CSVSpot(name: "Neckar Coffee", city: "Boise ID", wifiRating: "Fast", noiseRating: "Low", photoURL: nil, latitude: 43.6187, longitude: -116.2146),
            CSVSpot(name: "Broadcast Coffee", city: "Boise ID", wifiRating: "Available", noiseRating: "Medium", photoURL: nil, latitude: 43.6135, longitude: -116.2034),
            CSVSpot(name: "Push & Pour", city: "Boise ID", wifiRating: "Available", noiseRating: "Medium", photoURL: nil, latitude: 43.5904, longitude: -116.2796),
            CSVSpot(name: "Flying M", city: "Boise ID", wifiRating: "Available", noiseRating: "Medium", photoURL: nil, latitude: 43.6154, longitude: -116.2020),
            CSVSpot(name: "Alchemist Coffee Roasting Co", city: "Boise ID", wifiRating: "Available", noiseRating: "Low", photoURL: nil, latitude: 43.6218, longitude: -116.3125),
            CSVSpot(name: "Coffee Studio", city: "Boise ID", wifiRating: "Available", noiseRating: "Low", photoURL: nil, latitude: 43.6047, longitude: -116.2437),
            CSVSpot(name: "The District Coffee House", city: "Boise ID", wifiRating: "Available", noiseRating: "Low", photoURL: nil, latitude: 43.6129, longitude: -116.2115),
            CSVSpot(name: "Hyde Perk Coffee House", city: "Boise ID", wifiRating: "Available", noiseRating: "Low", photoURL: nil, latitude: 43.5898, longitude: -116.1956),
            CSVSpot(name: "Slow By Slow Coffee Bar", city: "Boise ID", wifiRating: "Available", noiseRating: "Low", photoURL: nil, latitude: 43.6182, longitude: -116.2008),
            CSVSpot(name: "Ann Morrison Park", city: "Boise ID", wifiRating: "Free", noiseRating: "Variable", photoURL: nil, latitude: 43.6097, longitude: -116.2278),
            CSVSpot(name: "Julia Davis Park", city: "Boise ID", wifiRating: "Free", noiseRating: "Variable", photoURL: nil, latitude: 43.6142, longitude: -116.1975),
            CSVSpot(name: "Cherie Buckner Webb Park", city: "Boise ID", wifiRating: "Free", noiseRating: "Variable", photoURL: nil, latitude: 43.6105, longitude: -116.2031),
            CSVSpot(name: "Library! at Cole & Ustick", city: "Boise ID", wifiRating: "Available", noiseRating: "Low", photoURL: nil, latitude: 43.6337, longitude: -116.2794),
            CSVSpot(name: "The Grove Hotel Lobby", city: "Boise ID", wifiRating: "Strong", noiseRating: "Low", photoURL: nil, latitude: 43.6158, longitude: -116.2012),
            CSVSpot(name: "JUMP", city: "Boise ID", wifiRating: "Open", noiseRating: "Variable", photoURL: nil, latitude: 43.6138, longitude: -116.2087),
            CSVSpot(name: "PINE", city: "Boise ID", wifiRating: "Available", noiseRating: "Low", photoURL: "https://pinecoffeesupply.com/pages/boise-id", latitude: 43.6175, longitude: -116.2063),
            CSVSpot(name: "Zero Six Coffee Fix", city: "Boise ID", wifiRating: "Available", noiseRating: "Medium", photoURL: "https://boise.citycast.fm/best/coffee-shops-study-remote-work", latitude: 43.6121, longitude: -116.2110)
        ]
    }
    
    // MARK: - Utility Functions
    
    func clearAllSpots() async {
        await MainActor.run {
            importStatus = "Clearing all spots..."
        }
        
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Spot.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try managedObjectContext.execute(deleteRequest)
            try managedObjectContext.save()
            
            await MainActor.run {
                importStatus = "All spots cleared successfully"
            }
        } catch {
            await MainActor.run {
                importStatus = "Error clearing spots: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Data Models

struct CSVSpot {
    let name: String
    let city: String
    let wifiRating: String
    let noiseRating: String
    let photoURL: String?
    let latitude: Double
    let longitude: Double
}

// MARK: - Error Types

enum DataImporterError: LocalizedError {
    case fileNotFound
    case invalidData
    case emptyFile
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "CSV file not found in app bundle"
        case .invalidData:
            return "Invalid data format in CSV file"
        case .emptyFile:
            return "CSV file is empty"
        case .parsingError:
            return "Error parsing CSV data"
        }
    }
}
