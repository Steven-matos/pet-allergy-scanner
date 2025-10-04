//
//  ForgotPasswordView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

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
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 60))
                        .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                    
                    Text("Reset Password")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Email Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.headline)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .onChange(of: email) { _, newEmail in
                            isEmailValid = InputValidator.isValidEmail(newEmail)
                        }
                    
                    // Email validation feedback
                    if !email.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: isEmailValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isEmailValid ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
                                .font(.caption)
                            
                            Text(isEmailValid ? "Valid email format" : "Invalid email format")
                                .font(.caption)
                                .foregroundColor(isEmailValid ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Reset Password Button
                Button(action: handleResetPassword) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "envelope.fill")
                        }
                        
                        Text("Send Reset Link")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? ModernDesignSystem.Colors.deepForestGreen : ModernDesignSystem.Colors.textSecondary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.headline)
                }
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal)
                
                Spacer()
                
                // Cancel Button
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
    
    private var isFormValid: Bool {
        return !email.isEmpty && isEmailValid
    }
    
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
