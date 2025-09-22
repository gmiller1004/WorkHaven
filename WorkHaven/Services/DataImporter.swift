//
//  DataImporter.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//  Updated to integrate GeocodingService for accurate lat/long coordinates
//
//  This service handles importing work spot data from CSV files and hardcoded data,
//  with integrated geocoding to ensure accurate latitude and longitude coordinates.
//  Features batch processing, rate limiting, and fallback to CSV coordinates.
//

import Foundation
import CoreData
import SwiftUI

class DataImporter: ObservableObject {
    @Published var isImporting = false
    @Published var importProgress: Double = 0.0
    @Published var importStatus = ""
    @Published var availableCities: [String] = ["Boise", "Austin", "Seattle", "Murrieta"]
    
    private let managedObjectContext: NSManagedObjectContext
    private var notificationManager: NotificationManager?
    private nonisolated let geocodingService = GeocodingService.shared
    
    // Geocoding batch settings
    private let geocodingBatchSize = 10
    private let geocodingDelay: UInt64 = 1_000_000_000 // 1 second delay between batches
    
    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }
    
    func configure() async {
        await geocodingService.configure(with: managedObjectContext)
    }
    
    func setNotificationManager(_ manager: NotificationManager) {
        self.notificationManager = manager
    }
    
    // MARK: - Manual Data Management
    
    func clearAllData() async {
        print("🗑️ Clearing all data...")
        
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Spot.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try managedObjectContext.execute(deleteRequest)
            try managedObjectContext.save()
            print("✅ All data cleared successfully")
        } catch {
            print("❌ Error clearing data: \(error)")
        }
    }
    
    // MARK: - Duplicate Cleanup
    
    func cleanupDuplicates() async {
        print("🧹 Starting duplicate cleanup...")
        
        let fetchRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Spot.lastModified, ascending: false)]
        
        do {
            let allSpots = try managedObjectContext.fetch(fetchRequest)
            var seenSpots: Set<String> = []
            var duplicatesToDelete: [Spot] = []
            
            for spot in allSpots {
                let identifier = "\(spot.name ?? "")_\(spot.address ?? "")"
                if seenSpots.contains(identifier) {
                    duplicatesToDelete.append(spot)
                } else {
                    seenSpots.insert(identifier)
                }
            }
            
            for duplicate in duplicatesToDelete {
                managedObjectContext.delete(duplicate)
            }
            
            if !duplicatesToDelete.isEmpty {
                try managedObjectContext.save()
                print("✅ Cleaned up \(duplicatesToDelete.count) duplicate spots")
            } else {
                print("✅ No duplicates found")
            }
            
        } catch {
            print("❌ Error during duplicate cleanup: \(error)")
        }
    }
    
    // MARK: - Import Methods
    
    func importWorkSpaces(from fileName: String) async {
        await performImport(from: fileName)
    }
    
    func importBoiseWorkSpaces(from fileName: String = "Boise_Work_Spots") async {
        await performImport(from: fileName)
    }
    
    func importWorkSpaces(for city: String) async {
        let fileName = "\(city)_Work_Spots"
        await performImport(from: fileName)
    }
    
    func importAllAvailableCities() async {
        let cities = ["Boise", "Austin", "Seattle", "Murrieta"]
        for city in cities {
            await importWorkSpaces(for: city)
        }
    }
    
    private func performImport(from fileName: String) async {
        // Prevent multiple simultaneous imports
        guard !isImporting else {
            print("⚠️ Import already in progress, skipping duplicate import request for \(fileName)")
            return
        }
        
        print("🔒 Starting import guard for \(fileName) - isImporting: \(isImporting)")
        
        await MainActor.run {
            isImporting = true
            importProgress = 0.0
            importStatus = "Starting import..."
        }
        
        print("🔄 Starting import from file: \(fileName)")
        
        // Check if we already have spots from this specific city
        let cityName = fileName.replacingOccurrences(of: "_Work_Spots", with: "")
        let existingSpotsRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
        existingSpotsRequest.predicate = NSPredicate(format: "address CONTAINS[cd] %@", cityName)
        existingSpotsRequest.fetchLimit = 1
        do {
            let existingSpots = try managedObjectContext.fetch(existingSpotsRequest)
            if !existingSpots.isEmpty {
                print("📊 Found existing spots for \(cityName), skipping import to prevent duplicates")
                await MainActor.run {
                    importStatus = "Skipped import - \(cityName) spots already exist"
                    isImporting = false
                }
                return
            }
        } catch {
            print("Error checking for existing spots: \(error)")
        }
        
        // First, clean up any existing duplicates
        await cleanupDuplicates()
        
        // Try to load from CSV file first
        var spots: [CSVSpot] = []
        
        do {
            guard let csvData = try loadCSVFile(fileName: fileName) else {
                throw DataImporterError.fileNotFound
            }
            spots = try parseCSVData(csvData)
            await MainActor.run {
                importStatus = "Loading data from CSV file..."
            }
        } catch {
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
        var validRowCount = 0
        var errorCount = 0
        
        for (index, line) in dataLines.enumerated() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            let columns = parseCSVLine(line)
            guard columns.count >= 7 else {
                print("❌ ERROR: Line \(index + 2) - Insufficient columns (expected 7, got \(columns.count)): \(line)")
                errorCount += 1
                continue
            }
            
            let name = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let city = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let wifiRating = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let noiseRating = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let photoURL = columns[4].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : columns[4].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Parse latitude and longitude (allow missing/invalid values for geocoding)
            let latitudeString = columns[5].trimmingCharacters(in: .whitespacesAndNewlines)
            let longitudeString = columns[6].trimmingCharacters(in: .whitespacesAndNewlines)
            
            var latitude: Double = 0.0
            var longitude: Double = 0.0
            var needsGeocoding = false
            
            if let lat = Double(latitudeString), let lng = Double(longitudeString) {
                if isValidLatitude(lat) && isValidLongitude(lng) {
                    latitude = lat
                    longitude = lng
                } else {
                    print("⚠️ WARNING: Line \(index + 2) - Invalid coordinates for '\(name)': lat=\(lat), lng=\(lng), will geocode")
                    needsGeocoding = true
                }
            } else {
                print("⚠️ WARNING: Line \(index + 2) - Missing coordinates for '\(name)', will geocode")
                needsGeocoding = true
            }
            
            // Validate required fields
            guard !name.isEmpty else {
                print("❌ ERROR: Line \(index + 2) - Empty name field")
                errorCount += 1
                continue
            }
            
            let spot = CSVSpot(
                name: name,
                city: city,
                wifiRating: wifiRating,
                noiseRating: noiseRating,
                photoURL: photoURL,
                latitude: latitude,
                longitude: longitude,
                needsGeocoding: needsGeocoding
            )
            
            spots.append(spot)
            validRowCount += 1
        }
        
        print("📊 CSV Import Summary: \(validRowCount) valid rows, \(errorCount) errors")
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
        
        var importedCount = 0
        var skippedCount = 0
        var errorCount = 0
        var geocodingCount = 0
        
        // Separate spots that need geocoding
        let spotsNeedingGeocoding = csvSpots.filter { $0.needsGeocoding }
        let spotsWithCoordinates = csvSpots.filter { !$0.needsGeocoding }
        
        print("📍 Geocoding needed for \(spotsNeedingGeocoding.count) spots")
        print("📍 Using existing coordinates for \(spotsWithCoordinates.count) spots")
        
        // First, import spots with existing coordinates
        for (index, csvSpot) in spotsWithCoordinates.enumerated() {
            let result = await createSpotFromCSV(csvSpot)
            switch result {
            case .success:
                importedCount += 1
            case .skipped:
                skippedCount += 1
            case .error:
                errorCount += 1
            }
            
            // Update progress
            let progress = Double(index + 1) / Double(csvSpots.count)
            await MainActor.run {
                importProgress = progress * 0.5 // First half for existing coordinates
                importStatus = "Imported \(importedCount) of \(csvSpots.count) spots... (Skipped: \(skippedCount))"
            }
        }
        
        // Then, geocode and import spots that need coordinates
        if !spotsNeedingGeocoding.isEmpty {
            await MainActor.run {
                importStatus = "Geocoding \(spotsNeedingGeocoding.count) spots for accurate coordinates..."
            }
            
            geocodingCount = await geocodeAndImportSpots(spotsNeedingGeocoding, totalSpots: csvSpots.count, importedCount: importedCount)
        }
        
        // Save context
        do {
            try managedObjectContext.save()
            print("✅ Successfully saved \(importedCount + geocodingCount) spots to Core Data (Skipped: \(skippedCount), Errors: \(errorCount))")
        } catch {
            print("❌ ERROR: Failed to save context: \(error)")
        }
    }
    
    private func geocodeAndImportSpots(_ spots: [CSVSpot], totalSpots: Int, importedCount: Int) async -> Int {
        var geocodingCount = 0
        let batchCount = (spots.count + geocodingBatchSize - 1) / geocodingBatchSize
        
        for batchIndex in 0..<batchCount {
            let startIndex = batchIndex * geocodingBatchSize
            let endIndex = min(startIndex + geocodingBatchSize, spots.count)
            let batch = Array(spots[startIndex..<endIndex])
            
            print("📍 Geocoding batch \(batchIndex + 1)/\(batchCount) (\(batch.count) spots)")
            
            for (index, csvSpot) in batch.enumerated() {
                let address = "\(csvSpot.name), \(csvSpot.city)"
                print("🔍 Geocoding: \(address)")
                
                do {
                    let placemarks = try await geocodingService.geocodeAddress(address)
                    
                    if let placemark = placemarks.first, let location = placemark.location {
                        // Update CSV spot with geocoded coordinates
                        let updatedSpot = CSVSpot(
                            name: csvSpot.name,
                            city: csvSpot.city,
                            wifiRating: csvSpot.wifiRating,
                            noiseRating: csvSpot.noiseRating,
                            photoURL: csvSpot.photoURL,
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            needsGeocoding: false
                        )
                        
                        let result = await createSpotFromCSV(updatedSpot)
                        switch result {
                        case .success:
                            geocodingCount += 1
                            print("✅ Geocoded: \(address) -> \(location.coordinate.latitude), \(location.coordinate.longitude)")
                        case .skipped:
                            print("⚠️ Skipped geocoded spot: \(address)")
                        case .error:
                            print("❌ Error creating geocoded spot: \(address)")
                        }
                    } else {
                        print("❌ No geocoding results for: \(address), using CSV coordinates")
                        // Fallback to CSV coordinates (even if 0,0)
                        let result = await createSpotFromCSV(csvSpot)
                        switch result {
                        case .success:
                            geocodingCount += 1
                        case .skipped:
                            break
                        case .error:
                            break
                        }
                    }
                } catch {
                    print("❌ Geocoding failed for \(address): \(error.localizedDescription), using CSV coordinates")
                    // Fallback to CSV coordinates
                    let result = await createSpotFromCSV(csvSpot)
                    switch result {
                    case .success:
                        geocodingCount += 1
                    case .skipped:
                        break
                    case .error:
                        break
                    }
                }
                
                // Update progress
                let currentIndex = importedCount + (batchIndex * geocodingBatchSize) + index + 1
                let progress = Double(currentIndex) / Double(totalSpots)
                await MainActor.run {
                    importProgress = progress
                    importStatus = "Geocoded \(geocodingCount) of \(spots.count) spots... (Total: \(importedCount + geocodingCount))"
                }
            }
            
            // Rate limiting delay between batches
            if batchIndex < batchCount - 1 {
                print("⏳ Rate limiting: waiting 1 second before next batch...")
                try? await Task.sleep(nanoseconds: geocodingDelay)
            }
        }
        
        return geocodingCount
    }
    
    private func createSpotFromCSV(_ csvSpot: CSVSpot) async -> ImportResult {
        // Enhanced deduplication: check by name AND city (since we use city as address)
        let fetchRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND address == %@", csvSpot.name, csvSpot.city)
        
        do {
            let existingSpots = try managedObjectContext.fetch(fetchRequest)
            if !existingSpots.isEmpty {
                print("⚠️ WARNING: Spot '\(csvSpot.name)' in '\(csvSpot.city)' already exists (found \(existingSpots.count) duplicates), skipping...")
                return .skipped
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
            spot.lastModified = Date() // Set modification date for notifications
            
            // Trigger notifications for new spots
            DispatchQueue.main.async {
                self.notificationManager?.scheduleNewSpotNotification(for: spot)
                
                // Check if it's a hot spot
                if spot.wifiRating >= 4 {
                    self.notificationManager?.scheduleHotSpotNotification(for: spot)
                }
                
                // Check if it's nearby for location-based notifications
                self.notificationManager?.scheduleLocationBasedNotification(for: spot)
            }
            
            return .success
            
        } catch {
            print("❌ ERROR: Failed to create spot '\(csvSpot.name)': \(error)")
            return .error
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
            return "Medium" // Default to medium
        }
    }
    
    private func determineOutletsAvailability(_ name: String, wifiRating: String) -> Bool {
        // Simple heuristic: if WiFi is good, likely has outlets
        let wifiScore = mapWiFiRating(wifiRating)
        return wifiScore >= 4
    }
    
    private func generateTips(for csvSpot: CSVSpot) -> String {
        var tips: [String] = []
        
        // WiFi tips
        switch csvSpot.wifiRating.lowercased() {
        case "fast", "strong":
            tips.append("Excellent WiFi speed")
        case "available", "open":
            tips.append("Good WiFi available")
        case "free":
            tips.append("Free WiFi")
        case "slow":
            tips.append("WiFi can be slow")
        default:
            break
        }
        
        // Noise tips
        switch csvSpot.noiseRating.lowercased() {
        case "low":
            tips.append("Quiet environment")
        case "high":
            tips.append("Can be noisy")
        default:
            break
        }
        
        // Outlet tips
        if determineOutletsAvailability(csvSpot.name, wifiRating: csvSpot.wifiRating) {
            tips.append("Power outlets available")
        }
        
        return tips.joined(separator: ". ")
    }
    
    // MARK: - Validation Functions
    
    private func isValidLatitude(_ latitude: Double) -> Bool {
        return latitude >= -90.0 && latitude <= 90.0
    }
    
    private func isValidLongitude(_ longitude: Double) -> Bool {
        return longitude >= -180.0 && longitude <= 180.0
    }
    
    // MARK: - Hardcoded Data (Fallback)
    
    private func getHardcodedBoiseSpots() -> [CSVSpot] {
        return [
            CSVSpot(name: "Neckar Coffee", city: "Boise ID", wifiRating: "Strong", noiseRating: "Low", photoURL: nil, latitude: 43.6150, longitude: -116.2023, needsGeocoding: false),
            CSVSpot(name: "Flying M Coffee", city: "Boise ID", wifiRating: "Available", noiseRating: "Medium", photoURL: nil, latitude: 43.6125, longitude: -116.2025, needsGeocoding: false),
            CSVSpot(name: "Dawson Taylor Coffee", city: "Boise ID", wifiRating: "Fast", noiseRating: "Low", photoURL: nil, latitude: 43.6140, longitude: -116.2010, needsGeocoding: false)
        ]
    }
}

// MARK: - Supporting Types

struct CSVSpot {
    let name: String
    let city: String
    let wifiRating: String
    let noiseRating: String
    let photoURL: String?
    let latitude: Double
    let longitude: Double
    let needsGeocoding: Bool
}

enum ImportResult {
    case success
    case skipped
    case error
}

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