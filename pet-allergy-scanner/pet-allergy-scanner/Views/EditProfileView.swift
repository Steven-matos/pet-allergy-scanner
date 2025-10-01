//
//  EditProfileView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI

/// View for editing user profile information
struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var selectedImage: UIImage?
    @State private var isSaving = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Profile Photo Section
                Section {
                    HStack {
                        Spacer()
                        ImagePickerView(selectedImage: $selectedImage)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("Account Information")) {
                    // Email (read-only)
                    HStack {
                        Text("Email")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(authService.currentUser?.email ?? "")
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                    
                    // Username
                    HStack {
                        Text("Username")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Spacer()
                        TextField("Enter username", text: $username)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                
                Section(header: Text("Personal Information")) {
                    // First Name
                    HStack {
                        Text("First Name")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Spacer()
                        TextField("Enter first name", text: $firstName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Last Name
                    HStack {
                        Text("Last Name")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Spacer()
                        TextField("Enter last name", text: $lastName)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Account Details")) {
                    HStack {
                        Text("Account Type")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(authService.currentUser?.role.displayName ?? "Free")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(authService.currentUser?.role == .premium ? ModernDesignSystem.Colors.goldenYellow : ModernDesignSystem.Colors.lightGray)
                            .foregroundColor(authService.currentUser?.role == .premium ? ModernDesignSystem.Colors.textOnAccent : ModernDesignSystem.Colors.textPrimary)
                            .cornerRadius(8)
                    }
                    
                    HStack {
                        Text("Member Since")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Spacer()
                        Text(authService.currentUser?.createdAt ?? Date(), style: .date)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isSaving || !hasChanges())
                }
            }
            .onAppear {
                loadUserData()
            }
            .alert("Success", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Profile updated successfully")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(authService.errorMessage ?? "Failed to update profile")
            }
        }
    }
    
    /// Load current user data into form fields
    private func loadUserData() {
        guard let user = authService.currentUser else { return }
        username = user.username ?? ""
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        
        // Load profile image if available
        if let imageUrl = user.imageUrl {
            selectedImage = UIImage(contentsOfFile: imageUrl)
        }
    }
    
    /// Check if any fields have been modified
    /// - Returns: True if any field has been changed from original value
    private func hasChanges() -> Bool {
        guard let user = authService.currentUser else { return false }
        
        // Check if image changed
        let imageChanged: Bool
        if let selectedImage = selectedImage {
            let existingImage = user.imageUrl.flatMap { UIImage(contentsOfFile: $0) }
            imageChanged = existingImage == nil || !imagesAreEqual(selectedImage, existingImage)
        } else if user.imageUrl != nil {
            imageChanged = true // Image was removed
        } else {
            imageChanged = false
        }
        
        return username != (user.username ?? "") ||
               firstName != (user.firstName ?? "") ||
               lastName != (user.lastName ?? "") ||
               imageChanged
    }
    
    /// Save profile changes to server
    private func saveProfile() {
        isSaving = true
        
        // Save new image if changed
        let newImageUrl: String?
        if let selectedImage = selectedImage {
            // Check if image changed by comparing with existing
            let existingImage = authService.currentUser?.imageUrl.flatMap { UIImage(contentsOfFile: $0) }
            if existingImage == nil || !imagesAreEqual(selectedImage, existingImage) {
                newImageUrl = saveImageLocally(selectedImage)
            } else {
                newImageUrl = nil // No change
            }
        } else if authService.currentUser?.imageUrl != nil {
            // Image was removed
            newImageUrl = ""
        } else {
            newImageUrl = nil // No change
        }
        
        Task {
            await authService.updateProfile(
                username: username.isEmpty ? nil : username,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                imageUrl: newImageUrl
            )
            
            isSaving = false
            
            if authService.errorMessage != nil {
                showingErrorAlert = true
            } else {
                showingSuccessAlert = true
                HapticFeedback.success()
            }
        }
    }
    
    /// Save image locally with optimization and return file URL
    /// - Parameter image: The UIImage to save
    /// - Returns: Local file URL string or nil
    private func saveImageLocally(_ image: UIImage?) -> String? {
        guard let image = image else { return nil }
        
        // Optimize image before saving
        let optimizedResult: OptimizedImageResult
        do {
            optimizedResult = try ImageOptimizer.optimizeForUpload(image: image)
            print("📸 Profile image optimized: \(optimizedResult.summary)")
        } catch {
            print("⚠️ Image optimization failed: \(error), using default compression")
            // Fallback to simple compression if optimization fails
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                return nil
            }
            return saveImageData(imageData)
        }
        
        return saveImageData(optimizedResult.data)
    }
    
    /// Save image data to local file system
    /// - Parameter data: The image data to save
    /// - Returns: Local file path string or nil
    private func saveImageData(_ data: Data) -> String? {
        // Create a unique filename
        let filename = "\(UUID().uuidString).jpg"
        
        // Get documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // Create profile images directory if needed
        let profileImagesDirectory = documentsDirectory.appendingPathComponent("ProfileImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: profileImagesDirectory, withIntermediateDirectories: true)
        
        // Create full file URL
        let fileURL = profileImagesDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    /// Compare two images for equality
    /// - Parameters:
    ///   - image1: First image
    ///   - image2: Second image
    /// - Returns: True if images are equal
    private func imagesAreEqual(_ image1: UIImage, _ image2: UIImage?) -> Bool {
        guard let image2 = image2 else { return false }
        guard let data1 = image1.pngData(), let data2 = image2.pngData() else { return false }
        return data1 == data2
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthService.shared)
}

