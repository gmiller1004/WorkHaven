//
//  SpotPhotoGallery.swift
//  WorkHaven
//
//  Created by Greg Miller on 9/22/25.
//  Photo gallery view for displaying user-generated photos of spots
//

import SwiftUI
import PhotosUI
import CoreData

struct SpotPhotoGallery: View {
    let spot: Spot
    @StateObject private var photoService: PhotoService
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var photoCaption = ""
    @State private var showingAddPhotoSheet = false
    
    init(spot: Spot, context: NSManagedObjectContext) {
        self.spot = spot
        self._photoService = StateObject(wrappedValue: PhotoService(context: context))
    }
    
    var photos: [SpotPhoto] {
        photoService.getPhotos(for: spot)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.Spacing.md) {
            // Header with Add Photo button
            HStack {
                Text("Photos")
                    .font(ThemeManager.Typography.dynamicHeadline())
                    .foregroundColor(ThemeManager.Colors.textPrimary)
                
                Spacer()
                
                Button(action: {
                    showingAddPhotoSheet = true
                }) {
                    HStack(spacing: ThemeManager.Spacing.xs) {
                        Image(systemName: "camera.fill")
                            .font(ThemeManager.Typography.dynamicCaption())
                        Text("Add Photo")
                            .font(ThemeManager.Typography.dynamicCaption())
                    }
                    .foregroundColor(ThemeManager.Colors.accent)
                    .padding(.horizontal, ThemeManager.Spacing.sm)
                    .padding(.vertical, ThemeManager.Spacing.xs)
                    .background(ThemeManager.Colors.accent.opacity(0.1))
                    .cornerRadius(ThemeManager.CornerRadius.sm)
                }
            }
            
            if photos.isEmpty {
                // Empty state
                VStack(spacing: ThemeManager.Spacing.md) {
                    Image(systemName: "camera.fill")
                        .font(ThemeManager.Typography.dynamicTitle1())
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                    
                    Text("No photos yet")
                        .font(ThemeManager.Typography.dynamicBody())
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                    
                    Text("Be the first to share a photo of this spot!")
                        .font(ThemeManager.Typography.dynamicCaption())
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ThemeManager.Spacing.xl)
                .background(ThemeManager.Colors.background)
                .cornerRadius(ThemeManager.CornerRadius.md)
            } else {
                // Photo grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: ThemeManager.Spacing.sm), count: 3), spacing: ThemeManager.Spacing.sm) {
                    ForEach(photos, id: \.objectID) { photo in
                        PhotoThumbnail(photo: photo, photoService: photoService)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddPhotoSheet) {
            AddPhotoSheet(
                spot: spot,
                photoService: photoService,
                isPresented: $showingAddPhotoSheet
            )
        }
    }
}

// MARK: - Photo Thumbnail

struct PhotoThumbnail: View {
    let photo: SpotPhoto
    let photoService: PhotoService
    @State private var showingFullScreen = false
    
    var body: some View {
        Button(action: {
            showingFullScreen = true
        }) {
            if let imageData = photo.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(ThemeManager.CornerRadius.sm)
                    .overlay(
                        // Caption overlay
                        VStack {
                            Spacer()
                            if let caption = photo.caption, !caption.isEmpty {
                                Text(caption)
                                    .font(ThemeManager.Typography.dynamicCaption())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, ThemeManager.Spacing.xs)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                                    .lineLimit(2)
                            }
                        }
                        .padding(ThemeManager.Spacing.xs)
                    )
            } else {
                Rectangle()
                    .fill(ThemeManager.Colors.background)
                    .frame(width: 100, height: 100)
                    .cornerRadius(ThemeManager.CornerRadius.sm)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(ThemeManager.Colors.textSecondary)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                photoService.deletePhoto(photo)
            } label: {
                Label("Delete Photo", systemImage: "trash")
            }
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            PhotoFullScreenView(photo: photo, isPresented: $showingFullScreen)
        }
    }
}

// MARK: - Add Photo Sheet

struct AddPhotoSheet: View {
    let spot: Spot
    let photoService: PhotoService
    @Binding var isPresented: Bool
    
    @State private var selectedImage: UIImage?
    @State private var photoCaption = ""
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: ThemeManager.Spacing.lg) {
                // Image picker
                Button(action: {
                    showingImagePicker = true
                }) {
                    VStack(spacing: ThemeManager.Spacing.md) {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(ThemeManager.CornerRadius.md)
                        } else {
                            VStack(spacing: ThemeManager.Spacing.sm) {
                                Image(systemName: "camera.fill")
                                    .font(ThemeManager.Typography.dynamicTitle1())
                                    .foregroundColor(ThemeManager.Colors.accent)
                                
                                Text("Tap to select photo")
                                    .font(ThemeManager.Typography.dynamicBody())
                                    .foregroundColor(ThemeManager.Colors.textPrimary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .background(ThemeManager.Colors.background)
                            .cornerRadius(ThemeManager.CornerRadius.md)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Caption field
                VStack(alignment: .leading, spacing: ThemeManager.Spacing.sm) {
                    Text("Caption (Optional)")
                        .font(ThemeManager.Typography.dynamicHeadline())
                        .foregroundColor(ThemeManager.Colors.textPrimary)
                    
                    TextField("Add a caption for your photo...", text: $photoCaption)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(ThemeManager.Typography.dynamicBody())
                }
                
                Spacer()
                
                // Upload button
                Button(action: uploadPhoto) {
                    HStack {
                        if photoService.isUploading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                        }
                        
                        Text(photoService.isUploading ? "Uploading..." : "Upload Photo")
                            .font(ThemeManager.Typography.dynamicBody())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedImage != nil ? ThemeManager.Colors.accent : ThemeManager.Colors.textSecondary)
                    .cornerRadius(ThemeManager.CornerRadius.md)
                }
                .disabled(selectedImage == nil || photoService.isUploading)
            }
            .padding()
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }
    
    private func uploadPhoto() {
        guard let selectedImage = selectedImage else { return }
        
        Task {
            await photoService.uploadPhoto(
                for: spot,
                image: selectedImage,
                caption: photoCaption.isEmpty ? nil : photoCaption
            )
            
            await MainActor.run {
                isPresented = false
            }
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.selectedImage = image as? UIImage
                }
            }
        }
    }
}

// MARK: - Photo Full Screen View

struct PhotoFullScreenView: View {
    let photo: SpotPhoto
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                if let imageData = photo.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .ignoresSafeArea()
                } else {
                    Text("Unable to load image")
                        .foregroundColor(ThemeManager.Colors.textSecondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let spot = Spot.createSampleSpot(in: context)
    SpotPhotoGallery(spot: spot, context: context)
        .padding()
}
