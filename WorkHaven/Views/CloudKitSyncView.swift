//
//  CloudKitSyncView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import CloudKit
import CoreData

struct CloudKitSyncView: View {
    @StateObject private var cloudKitManager: CloudKitManager
    @State private var showingStatusAlert = false
    @State private var statusMessage = ""
    
    init(context: NSManagedObjectContext) {
        self._cloudKitManager = StateObject(wrappedValue: CloudKitManager(context: context))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "icloud")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("iCloud Sync")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Keep your work spots synchronized across all devices")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Sync Status
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: cloudKitManager.isSyncing ? "arrow.clockwise" : "checkmark.circle")
                        .foregroundColor(cloudKitManager.isSyncing ? .blue : .green)
                        .rotationEffect(.degrees(cloudKitManager.isSyncing ? 360 : 0))
                        .animation(cloudKitManager.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: cloudKitManager.isSyncing)
                    
                    Text(cloudKitManager.isSyncing ? "Syncing..." : "Ready to Sync")
                        .font(.headline)
                    
                    Spacer()
                }
                
                if let lastSync = cloudKitManager.lastSyncDate {
                    HStack {
                        Text("Last sync:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(lastSync, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                if let error = cloudKitManager.syncError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Sync Button
            Button(action: {
                Task {
                    await cloudKitManager.syncWithCloudKit()
                }
            }) {
                HStack {
                    if cloudKitManager.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    
                    Text(cloudKitManager.isSyncing ? "Syncing..." : "Sync Now")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(cloudKitManager.isSyncing ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .disabled(cloudKitManager.isSyncing)
            
            // CloudKit Status Check
            Button(action: {
                Task {
                    await checkCloudKitStatus()
                }
            }) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Check iCloud Status")
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("iCloud Sync")
        .alert("iCloud Status", isPresented: $showingStatusAlert) {
            Button("OK") { }
        } message: {
            Text(statusMessage)
        }
        .onAppear {
            Task {
                await checkCloudKitStatus()
            }
        }
    }
    
    private func checkCloudKitStatus() async {
        let status = await cloudKitManager.checkCloudKitStatus()
        
        switch status {
        case .available:
            statusMessage = "iCloud is available and ready for synchronization."
        case .noAccount:
            statusMessage = "No iCloud account is signed in. Please sign in to iCloud in Settings."
        case .restricted:
            statusMessage = "iCloud access is restricted on this device."
        case .couldNotDetermine:
            statusMessage = "Unable to determine iCloud status. Please check your internet connection."
        case .temporarilyUnavailable:
            statusMessage = "iCloud is temporarily unavailable. Please try again later."
        @unknown default:
            statusMessage = "Unknown iCloud status."
        }
        
        showingStatusAlert = true
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    CloudKitSyncView(context: context)
}
