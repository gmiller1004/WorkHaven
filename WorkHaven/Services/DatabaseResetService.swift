//
//  DatabaseResetService.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//  Comprehensive database reset service for WorkHaven
//
//  This service provides methods to reset the database at different levels:
//  - Local Core Data only
//  - CloudKit only  
//  - Complete reset (both local and CloudKit)
//  - Reset with CloudKit environment reset
//

import Foundation
import CoreData
import CloudKit
import SwiftUI

@MainActor
class DatabaseResetService: ObservableObject {
    @Published var isResetting = false
    @Published var resetProgress: Double = 0.0
    @Published var resetStatus = ""
    @Published var resetError: String?
    
    private let managedObjectContext: NSManagedObjectContext
    private let cloudKitManager: CloudKitManager
    
    init(context: NSManagedObjectContext, cloudKitManager: CloudKitManager) {
        self.managedObjectContext = context
        self.cloudKitManager = cloudKitManager
    }
    
    // MARK: - Reset Options
    
    /// Reset local Core Data only (keeps CloudKit intact)
    func resetLocalDataOnly() async {
        await performReset(type: .localOnly)
    }
    
    /// Reset CloudKit only (keeps local data intact)
    func resetCloudKitOnly() async {
        await performReset(type: .cloudKitOnly)
    }
    
    /// Complete reset (both local and CloudKit)
    func resetEverything() async {
        await performReset(type: .complete)
    }
    
    /// Reset with CloudKit environment reset (for development)
    func resetWithCloudKitEnvironmentReset() async {
        await performReset(type: .withCloudKitReset)
    }
    
    // MARK: - Private Implementation
    
    private enum ResetType {
        case localOnly
        case cloudKitOnly
        case complete
        case withCloudKitReset
    }
    
    private func performReset(type: ResetType) async {
        await MainActor.run {
            isResetting = true
            resetProgress = 0.0
            resetStatus = "Starting reset..."
            resetError = nil
        }
        
        do {
            switch type {
            case .localOnly:
                try await resetLocalCoreData()
                
            case .cloudKitOnly:
                await resetCloudKitData()
                
            case .complete:
                try await resetLocalCoreData()
                await resetCloudKitData()
                
            case .withCloudKitReset:
                try await resetLocalCoreData()
                await resetCloudKitData()
                await resetCloudKitEnvironment()
            }
            
            await MainActor.run {
                resetStatus = "Reset completed successfully!"
                resetProgress = 1.0
                isResetting = false
            }
            
        } catch {
            await MainActor.run {
                resetError = "Reset failed: \(error.localizedDescription)"
                resetStatus = "Reset failed"
                isResetting = false
            }
        }
    }
    
    private func resetLocalCoreData() async throws {
        await MainActor.run {
            resetStatus = "Clearing local Core Data..."
            resetProgress = 0.2
        }
        
        // Clear all Spot entities
        let spotFetchRequest: NSFetchRequest<NSFetchRequestResult> = Spot.fetchRequest()
        let spotDeleteRequest = NSBatchDeleteRequest(fetchRequest: spotFetchRequest)
        
        // Clear all UserRating entities
        let ratingFetchRequest: NSFetchRequest<NSFetchRequestResult> = UserRating.fetchRequest()
        let ratingDeleteRequest = NSBatchDeleteRequest(fetchRequest: ratingFetchRequest)
        
        try managedObjectContext.execute(spotDeleteRequest)
        try managedObjectContext.execute(ratingDeleteRequest)
        try managedObjectContext.save()
        
        print("✅ Local Core Data cleared successfully")
        
        await MainActor.run {
            resetStatus = "Local data cleared"
            resetProgress = 0.5
        }
    }
    
    private func resetCloudKitData() async {
        await MainActor.run {
            resetStatus = "Clearing CloudKit data..."
            resetProgress = 0.6
        }
        
        await cloudKitManager.clearCloudKitRecords()
        
        await MainActor.run {
            resetStatus = "CloudKit data cleared"
            resetProgress = 0.8
        }
    }
    
    private func resetCloudKitEnvironment() async {
        await MainActor.run {
            resetStatus = "Resetting CloudKit environment..."
            resetProgress = 0.9
        }
        
        // This would require manual steps in CloudKit Dashboard
        print("🔧 CloudKit Environment Reset Instructions:")
        print("1. Go to CloudKit Dashboard (https://icloud.developer.apple.com/dashboard/)")
        print("2. Select your app and environment")
        print("3. Go to 'Data' tab")
        print("4. Select 'Reset Development Environment' or 'Reset Production Environment'")
        print("5. Confirm the reset")
        print("6. Wait for the reset to complete")
        
        await MainActor.run {
            resetStatus = "CloudKit environment reset instructions provided"
            resetProgress = 1.0
        }
    }
    
    // MARK: - Utility Methods
    
    /// Get current database statistics
    func getDatabaseStats() async -> (localSpots: Int, localRatings: Int, cloudKitRecords: Int) {
        // Count local spots
        let spotFetchRequest: NSFetchRequest<Spot> = Spot.fetchRequest()
        let localSpots = (try? managedObjectContext.count(for: spotFetchRequest)) ?? 0
        
        // Count local ratings
        let ratingFetchRequest: NSFetchRequest<UserRating> = UserRating.fetchRequest()
        let localRatings = (try? managedObjectContext.count(for: ratingFetchRequest)) ?? 0
        
        // Count CloudKit records (approximate)
        let cloudKitRecords = await getCloudKitRecordCount()
        
        return (localSpots: localSpots, localRatings: localRatings, cloudKitRecords: cloudKitRecords)
    }
    
    private func getCloudKitRecordCount() async -> Int {
        do {
            let container = CKContainer.default()
            let privateDatabase = container.privateCloudDatabase
            let query = CKQuery(recordType: "Spot", predicate: NSPredicate(format: "name != ''"))
            let results = try await privateDatabase.records(matching: query)
            return results.matchResults.count
        } catch {
            print("Error counting CloudKit records: \(error)")
            return 0
        }
    }
    
    /// Check if database is empty
    func isDatabaseEmpty() async -> Bool {
        let stats = await getDatabaseStats()
        return stats.localSpots == 0 && stats.localRatings == 0 && stats.cloudKitRecords == 0
    }
}

// MARK: - Reset Confirmation View

struct DatabaseResetView: View {
    @StateObject private var resetService: DatabaseResetService
    @Environment(\.dismiss) private var dismiss
    @State private var showingConfirmation = false
    @State private var selectedResetType: ResetType = .complete
    
    enum ResetType: String, CaseIterable {
        case localOnly = "Local Only"
        case cloudKitOnly = "CloudKit Only"
        case complete = "Complete Reset"
        case withCloudKitReset = "Complete + CloudKit Environment"
        
        var description: String {
            switch self {
            case .localOnly:
                return "Clear local Core Data only. CloudKit data remains intact."
            case .cloudKitOnly:
                return "Clear CloudKit data only. Local data remains intact."
            case .complete:
                return "Clear both local and CloudKit data. Recommended for fresh start."
            case .withCloudKitReset:
                return "Complete reset plus CloudKit environment reset. For development only."
            }
        }
    }
    
    init(context: NSManagedObjectContext, cloudKitManager: CloudKitManager) {
        _resetService = StateObject(wrappedValue: DatabaseResetService(context: context, cloudKitManager: cloudKitManager))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: ThemeManager.Spacing.lg) {
                // Header
                VStack(spacing: ThemeManager.Spacing.md) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(ThemeManager.Colors.error)
                    
                    Text("Database Reset")
                        .font(ThemeManager.Typography.dynamicLargeTitle())
                        .fontWeight(.bold)
                        .foregroundColor(ThemeManager.Colors.textPrimary)
                    
                    Text("Choose how to reset your database")
                        .font(ThemeManager.Typography.dynamicBody())
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, ThemeManager.Spacing.lg)
                
                // Reset Type Selection
                VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
                    Text("Reset Type")
                        .font(ThemeManager.Typography.dynamicHeadline())
                        .foregroundColor(ThemeManager.Colors.textPrimary)
                    
                    ForEach(ResetType.allCases, id: \.self) { type in
                        VStack(alignment: .leading, spacing: ThemeManager.Spacing.xs) {
                            HStack {
                                Image(systemName: selectedResetType == type ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedResetType == type ? ThemeManager.Colors.accent : ThemeManager.Colors.textSecondary)
                                
                                Text(type.rawValue)
                                    .font(ThemeManager.Typography.dynamicBody())
                                    .fontWeight(.medium)
                                    .foregroundColor(ThemeManager.Colors.textPrimary)
                            }
                            
                            Text(type.description)
                                .font(ThemeManager.Typography.dynamicCaption())
                                .foregroundColor(ThemeManager.Colors.textSecondary)
                                .padding(.leading, 24)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedResetType = type
                        }
                    }
                }
                .padding(.horizontal, ThemeManager.Spacing.lg)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: ThemeManager.Spacing.md) {
                    if resetService.isResetting {
                        VStack(spacing: ThemeManager.Spacing.sm) {
                            ProgressView(value: resetService.resetProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: ThemeManager.Colors.accent))
                            
                            Text(resetService.resetStatus)
                                .font(ThemeManager.Typography.dynamicCaption())
                                .foregroundColor(ThemeManager.Colors.textSecondary)
                        }
                    } else {
                        Button(action: {
                            showingConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Reset Database")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, ThemeManager.Spacing.md)
                            .background(ThemeManager.Colors.error)
                            .foregroundColor(ThemeManager.Colors.surface)
                            .cornerRadius(ThemeManager.CornerRadius.md)
                        }
                        .disabled(resetService.isResetting)
                    }
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(ThemeManager.Typography.dynamicBody())
                    .foregroundColor(ThemeManager.Colors.textSecondary)
                }
                .padding(.horizontal, ThemeManager.Spacing.lg)
                .padding(.bottom, ThemeManager.Spacing.lg)
            }
            .navigationTitle("Reset Database")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Confirm Reset", isPresented: $showingConfirmation) {
                Button("Reset", role: .destructive) {
                    Task {
                        switch selectedResetType {
                        case .localOnly:
                            await resetService.resetLocalDataOnly()
                        case .cloudKitOnly:
                            await resetService.resetCloudKitOnly()
                        case .complete:
                            await resetService.resetEverything()
                        case .withCloudKitReset:
                            await resetService.resetWithCloudKitEnvironmentReset()
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to reset the database? This action cannot be undone.")
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let cloudKitManager = CloudKitManager(context: context)
    DatabaseResetView(context: context, cloudKitManager: cloudKitManager)
}
