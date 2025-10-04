//
//  ImagePickerView.swift
//  SniffTest
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI
import PhotosUI

/// Image picker view that supports camera and photo library
struct ImagePickerView: View {
    @Binding var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        Button(action: {
            showingActionSheet = true
        }) {
            ZStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(ModernDesignSystem.Colors.deepForestGreen, lineWidth: 3)
                        )
                } else {
                    Circle()
                        .fill(ModernDesignSystem.Colors.deepForestGreen.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                Text("Add Photo")
                                    .font(.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                        )
                }
                
                // Edit icon overlay
                if selectedImage != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                .background(Circle().fill(Color.white))
                                .offset(x: -5, y: -5)
                        }
                    }
                    .frame(width: 120, height: 120)
                }
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showingActionSheet) {
            Button("Camera") {
                sourceType = .camera
                showingImagePicker = true
            }
            Button("Photo Library") {
                sourceType = .photoLibrary
                showingImagePicker = true
            }
            if selectedImage != nil {
                Button("Remove Photo", role: .destructive) {
                    selectedImage = nil
                    HapticFeedback.light()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: sourceType)
        }
    }
}

/// UIKit image picker wrapper for SwiftUI
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            
            HapticFeedback.success()
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

/// Async image loader for displaying remote images
struct AsyncImageView: View {
    let url: String?
    let placeholder: Image
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder
                    .resizable()
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    /// Load image from URL
    private func loadImage() {
        guard let urlString = url, let imageURL = URL(string: urlString), !isLoading else { return }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: imageURL)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.loadedImage = image
                        self.isLoading = false
                    }
                }
            } catch {
                print("Failed to load image: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

/// Profile image picker that displays existing user image with edit functionality
struct ProfileImagePickerView: View {
    @Binding var selectedImage: UIImage?
    let currentImageUrl: String?
    
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var existingImage: UIImage?
    @State private var isLoadingExistingImage = false
    
    var body: some View {
        Button(action: {
            showingActionSheet = true
        }) {
            ZStack {
                if let selectedImage = selectedImage {
                    // Show newly selected image
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(ModernDesignSystem.Colors.deepForestGreen, lineWidth: 3)
                        )
                } else if let existingImage = existingImage {
                    // Show existing user image
                    Image(uiImage: existingImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(ModernDesignSystem.Colors.deepForestGreen, lineWidth: 3)
                        )
                } else if isLoadingExistingImage {
                    // Show loading state
                    Circle()
                        .fill(ModernDesignSystem.Colors.lightGray.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                } else {
                    // Show add photo placeholder
                    Circle()
                        .fill(ModernDesignSystem.Colors.deepForestGreen.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                Text("Add Photo")
                                    .font(.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                        )
                }
                
                // Edit icon overlay - show if there's any image (selected or existing)
                if selectedImage != nil || existingImage != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                .background(Circle().fill(Color.white))
                                .offset(x: -5, y: -5)
                        }
                    }
                    .frame(width: 120, height: 120)
                }
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showingActionSheet) {
            Button("Camera") {
                sourceType = .camera
                showingImagePicker = true
            }
            Button("Photo Library") {
                sourceType = .photoLibrary
                showingImagePicker = true
            }
            if selectedImage != nil || existingImage != nil {
                Button("Remove Photo", role: .destructive) {
                    selectedImage = nil
                    existingImage = nil
                    HapticFeedback.light()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: sourceType)
        }
        .onAppear {
            loadExistingImage()
        }
    }
    
    /// Load existing user image from URL
    private func loadExistingImage() {
        guard let imageUrl = currentImageUrl, !imageUrl.isEmpty else { 
            print("🔍 ProfileImagePickerView: No image URL provided")
            return 
        }
        
        print("🔍 ProfileImagePickerView: Loading existing image from URL: \(imageUrl)")
        isLoadingExistingImage = true
        
        Task {
            do {
                let image: UIImage?
                
                if imageUrl.hasPrefix("http://") || imageUrl.hasPrefix("https://") {
                    // Load remote image
                    let (data, _) = try await URLSession.shared.data(from: URL(string: imageUrl)!)
                    image = UIImage(data: data)
                } else {
                    // Load local image
                    image = UIImage(contentsOfFile: imageUrl)
                }
                
                await MainActor.run {
                    self.existingImage = image
                    self.isLoadingExistingImage = false
                    print("🔍 ProfileImagePickerView: Image loaded successfully: \(image != nil ? "YES" : "NO")")
                }
            } catch {
                print("Failed to load existing image: \(error)")
                await MainActor.run {
                    self.isLoadingExistingImage = false
                }
            }
        }
    }
}

/// Pet profile image picker that displays existing pet image with edit functionality
struct PetProfileImagePickerView: View {
    @Binding var selectedImage: UIImage?
    let currentImageUrl: String?
    let species: PetSpecies
    
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var existingImage: UIImage?
    @State private var isLoadingExistingImage = false
    
    var body: some View {
        Button(action: {
            showingActionSheet = true
        }) {
            ZStack {
                if let selectedImage = selectedImage {
                    // Show newly selected image
                    Image(uiImage: selectedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(ModernDesignSystem.Colors.deepForestGreen, lineWidth: 3)
                        )
                } else if let existingImage = existingImage {
                    // Show existing pet image
                    Image(uiImage: existingImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(ModernDesignSystem.Colors.deepForestGreen, lineWidth: 3)
                        )
                } else if isLoadingExistingImage {
                    // Show loading state
                    Circle()
                        .fill(ModernDesignSystem.Colors.lightGray.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.8)
                        )
                } else {
                    // Show species icon as placeholder
                    Circle()
                        .fill(ModernDesignSystem.Colors.deepForestGreen.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: species.icon)
                                    .font(.system(size: 32))
                                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                Text("Add Photo")
                                    .font(.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                        )
                }
                
                // Edit icon overlay - show if there's any image (selected or existing)
                if selectedImage != nil || existingImage != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                .background(Circle().fill(Color.white))
                                .offset(x: -5, y: -5)
                        }
                    }
                    .frame(width: 120, height: 120)
                }
            }
        }
        .confirmationDialog("Choose Photo Source", isPresented: $showingActionSheet) {
            Button("Camera") {
                sourceType = .camera
                showingImagePicker = true
            }
            Button("Photo Library") {
                sourceType = .photoLibrary
                showingImagePicker = true
            }
            if selectedImage != nil || existingImage != nil {
                Button("Remove Photo", role: .destructive) {
                    selectedImage = nil
                    existingImage = nil
                    HapticFeedback.light()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: sourceType)
        }
        .onAppear {
            loadExistingImage()
        }
    }
    
    /// Load existing pet image from URL
    private func loadExistingImage() {
        guard let imageUrl = currentImageUrl, !imageUrl.isEmpty else { 
            print("🔍 PetProfileImagePickerView: No image URL provided")
            return 
        }
        
        print("🔍 PetProfileImagePickerView: Loading existing pet image from URL: \(imageUrl)")
        isLoadingExistingImage = true
        
        Task {
            do {
                let image: UIImage?
                
                if imageUrl.hasPrefix("http://") || imageUrl.hasPrefix("https://") {
                    // Load remote image
                    let (data, _) = try await URLSession.shared.data(from: URL(string: imageUrl)!)
                    image = UIImage(data: data)
                } else {
                    // Load local image
                    image = UIImage(contentsOfFile: imageUrl)
                }
                
                await MainActor.run {
                    self.existingImage = image
                    self.isLoadingExistingImage = false
                    print("🔍 PetProfileImagePickerView: Pet image loaded successfully: \(image != nil ? "YES" : "NO")")
                }
            } catch {
                print("Failed to load existing pet image: \(error)")
                await MainActor.run {
                    self.isLoadingExistingImage = false
                }
            }
        }
    }
}

#Preview {
    VStack {
        ImagePickerView(selectedImage: .constant(nil))
        
        ImagePickerView(selectedImage: .constant(UIImage(systemName: "dog.fill")))
        
        ProfileImagePickerView(selectedImage: .constant(nil), currentImageUrl: nil)
        
        ProfileImagePickerView(selectedImage: .constant(nil), currentImageUrl: "https://example.com/image.jpg")
        
        PetProfileImagePickerView(selectedImage: .constant(nil), currentImageUrl: nil, species: .dog)
        
        PetProfileImagePickerView(selectedImage: .constant(nil), currentImageUrl: "https://example.com/pet.jpg", species: .cat)
    }
}

