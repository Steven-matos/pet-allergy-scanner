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
        
        Task {
            var newImageUrl: String? = nil
            
            // Handle image upload if changed
            if let selectedImage = selectedImage {
                // Check if image changed by comparing with existing
                let existingImage = authService.currentUser?.imageUrl.flatMap { UIImage(contentsOfFile: $0) }
                if existingImage == nil || !imagesAreEqual(selectedImage, existingImage) {
                    do {
                        // Replace old image with new one (deletes old, uploads new)
                        let storageService = StorageService.shared
                        newImageUrl = try await storageService.replaceUserImage(
                            oldImageUrl: authService.currentUser?.imageUrl,
                            newImage: selectedImage,
                            userId: authService.currentUser?.id ?? ""
                        )
                        print("📸 User image replaced in Supabase: \(newImageUrl ?? "nil")")
                    } catch {
                        print("Failed to replace user image: \(error)")
                        // Don't fall back to local storage - fail properly
                        authService.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                        return
                    }
                } else {
                    newImageUrl = nil // No change
                }
            } else if authService.currentUser?.imageUrl != nil {
                // Image was removed - delete old image if it's in Supabase
                if let oldUrl = authService.currentUser?.imageUrl, oldUrl.contains(Configuration.supabaseURL) {
                    do {
                        try await StorageService.shared.deleteUserImage(path: oldUrl)
                        print("🗑️ User image removed from Supabase: \(oldUrl)")
                    } catch {
                        print("⚠️ Failed to delete old user image: \(error)")
                    }
                }
                newImageUrl = ""
            } else {
                newImageUrl = nil // No change
            }
            
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

