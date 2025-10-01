//
//  ImagePickerView.swift
//  pet-allergy-scanner
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

#Preview {
    VStack {
        ImagePickerView(selectedImage: .constant(nil))
        
        ImagePickerView(selectedImage: .constant(UIImage(systemName: "dog.fill")))
    }
}

