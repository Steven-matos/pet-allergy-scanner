//
//  PetImagePickerView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI
import PhotosUI

/// Enhanced image picker view specifically for pet photos with species icon fallback
struct PetImagePickerView: View {
    @Binding var selectedImage: UIImage?
    let species: PetSpecies
    
    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    var body: some View {
        Button(action: {
            showingActionSheet = true
        }) {
            ZStack {
                if let image = selectedImage {
                    // Display selected image
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
                    // Show species icon as placeholder
                    Circle()
                        .fill(ModernDesignSystem.Colors.deepForestGreen.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: species.icon)
                                    .font(.system(size: 48))
                                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                
                                Text("Add Photo")
                                    .font(.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                        )
                        .overlay(
                            Circle()
                                .stroke(ModernDesignSystem.Colors.deepForestGreen, lineWidth: 2)
                        )
                }
                
                // Edit icon overlay (only when image exists)
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

#Preview {
    VStack(spacing: 40) {
        // Without image - Dog
        PetImagePickerView(
            selectedImage: .constant(nil),
            species: .dog
        )
        
        // Without image - Cat
        PetImagePickerView(
            selectedImage: .constant(nil),
            species: .cat
        )
        
        // With image
        PetImagePickerView(
            selectedImage: .constant(UIImage(systemName: "photo")),
            species: .dog
        )
    }
}

