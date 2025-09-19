//
//  SpotShareView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI

struct SpotShareView: View {
    let spot: Spot
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingImage = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Share Your Spot")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Help others discover great places to work")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Shareable Card Preview
                ScrollView {
                    VStack(spacing: 16) {
                        SpotCardView(spot: spot)
                            .padding(.horizontal)
                        
                        // Share options
                        VStack(spacing: 12) {
                            Text("Share Options")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 8) {
                                // Image + Text sharing
                                Button(action: {
                                    generateAndShare()
                                }) {
                                    HStack {
                                        Image(systemName: "photo")
                                        Text("Share as Image + Text")
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                                
                                // Text only sharing
                                Button(action: {
                                    shareTextOnly()
                                }) {
                                    HStack {
                                        Image(systemName: "text.bubble")
                                        Text("Share as Text Only")
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                    }
                                    .foregroundColor(.blue)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                
                                // Copy to clipboard
                                Button(action: {
                                    copyToClipboard()
                                }) {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy to Clipboard")
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                    }
                                    .foregroundColor(.green)
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Social media tips
                        VStack(alignment: .leading, spacing: 12) {
                            Text("💡 Sharing Tips")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                TipRow(icon: "message", text: "iMessage: Great for sharing with friends and colleagues")
                                TipRow(icon: "camera", text: "Instagram: Use the image version for Stories or posts")
                                TipRow(icon: "bird", text: "X (Twitter): Text version works best for tweets")
                                TipRow(icon: "link", text: "LinkedIn: Professional sharing with the image card")
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        generateAndShare()
                    }
                    .fontWeight(.semibold)
                    .disabled(isGeneratingImage)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let shareImage = shareImage {
                ShareSheet(activityItems: [
                    shareImage,
                    generateShareText()
                ])
            }
        }
    }
    
    // MARK: - Share Functions
    
    private func generateAndShare() {
        isGeneratingImage = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let renderer = ImageRenderer(content: SpotCardView(spot: spot))
            renderer.scale = 3.0
            
            if let image = renderer.uiImage {
                self.shareImage = image
            }
            
            self.isGeneratingImage = false
            self.showingShareSheet = true
        }
    }
    
    private func shareTextOnly() {
        let text = generateShareText()
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func copyToClipboard() {
        let text = generateShareText()
        UIPasteboard.general.string = text
        
        // Show feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func generateShareText() -> String {
        var text = "🌟 Found an amazing work spot!\n\n"
        text += "📍 \(spot.name ?? "Unknown Spot")\n"
        text += "🏢 \(spot.address ?? "Unknown Address")\n\n"
        
        // WiFi rating
        let wifiStars = String(repeating: "⭐", count: Int(spot.wifiRating))
        text += "📶 WiFi: \(wifiStars) (\(spot.wifiRating)/5)\n"
        
        // Noise level
        let noiseEmoji = spot.noiseRating == "Low" ? "🔇" : spot.noiseRating == "Medium" ? "🔉" : "🔊"
        text += "\(noiseEmoji) Noise: \(spot.noiseRating ?? "Low")\n"
        
        // Outlets
        let outletEmoji = spot.outlets ? "🔌" : "❌"
        text += "\(outletEmoji) Outlets: \(spot.outlets ? "Yes" : "No")\n"
        
        // Tips
        if let tips = spot.tips, !tips.isEmpty {
            text += "\n💡 Pro Tip: \(tips)\n"
        }
        
        text += "\n#WorkHaven #RemoteWork #Productivity"
        
        return text
    }
}

// MARK: - Tip Row

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let spot = Spot(context: context)
    spot.name = "Neckar Coffee"
    spot.address = "Boise, ID"
    spot.latitude = 43.6187
    spot.longitude = -116.2146
    spot.wifiRating = 5
    spot.noiseRating = "Low"
    spot.outlets = true
    spot.tips = "Great coffee and quiet atmosphere. Perfect for focused work sessions."
    spot.photoURL = "https://example.com/photo.jpg"
    
    return SpotShareView(spot: spot)
}
