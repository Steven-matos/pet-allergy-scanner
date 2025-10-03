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
                        ProfileImagePickerView(selectedImage: $selectedImage, currentImageUrl: authService.currentUser?.imageUrl)
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
        guard let user = authService.currentUser else { 
            print("🔍 EditProfileView: No current user found")
            return 
        }
        
        print("🔍 EditProfileView: Loading user data - imageUrl: \(user.imageUrl ?? "nil")")
        username = user.username ?? ""
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        
        // Note: Profile image loading is now handled by ProfileImagePickerView
        // No need to load image here as it's managed by the picker component
    }
    
    /// Check if any fields have been modified
    /// - Returns: True if any field has been changed from original value
    private func hasChanges() -> Bool {
        guard let user = authService.currentUser else { return false }
        
        // Check if image changed - if selectedImage is not nil, it means user selected a new image
        let imageChanged = selectedImage != nil
        
        return username != (user.username ?? "") ||
               firstName != (user.firstName ?? "") ||
               lastName != (user.lastName ?? "") ||
               imageChanged
    }
    
    /// Save profile changes to server
    private func saveProfile() {
        print("🔍 EditProfileView: Starting profile save")
        isSaving = true
        
        Task {
            var newImageUrl: String? = nil
            
            // Handle image upload if changed
            if let selectedImage = selectedImage {
                print("🔍 EditProfileView: Image selected for upload")
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
                    authService.errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    return
                }
            } else {
                newImageUrl = nil // No change
            }
            
            print("🔍 EditProfileView: Updating profile with imageUrl: \(newImageUrl ?? "nil")")
            await authService.updateProfile(
                username: username.isEmpty ? nil : username,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                imageUrl: newImageUrl
            )
            
            isSaving = false
            
            if authService.errorMessage != nil {
                print("🔍 EditProfileView: Profile update failed: \(authService.errorMessage ?? "Unknown error")")
                showingErrorAlert = true
            } else {
                print("🔍 EditProfileView: Profile update successful")
                showingSuccessAlert = true
                HapticFeedback.success()
            }
        }
    }
    
}

#Preview {
    EditProfileView()
        .environmentObject(AuthService.shared)
}

