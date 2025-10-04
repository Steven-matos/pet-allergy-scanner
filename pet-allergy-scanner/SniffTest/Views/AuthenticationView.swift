//
//  AuthenticationView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showingAlert = false
    @State private var showingEmailVerificationMessage = false
    @State private var mfaToken = ""
    @State private var showingMFA = false
    @State private var isMFARequired = false
    @State private var passwordValidation: PasswordValidationResult = PasswordValidationResult(isValid: false, issues: [])
    @State private var isPasswordVisible = false
    @State private var confirmEmail = ""
    @State private var isEmailValid = false
    @State private var doEmailsMatch = false
    @State private var isUsernameValid = false
    @State private var showingForgotPassword = false
    @State private var justSwitchedToLogin = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // App Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                    
                    Text("SniffSafe")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("Keep your pets safe with ingredient scanning")
                        .font(.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Show verification success message when switching to login
                if justSwitchedToLogin {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ModernDesignSystem.Colors.safe)
                            Text("Email verification sent!")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(ModernDesignSystem.Colors.safe)
                        }
                        Text("Please check your email and click the verification link, then sign in below.")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(ModernDesignSystem.Colors.safe.opacity(0.1))
                    .cornerRadius(8)
                    .onAppear {
                        // Clear the flag after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            justSwitchedToLogin = false
                        }
                    }
                }
                
                // Show error message inline
                if let errorMessage = authService.errorMessage, 
                   !errorMessage.contains("verify your email") && 
                   !errorMessage.contains("verification link") {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.unsafe)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.unsafe)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(ModernDesignSystem.Colors.unsafe.opacity(0.1))
                    .cornerRadius(8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // Authentication Form
                VStack(spacing: 16) {
                    if !isLoginMode {
                        // Registration fields
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Username", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .onChange(of: username) { _, newUsername in
                                    isUsernameValid = InputValidator.isValidUsername(newUsername)
                                }
                            
                            // Username validation feedback
                            if !username.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: isUsernameValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(isUsernameValid ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
                                        .font(.caption)
                                    
                                    Text(isUsernameValid ? "Valid username" : username.isEmpty ? "Username must be 3-30 characters, letters, numbers, underscores, and hyphens only" : "Username contains inappropriate content or invalid characters")
                                        .font(.caption)
                                        .foregroundColor(isUsernameValid ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
                                }
                            }
                        }
                        
                        TextField("First Name", text: $firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Last Name", text: $lastName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .onChange(of: email) { _, newEmail in
                                isEmailValid = InputValidator.isValidEmail(newEmail)
                                doEmailsMatch = newEmail == confirmEmail && !newEmail.isEmpty
                                // Clear error when user starts typing
                                if authService.errorMessage != nil {
                                    authService.clearError()
                                }
                            }
                        
                        // Email validation feedback
                        // Show email validation feedback only during registration (not in login mode)
                        if !isLoginMode && !email.isEmpty {
                            let isValidInput = isEmailValid || (!email.isEmpty && !email.contains("@"))
                            HStack(spacing: 6) {
                                Image(systemName: isValidInput ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isValidInput ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
                                    .font(.caption)
                                
                                Text(isValidInput ? (isEmailValid ? "Valid email format" : "Valid username format") : "Enter email")
                                    .font(.caption)
                                    .foregroundColor(isValidInput ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
                            }
                        }
                        
                        // Confirm Email Field (only show during registration)
                        if !isLoginMode {
                            TextField("Confirm Email", text: $confirmEmail)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .onChange(of: confirmEmail) { _, newConfirmEmail in
                                    doEmailsMatch = email == newConfirmEmail && !newConfirmEmail.isEmpty && !email.isEmpty
                                }
                            
                            // Email match validation feedback
                            if !confirmEmail.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: doEmailsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(doEmailsMatch ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
                                        .font(.caption)
                                    
                                    Text(doEmailsMatch ? "Emails match" : "Emails do not match")
                                        .font(.caption)
                                        .foregroundColor(doEmailsMatch ? ModernDesignSystem.Colors.safe : ModernDesignSystem.Colors.unsafe)
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .trailing) {
                            if isPasswordVisible {
                                TextField("Password", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                SecureField("Password", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            Button(action: {
                                isPasswordVisible.toggle()
                            }) {
                                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    .font(.system(size: 16))
                            }
                            .padding(.trailing, 12)
                        }
                        .onChange(of: password) { _, newPassword in
                            passwordValidation = InputValidator.validatePassword(newPassword)
                            // Clear error when user starts typing
                            if authService.errorMessage != nil {
                                authService.clearError()
                            }
                        }
                        
                        // Password validation feedback (only show during registration)
                        if !isLoginMode && !password.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                // Password strength indicator
                                HStack {
                                    Text("Password Strength:")
                                        .font(.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    
                                    Text(passwordValidation.strength.description)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(passwordValidation.strength == .strong ? 
                                                       ModernDesignSystem.Colors.safe : 
                                                       passwordValidation.strength == .medium ? 
                                                       ModernDesignSystem.Colors.caution : 
                                                       ModernDesignSystem.Colors.unsafe)
                                }
                                
                                // Validation requirements
                                ForEach(passwordValidation.issues, id: \.self) { issue in
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(ModernDesignSystem.Colors.unsafe)
                                            .font(.caption)
                                        
                                        Text(issue)
                                            .font(.caption)
                                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    }
                                }
                                
                                // Show success message when password is valid
                                if passwordValidation.isValid {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(ModernDesignSystem.Colors.safe)
                                            .font(.caption)
                                        
                                        Text("Password meets all requirements")
                                            .font(.caption)
                                            .foregroundColor(ModernDesignSystem.Colors.safe)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    
                    // Forgot Password Button (only show during login)
                    if isLoginMode {
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                showingForgotPassword = true
                            }
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                        }
                        .padding(.top, 8)
                    }
                    
                    // Submit Button
                    Button(action: handleSubmit) {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(ModernDesignSystem.Colors.textOnPrimary)
                            }
                            Text(isLoginMode ? "Sign In" : "Create Account")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ModernDesignSystem.Colors.buttonPrimary)
                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                        .cornerRadius(10)
                    }
                    .disabled(authService.isLoading || !isFormValid)
                    
                    // MFA Token Field (shown when MFA is required)
                    if isMFARequired {
                        VStack(spacing: 12) {
                            Text("Multi-Factor Authentication")
                                .font(.headline)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            TextField("Enter 6-digit code", text: $mfaToken)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.title2)
                                .monospacedDigit()
                            
                            Button("Verify MFA") {
                                handleMFAVerification()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(ModernDesignSystem.Colors.safe)
                            .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                            .cornerRadius(10)
                            .disabled(mfaToken.count != 6)
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 32)
                
                // Toggle between login and registration
                Button(action: {
                    withAnimation {
                        isLoginMode.toggle()
                        clearForm()
                    }
                }) {
                    Text(isLoginMode ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                        .foregroundColor(ModernDesignSystem.Colors.buttonPrimary)
                }
                .padding(.top, 16)
                
                Spacer()
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(authService.errorMessage ?? "An error occurred")
            }
            .alert("Email Verification Required", isPresented: $showingEmailVerificationMessage) {
                Button("OK") { 
                    // Switch to login mode and clear all fields
                    isLoginMode = true
                    justSwitchedToLogin = true
                    clearForm()
                    authService.clearError()
                }
            } message: {
                Text(authService.errorMessage ?? "Please check your email and click the verification link to activate your account. You can then sign in with your credentials.")
            }
            .onChange(of: authService.errorMessage) { _, errorMessage in
                if let message = errorMessage {
                    // Check if this is an email verification message
                    if message.contains("verify your email") || message.contains("verification link") || message.contains("check your email") {
                        showingEmailVerificationMessage = true
                    } else {
                        showingAlert = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
    }
    
    private var isFormValid: Bool {
        if isLoginMode {
            // For login, allow either valid email or non-empty username
            let isValidInput = isEmailValid || (!email.isEmpty && !email.contains("@"))
            return !email.isEmpty && !password.isEmpty && isValidInput
        } else {
            return !email.isEmpty && !password.isEmpty && !firstName.isEmpty && 
                   isEmailValid && doEmailsMatch && passwordValidation.isValid && 
                   (username.isEmpty || isUsernameValid)
        }
    }
    
    private func handleSubmit() {
        if isLoginMode {
            Task {
                await authService.login(email: email, password: password)
                // Check if MFA is required after login
                if authService.errorMessage?.contains("MFA") == true {
                    isMFARequired = true
                }
            }
        } else {
            Task {
                await authService.register(
                    email: email,
                    password: password,
                    username: username.isEmpty ? nil : username,
                    firstName: firstName.isEmpty ? nil : firstName,
                    lastName: lastName.isEmpty ? nil : lastName
                )
            }
        }
    }
    
    private func handleMFAVerification() {
        Task {
            // This would integrate with the MFA service
            // For now, we'll just clear the MFA requirement
            isMFARequired = false
            mfaToken = ""
        }
    }
    
    private func clearForm() {
        email = ""
        password = ""
        username = ""
        firstName = ""
        lastName = ""
        mfaToken = ""
        isMFARequired = false
        isPasswordVisible = false
        confirmEmail = ""
        isEmailValid = false
        doEmailsMatch = false
        isUsernameValid = false
        passwordValidation = PasswordValidationResult(isValid: false, issues: [])
        justSwitchedToLogin = false
        authService.clearError()
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthService.shared)
}
