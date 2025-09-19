//
//  PhotoService.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/19/25.
//

import Foundation
import UIKit
import PhotosUI

class PhotoService: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var photoURL: String?
    
    func selectPhoto(from picker: PHPickerViewController) {
        // This would be implemented with PHPickerViewController
        // For now, we'll provide a placeholder implementation
    }
    
    func savePhoto(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("Error saving photo: \(error)")
            return nil
        }
    }
    
    func loadPhoto(from fileName: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    func deletePhoto(fileName: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        try? FileManager.default.removeItem(at: fileURL)
    }
}
