//
//  ProfileSetupView.swift
//  SniffTest
//
//  View for collecting user profile information during onboarding
//  Shown conditionally when Apple Sign-In doesn't provide the user's name
//

import SwiftUI

/// Profile setup view for collecting user's name and optional username
/// Displayed during onboarding when the user's name is not available (e.g., Apple Sign-In)
struct ProfileSetupView: View {
    
    // MARK: - Bindings
    
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var username: String
    
    // MARK: - State
    
    @FocusState private var focusedField: Field?
    @State private var showFirstNameError = false
    
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
    
    /// Check if username is valid (if provided)
    var isUsernameValid: Bool {
        username.isEmpty || InputValidator.isValidUsername(username)
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
                // First Name (Required)
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("First Name *")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter your first name", text: $firstName)
                        .modernInputField()
                        .autocapitalization(.words)
                        .textContentType(.givenName)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .firstName)
                        .background(
                            showFirstNameError ?
                                Color(hex: "#FFF3E0") :
                                Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(
                                    showFirstNameError ?
                                        Color(hex: "#FFB300") :
                                        Color.clear,
                                    lineWidth: showFirstNameError ? 2 : 0
                                )
                        )
                        .animation(.easeInOut(duration: 0.3), value: showFirstNameError)
                        .onSubmit {
                            focusedField = .lastName
                        }
                        .onChange(of: firstName) { _, _ in
                            showFirstNameError = false
                        }
                    
                    if showFirstNameError {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Color(hex: "#FFB300"))
                            Text("First name is required (at least 2 characters)")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(Color(hex: "#FFB300"))
                        }
                    }
                }
                
                // Last Name (Optional)
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Last Name (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter your last name", text: $lastName)
                        .modernInputField()
                        .autocapitalization(.words)
                        .textContentType(.familyName)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .lastName)
                        .onSubmit {
                            focusedField = .username
                        }
                }
                
                // Username (Optional)
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Username (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Choose a username", text: $username)
                        .modernInputField()
                        .autocapitalization(.none)
                        .textContentType(.username)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .username)
                        .onSubmit {
                            focusedField = nil
                        }
                    
                    if !username.isEmpty && !isUsernameValid {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Color(hex: "#FFB300"))
                            Text("Username must be 3-30 characters, letters, numbers, underscores, and hyphens only")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(Color(hex: "#FFB300"))
                        }
                    } else if username.isEmpty {
                        Text("You can set a username later in your profile settings")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            Spacer()
        }
    }
    
    // MARK: - Methods
    
    /// Validate the form and show errors if invalid
    /// - Returns: True if form is valid
    func validateAndShowErrors() -> Bool {
        if !isFirstNameValid {
            showFirstNameError = true
            focusedField = .firstName
            
            // Auto-hide error after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showFirstNameError = false
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
        username: .constant("")
    )
}

