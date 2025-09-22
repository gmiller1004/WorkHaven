//
//  ImportView_Simple.swift
//  WorkHaven
//
//  Temporary simplified version to resolve build issues
//

import SwiftUI

struct ImportView_Simple: View {
    @StateObject private var dataImporter: DataImporter
    @StateObject private var cloudKitManager: CloudKitManager
    @State private var showingClearAlert = false
    @State private var selectedCity = "Boise"
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        self._dataImporter = StateObject(wrappedValue: DataImporter(context: context))
        self._cloudKitManager = StateObject(wrappedValue: CloudKitManager(context: context))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Import Work Spaces")
                    .font(.title)
                
                Text("Import pre-configured work spaces")
                    .font(.body)
                
                Button("Import Boise") {
                    Task {
                        await dataImporter.importBoiseWorkSpaces()
                    }
                }
                .disabled(dataImporter.isImporting)
                
                if dataImporter.isImporting {
                    ProgressView(value: dataImporter.importProgress)
                    Text(dataImporter.importStatus)
                        .font(.caption)
                }
                
                Button("Clear All Spots") {
                    showingClearAlert = true
                }
                .foregroundColor(.red)
            }
            .padding()
            .alert("Clear All Spots", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    Task {
                        await dataImporter.clearAllData()
                        await cloudKitManager.clearCloudKitRecords()
                    }
                }
            } message: {
                Text("This will permanently delete all spots. This action cannot be undone.")
            }
        }
    }
}
