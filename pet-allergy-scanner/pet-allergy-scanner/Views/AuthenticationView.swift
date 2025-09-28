//
//  AuthenticationView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showingAlert = false
    @State private var mfaToken = ""
    @State private var showingMFA = false
    @State private var isMFARequired = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // App Logo and Title
                VStack(spacing: 16) {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Pet Allergy Scanner")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Keep your pets safe with ingredient scanning")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Authentication Form
                VStack(spacing: 16) {
                    if !isLoginMode {
                        // Registration fields
                        TextField("First Name", text: $firstName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Last Name", text: $lastName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    // Submit Button
                    Button(action: handleSubmit) {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isLoginMode ? "Sign In" : "Create Account")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(authService.isLoading || !isFormValid)
                    
                    // MFA Token Field (shown when MFA is required)
                    if isMFARequired {
                        VStack(spacing: 12) {
                            Text("Multi-Factor Authentication")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
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
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .disabled(mfaToken.count != 6)
                        }
                        .padding(.top, 20)
                    }
                }
                .padding(.horizontal, 32)
                
                // Toggle between login and registration
                Button(action: {
                    isLoginMode.toggle()
                    clearForm()
                }) {
                    Text(isLoginMode ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                        .foregroundColor(.blue)
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
            .onChange(of: authService.errorMessage) { errorMessage in
                if errorMessage != nil {
                    showingAlert = true
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        if isLoginMode {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty && !firstName.isEmpty
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
        firstName = ""
        lastName = ""
        mfaToken = ""
        isMFARequired = false
        authService.clearError()
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthService.shared)
}
