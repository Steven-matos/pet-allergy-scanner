//
//  ForgotPasswordView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/**
 * Forgot Password View - Trust & Nature Design System Compliant
 * 
 * Redesigned password reset screen following the Trust & Nature Design System:
 * - Proper spacing using ModernDesignSystem.Spacing scale
 * - Typography hierarchy with design system fonts
 * - Trust & Nature color palette throughout
 * - Modern card-based layout with proper shadows
 * - Enhanced visual hierarchy and user experience
 * 
 * Follows SOLID principles with single responsibility for password reset
 * Implements DRY by reusing design system components
 * Follows KISS by keeping the interface clean and intuitive
 */
struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var isEmailValid = false
    @State private var isLoading = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.xl) {
                    // Header Section
                    headerSection
                    
                    // Main Reset Card
                    resetPasswordCard
                    
                    // Cancel Section
                    cancelSection
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
        }
        .alert("Reset Link Sent", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("We've sent a password reset link to \(email). Please check your email and follow the instructions to reset your password.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Reset Password Icon
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .accessibilityLabel("Password reset icon")
            
            // Title with design system typography
            Text("Reset Password")
                .font(ModernDesignSystem.Typography.largeTitle)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            
            // Description with proper color and spacing
            Text("Enter your email address and we'll send you a link to reset your password.")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        }
        .padding(.top, ModernDesignSystem.Spacing.xl)
    }
    
    // MARK: - Reset Password Card
    
    private var resetPasswordCard: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Card Header
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text("Password Reset")
                    .font(ModernDesignSystem.Typography.title)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("We'll send you a secure link to reset your password")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Email Input Section
            emailInputSection
            
            // Reset Button Section
            resetButtonSection
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
    
    // MARK: - Email Input Section
    
    private var emailInputSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Email Label
            Text("Email Address")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            // Email Input Field
            TextField("Enter your email", text: $email)
                .modernInputField()
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .onChange(of: email) { _, newEmail in
                    isEmailValid = InputValidator.isValidEmail(newEmail)
                }
            
            // Email validation feedback
            if !email.isEmpty {
                validationFeedback(
                    isValid: isEmailValid,
                    message: isEmailValid ? "Valid email format" : "Invalid email format"
                )
            }
        }
    }
    
    // MARK: - Reset Button Section
    
    private var resetButtonSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Main reset button
            Button(action: handleResetPassword) {
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(ModernDesignSystem.Colors.textOnPrimary)
                    } else {
                        Image(systemName: "envelope.fill")
                            .font(ModernDesignSystem.Typography.subheadline)
                    }
                    
                    Text("Send Reset Link")
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
            
            // Help text
            Text("Check your email for the reset link. It may take a few minutes to arrive.")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Cancel Section
    
    private var cancelSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            Button("Cancel") {
                dismiss()
            }
            .font(ModernDesignSystem.Typography.body)
            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .padding(.bottom, ModernDesignSystem.Spacing.xl)
    }
    
    // MARK: - Helper Views
    
    private func validationFeedback(isValid: Bool, message: String) -> some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isValid ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
                .font(ModernDesignSystem.Typography.caption)
            
            Text(message)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(isValid ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        return !email.isEmpty && isEmailValid
    }
    
    // MARK: - Helper Methods
    
    private func handleResetPassword() {
        isLoading = true
        
        Task {
            do {
                try await authService.resetPassword(email: email)
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
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AuthService(preview: true))
}