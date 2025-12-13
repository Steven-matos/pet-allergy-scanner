//
//  SetNewPasswordView.swift
//  SniffTest
//
//  Created by Steven Matos on 12/12/25.
//

import SwiftUI

/**
 * Set New Password View - Trust & Nature Design System Compliant
 *
 * Displayed after user clicks password reset link from email.
 * Allows user to set a new password before logging in.
 *
 * Flow:
 * 1. User requests password reset (ForgotPasswordView)
 * 2. User receives email with reset link
 * 3. User clicks link, app opens with recovery token
 * 4. This view is shown to set new password
 * 5. After success, user is redirected to login
 *
 * Follows SOLID principles with single responsibility for password setting
 * Implements DRY by reusing design system components
 * Follows KISS by keeping the interface clean and intuitive
 */
struct SetNewPasswordView: View {
    @EnvironmentObject var authService: AuthService
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    // MARK: - Password Validation States
    @State private var hasMinLength = false
    @State private var hasUppercase = false
    @State private var hasLowercase = false
    @State private var hasNumber = false
    @State private var hasSpecialChar = false
    @State private var passwordsMatch = false
    
    // MARK: - Focus Management
    private enum Field: Hashable {
        case password
        case confirmPassword
    }
    
    @FocusState private var focusedField: Field?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.xl) {
                    // Header Section
                    headerSection
                    
                    // Main Password Card
                    passwordCard
                    
                    // Cancel Section
                    cancelSection
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
            .formKeyboardAvoidance()
            .background(ModernDesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
        }
        .alert("Password Updated", isPresented: $showingSuccessAlert) {
            Button("Log In") {
                // User will be redirected to login automatically
            }
        } message: {
            Text("Your password has been updated successfully. Please log in with your new password.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Auto-focus password field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .password
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Lock Icon
            Image(systemName: "lock.rotation")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .accessibilityLabel("Set new password icon")
            
            // Title
            Text("Set New Password")
                .font(ModernDesignSystem.Typography.largeTitle)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            
            // Description
            Text("Create a strong password for your account. You'll use this to log in.")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        }
        .padding(.top, ModernDesignSystem.Spacing.xl)
    }
    
    // MARK: - Password Card
    
    private var passwordCard: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Card Header
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text("Create Password")
                    .font(ModernDesignSystem.Typography.title)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Choose a secure password that you haven't used before")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Password Input
            passwordInputSection
            
            // Confirm Password Input
            confirmPasswordInputSection
            
            // Password Requirements
            passwordRequirementsSection
            
            // Submit Button
            submitButtonSection
        }
        .padding(ModernDesignSystem.Spacing.xl)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.large)
        .shadow(
            color: ModernDesignSystem.Shadows.medium.color,
            radius: ModernDesignSystem.Shadows.medium.radius,
            x: ModernDesignSystem.Shadows.medium.x,
            y: ModernDesignSystem.Shadows.medium.y
        )
    }
    
    // MARK: - Password Input Section
    
    private var passwordInputSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("New Password")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            HStack {
                Group {
                    if showPassword {
                        TextField("Enter new password", text: $password)
                    } else {
                        SecureField("Enter new password", text: $password)
                    }
                }
                .modernInputField()
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .confirmPassword
                }
                .onChange(of: password) { _, newValue in
                    validatePassword(newValue)
                }
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(.trailing, ModernDesignSystem.Spacing.sm)
            }
        }
    }
    
    // MARK: - Confirm Password Input Section
    
    private var confirmPasswordInputSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Confirm Password")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            HStack {
                Group {
                    if showConfirmPassword {
                        TextField("Confirm new password", text: $confirmPassword)
                    } else {
                        SecureField("Confirm new password", text: $confirmPassword)
                    }
                }
                .modernInputField()
                .focused($focusedField, equals: .confirmPassword)
                .submitLabel(.done)
                .onSubmit {
                    if isFormValid {
                        focusedField = nil
                        handleSetPassword()
                    }
                }
                .onChange(of: confirmPassword) { _, newValue in
                    passwordsMatch = !newValue.isEmpty && newValue == password
                }
                
                Button(action: { showConfirmPassword.toggle() }) {
                    Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(.trailing, ModernDesignSystem.Spacing.sm)
            }
            
            // Passwords match feedback
            if !confirmPassword.isEmpty {
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(passwordsMatch ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
                        .font(ModernDesignSystem.Typography.caption)
                    
                    Text(passwordsMatch ? "Passwords match" : "Passwords do not match")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(passwordsMatch ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
                }
            }
        }
    }
    
    // MARK: - Password Requirements Section
    
    private var passwordRequirementsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Password Requirements")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                requirementRow(met: hasMinLength, text: "At least 8 characters")
                requirementRow(met: hasUppercase, text: "One uppercase letter")
                requirementRow(met: hasLowercase, text: "One lowercase letter")
                requirementRow(met: hasNumber, text: "One number")
                requirementRow(met: hasSpecialChar, text: "One special character (!@#$%^&*)")
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.background.opacity(0.5))
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
    }
    
    /// Helper view for password requirement row
    private func requirementRow(met: Bool, text: String) -> some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundColor(met ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.textSecondary)
                .font(ModernDesignSystem.Typography.caption)
            
            Text(text)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(met ? ModernDesignSystem.Colors.textPrimary : ModernDesignSystem.Colors.textSecondary)
        }
    }
    
    // MARK: - Submit Button Section
    
    private var submitButtonSection: some View {
        Button(action: handleSetPassword) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(ModernDesignSystem.Colors.textOnPrimary)
                } else {
                    Image(systemName: "checkmark.shield.fill")
                        .font(ModernDesignSystem.Typography.subheadline)
                }
                
                Text("Set New Password")
                    .font(ModernDesignSystem.Typography.bodyEmphasized)
            }
            .frame(maxWidth: .infinity)
            .padding(ModernDesignSystem.Spacing.lg)
            .background(isFormValid ? ModernDesignSystem.Colors.buttonPrimary : ModernDesignSystem.Colors.textSecondary)
            .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
        }
        .disabled(!isFormValid || isLoading)
    }
    
    // MARK: - Cancel Section
    
    private var cancelSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            Button("Cancel") {
                handleCancel()
            }
            .font(ModernDesignSystem.Typography.body)
            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            Text("Cancelling will return you to the login screen.")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, ModernDesignSystem.Spacing.xl)
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar && passwordsMatch
    }
    
    // MARK: - Helper Methods
    
    /// Validate password against requirements
    private func validatePassword(_ password: String) {
        hasMinLength = password.count >= 8
        hasUppercase = password.contains(where: { $0.isUppercase })
        hasLowercase = password.contains(where: { $0.isLowercase })
        hasNumber = password.contains(where: { $0.isNumber })
        hasSpecialChar = password.contains(where: { "!@#$%^&*(),.?\":{}|<>".contains($0) })
        
        // Update passwords match if confirm password is not empty
        if !confirmPassword.isEmpty {
            passwordsMatch = confirmPassword == password
        }
    }
    
    /// Handle set password action
    private func handleSetPassword() {
        guard isFormValid else { return }
        
        isLoading = true
        
        Task {
            do {
                try await authService.updatePassword(newPassword: password)
                await MainActor.run {
                    isLoading = false
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    showingErrorAlert = true
                }
            }
        }
    }
    
    /// Handle cancel action
    private func handleCancel() {
        Task {
            await authService.cancelPasswordReset()
        }
    }
}

#Preview {
    SetNewPasswordView()
        .environmentObject(AuthService(preview: true))
}

