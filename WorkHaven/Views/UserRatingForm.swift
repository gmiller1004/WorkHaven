//
//  UserRatingForm.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import CoreData

struct UserRatingForm: View {
    let spot: Spot
    let viewModel: SpotViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @State private var wifiRating: Int16 = 1
    @State private var noiseRating: String = "Low"
    @State private var outlets: Bool = false
    @State private var tip: String = ""
    @State private var showingSuccessAlert = false
    @State private var isSubmitting = false
    
    private let noiseOptions = ["Low", "Medium", "High"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Rate This Spot")
                    .font(ThemeManager.Typography.dynamicTitle2())
                    .fontWeight(.bold)
                    .foregroundColor(ThemeManager.Colors.textPrimary)
                
                Text("Share your experience to help others")
                    .font(ThemeManager.Typography.dynamicSubheadline())
                    .foregroundColor(ThemeManager.Colors.textSecondary)
                
                Text("Your rating helps refine the spot's quality score.")
                    .font(ThemeManager.Typography.dynamicCaption())
                    .foregroundColor(ThemeManager.Colors.accent)
                    .italic()
            }
            
            // WiFi Rating
            VStack(alignment: .leading, spacing: 12) {
                Text("WiFi Quality")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: {
                            wifiRating = Int16(star)
                        }) {
                            Image(systemName: star <= wifiRating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundColor(star <= wifiRating ? .yellow : .gray)
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(wifiRating) star\(wifiRating == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Noise Rating
            VStack(alignment: .leading, spacing: 12) {
                Text("Noise Level")
                    .font(.headline)
                
                Picker("Noise Level", selection: $noiseRating) {
                    ForEach(noiseOptions, id: \.self) { option in
                        HStack {
                            Text(option)
                            Spacer()
                            Text(noiseIcon(for: option))
                        }
                        .tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Outlets
            VStack(alignment: .leading, spacing: 12) {
                Text("Power Outlets")
                    .font(.headline)
                
                HStack {
                    Button(action: {
                        outlets = true
                    }) {
                        HStack {
                            Image(systemName: outlets ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(outlets ? .green : .gray)
                            Text("Yes")
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Button(action: {
                        outlets = false
                    }) {
                        HStack {
                            Image(systemName: !outlets ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(!outlets ? .green : .gray)
                            Text("No")
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Tips
            VStack(alignment: .leading, spacing: 12) {
                Text("Tips (Optional)")
                    .font(.headline)
                
                TextField("Share your experience...", text: $tip, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
            }
            
            // Submit Button
            Button(action: submitRating) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "star.fill")
                    }
                    Text(isSubmitting ? "Submitting..." : "Submit Rating")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSubmitting ? Color.gray : Color.blue)
                .cornerRadius(12)
            }
            .disabled(isSubmitting)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
        .alert("Rating Submitted!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                resetForm()
            }
        } message: {
            Text("Thank you for your feedback! Your rating has been saved.")
        }
    }
    
    // MARK: - Helper Functions
    
    private func noiseIcon(for level: String) -> String {
        switch level {
        case "Low": return "🔇"
        case "Medium": return "🔉"
        case "High": return "🔊"
        default: return "🔇"
        }
    }
    
    private func submitRating() {
        isSubmitting = true
        
        // Add user rating using SpotViewModel
        viewModel.addUserRating(
            to: spot,
            wifiRating: wifiRating,
            noiseRating: noiseRating,
            outlets: outlets,
            tips: tip.isEmpty ? nil : tip
        )
        
        // Update spot's lastModified to trigger CloudKit sync
        spot.lastModified = Date()
        
        // Save context and trigger CloudKit sync
        viewModel.saveContext()
        
        // Trigger CloudKit sync in background
        Task {
            // Note: CloudKit sync would be triggered automatically by the saveContext
            // but we can also explicitly trigger it if needed
            await MainActor.run {
                showingSuccessAlert = true
            }
        }
    }
    
    private func resetForm() {
        wifiRating = 1
        noiseRating = "Low"
        outlets = false
        tip = ""
        isSubmitting = false
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let spot = Spot.createSampleSpot(in: context)
    return UserRatingForm(spot: spot, viewModel: SpotViewModel(context: context))
        .environment(\.managedObjectContext, context)
}
