//
//  EditProfileView.swift
//  SniffTest
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI

/**
 * Edit Profile View following Trust & Nature Design System
 * 
 * Features:
 * - Card-based layout with soft cream backgrounds
 * - Trust & Nature color palette throughout
 * - Consistent spacing and typography
 * - Professional, nature-inspired design
 * - Accessible form controls
 * 
 * Design System Compliance:
 * - Uses ModernDesignSystem for all styling
 * - Follows Trust & Nature color palette
 * - Implements consistent spacing scale
 * - Applies proper shadows and corner radius
 * - Maintains accessibility standards
 */
struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileService = CachedProfileService.shared
    
    @State private var username: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var selectedImage: UIImage?
    @State private var isSaving = false
    @State private var isUploadingImage = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // MARK: - Profile Photo Card
                    profilePhotoCard
                    
                    // MARK: - Account Information Card
                    accountInformationCard
                    
                    // MARK: - Personal Information Card
                    personalInformationCard
                    
                    // MARK: - Account Details Card
                    accountDetailsCard
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .formKeyboardAvoidance()
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.red.opacity(0.8))
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isUploadingImage {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button("Save") {
                            saveProfile()
                        }
                        .disabled(isSaving || isUploadingImage || !hasChanges())
                        .foregroundColor((isSaving || isUploadingImage || !hasChanges()) ? ModernDesignSystem.Colors.textSecondary : ModernDesignSystem.Colors.primary)
                    }
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
    
    // MARK: - Profile Photo Card
    private var profilePhotoCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Profile Photo")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            // Profile Image Picker
            HStack {
                Spacer()
                ProfileImagePickerView(selectedImage: $selectedImage, currentImageUrl: authService.currentUser?.imageUrl)
                Spacer()
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Account Information Card
    private var accountInformationCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Account Information")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Email (read-only)
                HStack {
                    Text("Email")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Spacer()
                    Text(authService.currentUser?.email ?? "")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                }
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Username
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Username")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    TextField("Enter username", text: $username)
                        .font(ModernDesignSystem.Typography.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .modernInputField()
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Personal Information Card
    private var personalInformationCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Personal Information")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // First Name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("First Name")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    TextField("Enter first name", text: $firstName)
                        .font(ModernDesignSystem.Typography.body)
                        .modernInputField()
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Last Name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Last Name")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    TextField("Enter last name", text: $lastName)
                        .font(ModernDesignSystem.Typography.body)
                        .modernInputField()
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Account Details Card
    private var accountDetailsCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Account Details")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Account Type
                HStack {
                    Text("Account Type")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    Spacer()
                    Text(authService.currentUser?.role.displayName ?? "Free")
                        .font(ModernDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(
                            authService.currentUser?.role == .premium ? 
                            ModernDesignSystem.Colors.goldenYellow : 
                            ModernDesignSystem.Colors.textSecondary
                        )
                        .foregroundColor(
                            authService.currentUser?.role == .premium ? 
                            ModernDesignSystem.Colors.textOnAccent : 
                            ModernDesignSystem.Colors.textOnPrimary
                        )
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                }
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Member Since
                HStack {
                    Text("Member Since")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    Spacer()
                    Text(authService.currentUser?.createdAt ?? Date(), style: .date)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
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
                
                // Validate image before upload
                guard let userId = authService.currentUser?.id, !userId.isEmpty else {
                    await MainActor.run {
                        authService.errorMessage = "User not authenticated. Please sign in and try again."
                        showingErrorAlert = true
                        isSaving = false
                    }
                    return
                }
                
                guard selectedImage.size.width > 0 && selectedImage.size.height > 0 else {
                    await MainActor.run {
                        authService.errorMessage = "Invalid image selected. Please choose a different image."
                        showingErrorAlert = true
                        isSaving = false
                    }
                    return
                }
                
                // Show upload progress
                await MainActor.run {
                    isUploadingImage = true
                }
                
                do {
                    // Replace old image with new one (deletes old, uploads new)
                    let storageService = StorageService.shared
                    newImageUrl = try await storageService.replaceUserImage(
                        oldImageUrl: authService.currentUser?.imageUrl,
                        newImage: selectedImage,
                        userId: userId
                    )
                    print("📸 User image replaced in Supabase: \(newImageUrl ?? "nil")")
                    
                    await MainActor.run {
                        isUploadingImage = false
                    }
                } catch {
                    // Provide user-friendly error message
                    let errorMessage: String
                    if let storageError = error as? StorageError {
                        errorMessage = storageError.localizedDescription
                    } else {
                        errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    }
                    
                    await MainActor.run {
                        isUploadingImage = false
                        authService.errorMessage = errorMessage
                        showingErrorAlert = true
                        isSaving = false
                    }
                    return // Stop profile update if image upload fails
                }
            } else {
                newImageUrl = nil // No change
            }
            
            print("🔍 EditProfileView: Updating profile with imageUrl: \(newImageUrl ?? "nil")")
            
            let userUpdate = UserUpdate(
                username: username.isEmpty ? nil : username,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                imageUrl: newImageUrl,
                role: nil,
                onboarded: nil
            )
            
            do {
                _ = try await profileService.updateProfile(userUpdate)
                
                // Track analytics - determine which fields were updated
                var fieldsUpdated: [String] = []
                let currentUser = authService.currentUser
                if firstName != (currentUser?.firstName ?? "") { fieldsUpdated.append("first_name") }
                if lastName != (currentUser?.lastName ?? "") { fieldsUpdated.append("last_name") }
                if username != (currentUser?.username ?? "") { fieldsUpdated.append("username") }
                if selectedImage != nil { fieldsUpdated.append("image") }
                if !fieldsUpdated.isEmpty {
                    PostHogAnalytics.trackProfileUpdated(fieldsUpdated: fieldsUpdated)
                }
                
                await MainActor.run {
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    authService.errorMessage = "Failed to update profile: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
            
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

