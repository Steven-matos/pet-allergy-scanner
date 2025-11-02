//
//  AuthenticationView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/**
 * Authentication View - Trust & Nature Design System Compliant
 * 
 * Redesigned login and sign up screen following the Trust & Nature Design System:
 * - Proper spacing using ModernDesignSystem.Spacing scale
 * - Typography hierarchy with design system fonts
 * - Trust & Nature color palette throughout
 * - Modern card-based layout with proper shadows
 * - Enhanced visual hierarchy and user experience
 * 
 * Follows SOLID principles with single responsibility for authentication
 * Implements DRY by reusing design system components
 * Follows KISS by keeping the interface clean and intuitive
 */
struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isLoginMode = true // Default to login mode (most users have accounts)
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
    
    // MARK: - Focus Management
    
    /// Field identifiers for focus management
    private enum Field: Hashable {
        case username
        case firstName
        case lastName
        case email
        case confirmEmail
        case password
        case mfaToken
    }
    
    @FocusState private var focusedField: Field?
    @StateObject private var keyboardManager = KeyboardAvoidanceManager()
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.xl) {
                    // Header Section with proper spacing
                    headerSection
                    
                    // Main Authentication Card
                    authenticationCard
                    
                    // Mode Toggle Section
                    modeToggleSection
                }
                .padding(ModernDesignSystem.Spacing.lg)
                .padding(.bottom, keyboardManager.isKeyboardVisible ? max(keyboardManager.keyboardHeight + 40, 300) : 0) // Dynamic padding: show padding when keyboard is visible, remove when dismissed
            }
            .formKeyboardAvoidance()
            .background(ModernDesignSystem.Colors.background)
            .ignoresSafeArea(.all)
            .onChange(of: focusedField) { _, newField in
                // Scroll to focused field when keyboard appears
                if let field = newField {
                    // Small delay to ensure keyboard animation starts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(authService.errorMessage ?? "An error occurred")
        }
        .alert("Registration Successful", isPresented: Binding(
            get: { showingEmailVerificationMessage && !isLoginMode }, // Only show if in sign-up mode
            set: { showingEmailVerificationMessage = $0 }
        )) {
            Button("OK") { 
                isLoginMode = true
                justSwitchedToLogin = true
                clearForm()
                showingEmailVerificationMessage = false
                // Don't clear error here - let it show in status section
            }
        } message: {
            Text(authService.errorMessage ?? "Registration successful! Please check your email and click the verification link to activate your account. You can then sign in with your credentials.")
        }
        .onChange(of: authService.errorMessage) { _, errorMessage in
            if let message = errorMessage {
                if isEmailVerificationMessage(message) {
                    // Only show alert for registration (sign up mode)
                    // For login mode, show in status section instead
                    if !isLoginMode {
                        showingEmailVerificationMessage = true
                    }
                    // In login mode, message will appear in status section (no alert)
                } else {
                    showingAlert = true
                }
            }
        }
        .sheet(isPresented: $showingForgotPassword) {
            ForgotPasswordView()
        }
        .onChange(of: isLoginMode) { _, newValue in
            // Auto-focus first field when switching modes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if newValue {
                    focusedField = .email
                } else {
                    focusedField = .username
                }
            }
        }
        .onChange(of: isMFARequired) { _, newValue in
            // Auto-focus MFA field when MFA is required
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .mfaToken
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // App Logo with proper styling
            Image("Branding/app-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .cornerRadius(ModernDesignSystem.CornerRadius.large)
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
                .accessibilityLabel("SniffTest app logo")
            
            // App Title with design system typography
            Text("SniffTest")
                .font(ModernDesignSystem.Typography.largeTitle)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            
            // Subtitle with proper color and spacing
            Text("Keep your pets safe with ingredient scanning")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        }
        .padding(.top, ModernDesignSystem.Spacing.xl)
    }
    
    // MARK: - Authentication Card
    
    private var authenticationCard: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Card Header
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text(isLoginMode ? "Welcome Back" : "Create Account")
                    .font(ModernDesignSystem.Typography.title)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(isLoginMode ? "Sign in to continue" : "Join SniffTest to protect your pets")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Status Messages
            statusMessagesSection
            
            // Authentication Form
            authenticationFormSection
            
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
    
    // MARK: - Status Messages Section
    
    private var statusMessagesSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Email verification message (from registration or login)
            if justSwitchedToLogin || isEmailVerificationMessage(authService.errorMessage) {
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.safe)
                            .font(ModernDesignSystem.Typography.subheadline)
                        Text(justSwitchedToLogin ? "Email verification sent!" : 
                             (isLoginMode ? "Email Verification Required" : "Registration successful!"))
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ModernDesignSystem.Colors.safe)
                    }
                    Text(isEmailVerificationMessage(authService.errorMessage) ? 
                         (authService.errorMessage ?? "Please check your email and click the verification link to activate your account. You can then sign in with your credentials.") :
                         "Please check your email and click the verification link, then sign in below.")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.safe.opacity(0.1))
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                        justSwitchedToLogin = false
                        // Clear the email verification message after showing
                        if isEmailVerificationMessage(authService.errorMessage) {
                            authService.clearError()
                        }
                    }
                }
            }
            
            // Error message (non-email verification errors)
            if let errorMessage = authService.errorMessage, 
               !isEmailVerificationMessage(errorMessage) {
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ModernDesignSystem.Colors.unsafe)
                        .font(ModernDesignSystem.Typography.subheadline)
                    Text(errorMessage)
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.unsafe)
                        .multilineTextAlignment(.leading)
                    Spacer()
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.unsafe.opacity(0.1))
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    /// Helper to check if error message is about email verification
    private func isEmailVerificationMessage(_ message: String?) -> Bool {
        guard let message = message else { return false }
        let lowerMessage = message.lowercased()
        return lowerMessage.contains("verify your email") ||
               lowerMessage.contains("verification link") ||
               lowerMessage.contains("check your email") ||
               lowerMessage.contains("registration successful") ||
               (lowerMessage.contains("email") && lowerMessage.contains("verification")) ||
               (lowerMessage.contains("verify") && lowerMessage.contains("email"))
    }
    
    // MARK: - Authentication Form Section
    
    private var authenticationFormSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            if !isLoginMode {
                // Registration fields with proper spacing
                registrationFieldsSection
            }
            
            // Email field with validation
            emailFieldSection
            
            // Password field with validation
            passwordFieldSection
            
            // Forgot Password (login only)
            if isLoginMode {
                forgotPasswordSection
            }
        }
    }
    
    // MARK: - Registration Fields Section
    
    private var registrationFieldsSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Username field
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                TextField("Username", text: $username)
                    .modernInputField()
                    .autocapitalization(.none)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .username)
                    .id(Field.username)
                    .onSubmit {
                        // Move focus to first name field
                        focusedField = .firstName
                    }
                    .onChange(of: username) { _, newUsername in
                        isUsernameValid = InputValidator.isValidUsername(newUsername)
                    }
                
                if !username.isEmpty {
                    validationFeedback(
                        isValid: isUsernameValid,
                        message: isUsernameValid ? "Valid username" : "Username must be 3-30 characters, letters, numbers, underscores, and hyphens only"
                    )
                }
            }
            
            // Name fields in a row
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                TextField("First Name", text: $firstName)
                    .modernInputField()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .firstName)
                    .id(Field.firstName)
                    .onSubmit {
                        // Move focus to last name field
                        focusedField = .lastName
                    }
                
                TextField("Last Name", text: $lastName)
                    .modernInputField()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .lastName)
                    .id(Field.lastName)
                    .onSubmit {
                        // Move focus to email field
                        focusedField = .email
                    }
            }
        }
    }
    
    // MARK: - Email Field Section
    
    private var emailFieldSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            TextField("Email", text: $email)
                .modernInputField()
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .submitLabel(.next)
                .focused($focusedField, equals: .email)
                .id(Field.email)
                .onSubmit {
                    // Move focus to confirm email or password field
                    if isLoginMode {
                        focusedField = .password
                    } else {
                        focusedField = .confirmEmail
                    }
                }
                .onChange(of: email) { _, newEmail in
                    isEmailValid = InputValidator.isValidEmail(newEmail)
                    doEmailsMatch = newEmail == confirmEmail && !newEmail.isEmpty
                    if authService.errorMessage != nil {
                        authService.clearError()
                    }
                }
            
            // Email validation feedback (registration only)
            if !isLoginMode && !email.isEmpty {
                let isValidInput = isEmailValid || (!email.isEmpty && !email.contains("@"))
                validationFeedback(
                    isValid: isValidInput,
                    message: isValidInput ? (isEmailValid ? "Valid email format" : "Valid username format") : "Enter email"
                )
            }
            
            // Confirm Email Field (registration only)
            if !isLoginMode {
                TextField("Confirm Email", text: $confirmEmail)
                    .modernInputField()
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .confirmEmail)
                    .id(Field.confirmEmail)
                    .onSubmit {
                        // Move focus to password field
                        focusedField = .password
                    }
                    .onChange(of: confirmEmail) { _, newConfirmEmail in
                        doEmailsMatch = email == newConfirmEmail && !newConfirmEmail.isEmpty && !email.isEmpty
                    }
                
                if !confirmEmail.isEmpty {
                    validationFeedback(
                        isValid: doEmailsMatch,
                        message: doEmailsMatch ? "Emails match" : "Emails do not match"
                    )
                }
            }
        }
    }
    
    // MARK: - Password Field Section
    
    private var passwordFieldSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            ZStack(alignment: .trailing) {
                if isPasswordVisible {
                    TextField("Password", text: $password)
                        .modernInputField()
                        .submitLabel(isLoginMode ? .done : .next)
                        .focused($focusedField, equals: .password)
                        .id(Field.password)
                        .onSubmit {
                            // Submit form if valid or dismiss keyboard
                            if isFormValid {
                                focusedField = nil
                                handleSubmit()
                            }
                        }
                } else {
                    SecureField("Password", text: $password)
                        .modernInputField()
                        .submitLabel(isLoginMode ? .done : .next)
                        .focused($focusedField, equals: .password)
                        .id(Field.password)
                        .onSubmit {
                            // Submit form if valid or dismiss keyboard
                            if isFormValid {
                                focusedField = nil
                                handleSubmit()
                            }
                        }
                }
                
                Button(action: {
                    isPasswordVisible.toggle()
                }) {
                    Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .font(ModernDesignSystem.Typography.subheadline)
                }
                .padding(.trailing, ModernDesignSystem.Spacing.md)
            }
            .onChange(of: password) { _, newPassword in
                passwordValidation = InputValidator.validatePassword(newPassword)
                if authService.errorMessage != nil {
                    authService.clearError()
                }
            }
            
            // Password validation feedback (registration only)
            if !isLoginMode && !password.isEmpty {
                passwordValidationSection
            }
        }
    }
    
    // MARK: - Password Validation Section
    
    private var passwordValidationSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            // Password strength indicator
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text("Password Strength:")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text(passwordValidation.strength.description)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(passwordValidation.strength == .strong ? 
                                   ModernDesignSystem.Colors.safe : 
                                   passwordValidation.strength == .medium ? 
                                   ModernDesignSystem.Colors.caution : 
                                   ModernDesignSystem.Colors.unsafe)
            }
            
            // Validation requirements
            ForEach(passwordValidation.issues, id: \.self) { issue in
                validationFeedback(
                    isValid: false,
                    message: issue
                )
            }
            
            // Success message
            if passwordValidation.isValid {
                validationFeedback(
                    isValid: true,
                    message: "Password meets all requirements"
                )
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
    }
    
    // MARK: - Forgot Password Section
    
    private var forgotPasswordSection: some View {
        HStack {
            Spacer()
            Button("Forgot Password?") {
                showingForgotPassword = true
            }
            .font(ModernDesignSystem.Typography.caption)
            .foregroundColor(ModernDesignSystem.Colors.primary)
        }
    }
    
    // MARK: - Submit Button Section
    
    private var submitButtonSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Main submit button
            Button(action: handleSubmit) {
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(ModernDesignSystem.Colors.textOnPrimary)
                    }
                    Text(isLoginMode ? "Sign In" : "Create Account")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                }
                .frame(maxWidth: .infinity)
                .padding(ModernDesignSystem.Spacing.lg)
                .background(ModernDesignSystem.Colors.buttonPrimary)
                .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
            }
            .disabled(authService.isLoading || !isFormValid)
            
            // MFA Token Field (shown when MFA is required)
            if isMFARequired {
                mfaSection
            }
        }
    }
    
    // MARK: - MFA Section
    
    private var mfaSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            Text("Multi-Factor Authentication")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            TextField("Enter 6-digit code", text: $mfaToken)
                .modernInputField()
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(ModernDesignSystem.Typography.title2)
                .monospacedDigit()
                .focused($focusedField, equals: .mfaToken)
                .id(Field.mfaToken)
                .onSubmit {
                    if mfaToken.count == 6 {
                        focusedField = nil
                        handleMFAVerification()
                    }
                }
            
            Button("Verify MFA") {
                handleMFAVerification()
            }
            .modernButton(style: .success)
            .disabled(mfaToken.count != 6)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Mode Toggle Section
    
    private var modeToggleSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            Button(action: {
                // Dismiss keyboard first
                focusedField = nil
                withAnimation(.easeInOut(duration: 0.3)) {
                    isLoginMode.toggle()
                    clearForm()
                }
            }) {
                Text(isLoginMode ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
            }
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
    
    // MARK: - Helper Methods
    
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
        focusedField = nil
        authService.clearError()
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthService.shared)
}