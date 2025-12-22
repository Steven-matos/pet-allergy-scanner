//
//  ProfileSetupView.swift
//  SniffTest
//
//  View for collecting user profile information during onboarding
//  Shown conditionally when Apple Sign-In doesn't provide the user's name
//

import SwiftUI

/// Profile setup view for collecting user's name and username
/// Displayed during onboarding when the user's name is not available (e.g., Apple Sign-In)
/// First name and username are required; last name is optional
struct ProfileSetupView: View {
    
    // MARK: - Bindings
    
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var username: String
    @Binding var showFirstNameError: Bool
    @Binding var firstNameShimmy: Bool
    @Binding var showUsernameError: Bool
    @Binding var usernameShimmy: Bool
    
    // MARK: - State
    
    @FocusState private var focusedField: Field?
    
    /// Field identifiers for focus management
    private enum Field: Hashable {
        case firstName
        case lastName
        case username
    }
    
    // MARK: - Computed Properties
    
    /// Check if first name is valid (at least 2 characters)
    var isFirstNameValid: Bool {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }
    
    /// Check if username is valid (required)
    var isUsernameValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && InputValidator.isValidUsername(username.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            // Header
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                
                Text("Complete Your Profile")
                    .font(ModernDesignSystem.Typography.largeTitle)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Tell us your name so we can personalize your experience.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            }
            .padding(.top, ModernDesignSystem.Spacing.xxl)
            
            // Form Fields
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Username (Required)
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Username *")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Choose a username", text: $username)
                        .modernInputField()
                        .autocapitalization(.none)
                        .textContentType(.username)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .username)
                        .background(
                            showUsernameError ?
                                Color.red.opacity(0.1) : // Light red background for validation error
                                Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(
                                    showUsernameError ?
                                        Color.red : // Red border for validation error
                                        Color.clear,
                                    lineWidth: showUsernameError ? 2 : 0
                                )
                        )
                        .offset(x: usernameShimmy ? 10 : -10)
                        .animation(.spring(response: 0.08, dampingFraction: 0.4), value: usernameShimmy)
                        .onAppear {
                            usernameShimmy = false
                        }
                        .animation(.easeInOut(duration: 0.3), value: showUsernameError)
                        .onSubmit {
                            focusedField = .firstName
                        }
                        .onChange(of: username) { _, _ in
                            showUsernameError = false
                            usernameShimmy = false
                        }
                    
                    if showUsernameError {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Username is required (3-30 characters)")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text("Username must be 3-30 characters, letters, numbers, underscores, and hyphens only")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // First Name and Last Name (side by side)
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    // First Name (Required)
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        Text("First Name *")
                            .font(ModernDesignSystem.Typography.bodyEmphasized)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        TextField("First name", text: $firstName)
                            .modernInputField()
                            .autocapitalization(.words)
                            .textContentType(.givenName)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .firstName)
                            .background(
                                showFirstNameError ?
                                    Color.red.opacity(0.1) : // Light red background for validation error
                                    Color.clear
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                    .stroke(
                                        showFirstNameError ?
                                            Color.red : // Red border for validation error
                                            Color.clear,
                                        lineWidth: showFirstNameError ? 2 : 0
                                    )
                            )
                            .offset(x: firstNameShimmy ? 10 : -10)
                            .animation(.spring(response: 0.08, dampingFraction: 0.4), value: firstNameShimmy)
                            .onAppear {
                                firstNameShimmy = false
                            }
                            .animation(.easeInOut(duration: 0.3), value: showFirstNameError)
                            .onSubmit {
                                focusedField = .lastName
                            }
                            .onChange(of: firstName) { _, _ in
                                showFirstNameError = false
                                firstNameShimmy = false
                            }
                        
                        if showFirstNameError {
                            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("First name is required (at least 2 characters)")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    // Last Name (Optional)
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        Text("Last Name (Optional)")
                            .font(ModernDesignSystem.Typography.bodyEmphasized)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        TextField("Last name", text: $lastName)
                            .modernInputField()
                            .autocapitalization(.words)
                            .textContentType(.familyName)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .lastName)
                            .onSubmit {
                                focusedField = nil
                            }
                    }
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            Spacer()
        }
    }
    
    // MARK: - Methods
    
    /// Dismisses the keyboard by clearing focus from all fields
    func dismissKeyboard() {
        focusedField = nil
    }
    
    /// Validate the form and show errors if invalid
    /// - Returns: True if form is valid
    func validateAndShowErrors() -> Bool {
        if !isFirstNameValid {
            showFirstNameError = true
            firstNameShimmy = true
            focusedField = .firstName
            
            // Trigger shimmy animation sequence
            Task { @MainActor in
                // First shake right
                firstNameShimmy = true
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                // Then shake left
                firstNameShimmy = false
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                // Shake right again
                firstNameShimmy = true
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                // Return to center
                firstNameShimmy = false
            }
            
            // Auto-hide error after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showFirstNameError = false
            }
            return false
        }
        
        if !isUsernameValid {
            showUsernameError = true
            usernameShimmy = true
            focusedField = .username
            
            // Trigger shimmy animation sequence
            Task { @MainActor in
                // First shake right
                usernameShimmy = true
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                // Then shake left
                usernameShimmy = false
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                // Shake right again
                usernameShimmy = true
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                // Return to center
                usernameShimmy = false
            }
            
            // Auto-hide error after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showUsernameError = false
            }
            return false
        }
        
        return true
    }
}

// MARK: - Preview

#Preview {
    ProfileSetupView(
        firstName: .constant(""),
        lastName: .constant(""),
        username: .constant(""),
        showFirstNameError: .constant(false),
        firstNameShimmy: .constant(false),
        showUsernameError: .constant(false),
        usernameShimmy: .constant(false)
    )
}

