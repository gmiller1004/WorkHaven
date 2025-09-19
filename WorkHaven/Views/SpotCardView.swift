//
//  SpotCardView.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import SwiftUI
import UIKit

struct SpotCardView: View {
    let spot: Spot
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingImage = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with spot name and location
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(spot.name ?? "Unknown Spot")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        Text(spot.address ?? "Unknown Address")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // WiFi Rating
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= spot.wifiRating ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                        Text("WiFi")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Content area
            VStack(alignment: .leading, spacing: 16) {
                // Photo or placeholder
                if let photoURL = spot.photoURL, !photoURL.isEmpty {
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, maxHeight: 120)
                            .background(Color.gray.opacity(0.2))
                    }
                    .frame(height: 120)
                    .clipped()
                    .cornerRadius(8)
                } else {
                    Image(systemName: "building.2")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, maxHeight: 120)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                // Ratings and amenities
                HStack(spacing: 20) {
                    // Noise Level
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: noiseIcon)
                                .foregroundColor(noiseColor)
                            Text(spot.noiseRating ?? "Low")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        Text("Noise")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Outlets
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: outlets ? "powerplug.fill" : "powerplug")
                                .foregroundColor(outlets ? .green : .red)
                            Text(outlets ? "Yes" : "No")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        Text("Outlets")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Tips section
                if let tips = spot.tips, !tips.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Pro Tip")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text(tips)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Challenge prompt
                VStack(spacing: 8) {
                    Text("🌟 Share your new spot!")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Help others discover great places to work")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            generateShareImage()
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
    
    // MARK: - Computed Properties
    
    private var outlets: Bool {
        spot.outlets
    }
    
    private var noiseIcon: String {
        switch spot.noiseRating {
        case "Low": return "speaker.slash"
        case "Medium": return "speaker.1"
        case "High": return "speaker.3"
        default: return "speaker.slash"
        }
    }
    
    private var noiseColor: Color {
        switch spot.noiseRating {
        case "Low": return .green
        case "Medium": return .orange
        case "High": return .red
        default: return .green
        }
    }
    
    // MARK: - Share Functions
    
    private func generateShareImage() {
        isGeneratingImage = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let renderer = ImageRenderer(content: self)
            renderer.scale = 3.0 // High resolution for sharing
            
            if let image = renderer.uiImage {
                self.shareImage = image
            }
            
            self.isGeneratingImage = false
        }
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
        let outletEmoji = outlets ? "🔌" : "❌"
        text += "\(outletEmoji) Outlets: \(outlets ? "Yes" : "No")\n"
        
        // Tips
        if let tips = spot.tips, !tips.isEmpty {
            text += "\n💡 Pro Tip: \(tips)\n"
        }
        
        text += "\n#WorkHaven #RemoteWork #Productivity"
        
        return text
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        
        // Configure for specific platforms
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIApplication.shared.windows.first
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {}
}

// MARK: - Share Button

struct ShareButton: View {
    let spot: Spot
    @State private var showingShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingImage = false
    
    var body: some View {
        Button(action: {
            generateShareImage()
        }) {
            HStack(spacing: 8) {
                if isGeneratingImage {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                
                Text("Share Spot")
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
        }
        .disabled(isGeneratingImage)
        .sheet(isPresented: $showingShareSheet) {
            if let shareImage = shareImage {
                ShareSheet(activityItems: [
                    shareImage,
                    generateShareText()
                ])
            }
        }
    }
    
    private func generateShareImage() {
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
    
    private func generateShareText() -> String {
        var text = "🌟 Found an amazing work spot!\n\n"
        text += "📍 \(spot.name ?? "Unknown Spot")\n"
        text += "🏢 \(spot.address ?? "Unknown Address")\n\n"
        
        let wifiStars = String(repeating: "⭐", count: Int(spot.wifiRating))
        text += "📶 WiFi: \(wifiStars) (\(spot.wifiRating)/5)\n"
        
        let noiseEmoji = spot.noiseRating == "Low" ? "🔇" : spot.noiseRating == "Medium" ? "🔉" : "🔊"
        text += "\(noiseEmoji) Noise: \(spot.noiseRating ?? "Low")\n"
        
        let outletEmoji = spot.outlets ? "🔌" : "❌"
        text += "\(outletEmoji) Outlets: \(spot.outlets ? "Yes" : "No")\n"
        
        if let tips = spot.tips, !tips.isEmpty {
            text += "\n💡 Pro Tip: \(tips)\n"
        }
        
        text += "\n#WorkHaven #RemoteWork #Productivity"
        
        return text
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
    
    return VStack {
        SpotCardView(spot: spot)
            .padding()
        
        ShareButton(spot: spot)
            .padding()
    }
}
