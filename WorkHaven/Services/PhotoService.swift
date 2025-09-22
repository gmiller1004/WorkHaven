//
//  PhotoService.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/22/25.
//  Service for handling user photo uploads and management for spots
//

import Foundation
import UIKit
import PhotosUI
import CoreData

class PhotoService: ObservableObject {
    @Published var isUploading = false
    @Published var uploadError: String?
    
    private let managedObjectContext: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }
    
    // MARK: - Photo Upload
    
    func uploadPhoto(for spot: Spot, image: UIImage, caption: String? = nil) async {
        await MainActor.run {
            isUploading = true
            uploadError = nil
        }
        
        do {
            // Compress image to reasonable size
            guard let imageData = compressImage(image) else {
                throw PhotoError.compressionFailed
            }
            
            // Create SpotPhoto entity
            let spotPhoto = SpotPhoto(context: managedObjectContext)
            spotPhoto.imageData = imageData
            spotPhoto.caption = caption
            spotPhoto.timestamp = Date()
            spotPhoto.spot = spot
            
            // Save to Core Data
            try managedObjectContext.save()
            
            print("✅ Photo uploaded successfully for \(spot.name ?? "Unknown")")
            
            await MainActor.run {
                isUploading = false
            }
            
        } catch {
            print("❌ Photo upload failed: \(error)")
            await MainActor.run {
                isUploading = false
                uploadError = error.localizedDescription
            }
        }
    }
    
    // MARK: - Photo Management
    
    func getPhotos(for spot: Spot) -> [SpotPhoto] {
        guard let photos = spot.photos as? Set<SpotPhoto> else { return [] }
        return photos.sorted { 
            ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast)
        }
    }
    
    func deletePhoto(_ photo: SpotPhoto) {
        managedObjectContext.delete(photo)
        
        do {
            try managedObjectContext.save()
            print("✅ Photo deleted successfully")
        } catch {
            print("❌ Failed to delete photo: \(error)")
        }
    }
    
    // MARK: - Image Processing
    
    private func compressImage(_ image: UIImage, maxSize: Int = 1024 * 1024) -> Data? {
        var compressionQuality: CGFloat = 0.8
        var imageData = image.jpegData(compressionQuality: compressionQuality)
        
        // Reduce quality until we're under the size limit
        while let data = imageData, data.count > maxSize && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = image.jpegData(compressionQuality: compressionQuality)
        }
        
        return imageData
    }
    
    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - Photo Errors

enum PhotoError: LocalizedError {
    case compressionFailed
    case uploadFailed
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .uploadFailed:
            return "Failed to upload photo"
        case .invalidImage:
            return "Invalid image data"
        }
    }
}