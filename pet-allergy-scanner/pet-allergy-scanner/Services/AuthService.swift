//
//  AuthService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/// Authentication service for managing user authentication state using Swift Concurrency
@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    private init() {
        // Check for existing authentication on app launch
        checkAuthenticationStatus()
        
        // Attempt to restore existing auth token and user session
        // Token is persisted securely using Keychain inside APIService
        if apiService.hasAuthToken {
            Task {
                await restoreUserSession()
            }
        }
    }

    /// Internal initializer for SwiftUI previews and testing only
    init(preview: Bool) {
        // Do not perform authentication checks or restore session
        // Allows setting properties for preview/test use
    }
    
    /// Restore user session from stored token
    private func restoreUserSession() async {
        isAuthenticated = true
        isLoading = true
        
        do {
            let user = try await apiService.getCurrentUser()
            currentUser = user
            isLoading = false
        } catch {
            isLoading = false
            logout()
        }
    }
    
    /// Check if user is currently authenticated
    private func checkAuthenticationStatus() {
        // In a real app, you would check for stored tokens here
        // For now, we'll start with no authentication
        isAuthenticated = false
        currentUser = nil
    }
    
    /// Register a new user
    func register(
        email: String,
        password: String,
        username: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        
        let userCreate = UserCreate(
            email: email,
            password: password,
            username: username,
            firstName: firstName,
            lastName: lastName,
            role: .free
        )
        
        do {
            let registrationResponse = try await apiService.register(user: userCreate)
            handleRegistrationResponse(registrationResponse)
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    /// Login user with email and password
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let authResponse = try await apiService.login(email: email, password: password)
            handleAuthResponse(authResponse)
        } catch let apiError as APIError {
            isLoading = false
            // Handle email verification errors as informational messages, not errors
            if case .emailNotVerified(let message) = apiError {
                errorMessage = message
            } else {
                errorMessage = apiError.localizedDescription
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    /// Logout current user
    func logout() {
        apiService.clearAuthToken()
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
    }
    
    /// Update current user profile
    func updateProfile(username: String?, firstName: String?, lastName: String?) async {
        guard isAuthenticated else { return }
        
        isLoading = true
        errorMessage = nil
        
        let userUpdate = UserUpdate(
            username: username,
            firstName: firstName,
            lastName: lastName,
            role: nil
        )
        
        do {
            let user = try await apiService.updateUser(userUpdate)
            currentUser = user
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
    
    /// Handle registration response
    private func handleRegistrationResponse(_ registrationResponse: RegistrationResponse) {
        isLoading = false
        
        if let emailVerificationRequired = registrationResponse.emailVerificationRequired, emailVerificationRequired {
            // Email verification required - show message instead of error
            errorMessage = registrationResponse.message ?? "Please check your email and click the verification link to activate your account."
            isAuthenticated = false
            currentUser = nil
        } else if let accessToken = registrationResponse.accessToken, let user = registrationResponse.user {
            // Email already verified - proceed with login
            apiService.setAuthToken(accessToken)
            isAuthenticated = true
            currentUser = user
            errorMessage = nil
        } else {
            // Fallback error
            errorMessage = "Registration failed. Please try again."
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    /// Handle authentication response
    private func handleAuthResponse(_ authResponse: AuthResponse) {
        // Store the access token in the API service for future requests
        apiService.setAuthToken(authResponse.accessToken)
        isAuthenticated = true
        currentUser = authResponse.user
        isLoading = false
        errorMessage = nil
    }
    
    /// Handle email confirmation from URL redirect
    func handleEmailConfirmation(accessToken: String, refreshToken: String) {
        print("AuthService: Handling email confirmation")
        
        // Store the tokens
        apiService.setAuthToken(accessToken)
        
        // Update authentication state
        isAuthenticated = true
        isLoading = true
        errorMessage = nil
        
        // Fetch user information
        Task {
            do {
                let user = try await apiService.getCurrentUser()
                currentUser = user
                isLoading = false
                print("AuthService: Email confirmation successful")
            } catch {
                print("AuthService: Email confirmation failed - \(error)")
                isLoading = false
                logout()
            }
        }
    }
    
    /// Handle password reset from URL redirect
    func handlePasswordReset(accessToken: String) {
        print("AuthService: Handling password reset")
        
        // Store the token for password reset flow
        apiService.setAuthToken(accessToken)
        
        // You might want to show a password reset form or navigate to a specific screen
        // For now, we'll just set the user as authenticated
        isAuthenticated = true
        isLoading = true
        
        Task {
            do {
                let user = try await apiService.getCurrentUser()
                currentUser = user
                isLoading = false
                print("AuthService: Password reset token validated")
            } catch {
                print("AuthService: Password reset validation failed - \(error)")
                isLoading = false
                logout()
            }
        }
    }
    
    /// Handle general auth callback
    func handleAuthCallback(accessToken: String) {
        print("AuthService: Handling auth callback")
        
        apiService.setAuthToken(accessToken)
        isAuthenticated = true
        isLoading = true
        errorMessage = nil
        
        // Fetch user information
        Task {
            do {
                let user = try await apiService.getCurrentUser()
                currentUser = user
                isLoading = false
                print("AuthService: Auth callback successful")
            } catch {
                print("AuthService: Auth callback failed - \(error)")
                isLoading = false
                logout()
            }
        }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}