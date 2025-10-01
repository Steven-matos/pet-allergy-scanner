//
//  AuthService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/// Authentication state enum to prevent intermediate states and UI flashing
enum AuthState: Equatable {
    /// Initial state when determining authentication status
    case initializing
    /// Loading user data or performing authentication
    case loading
    /// User is authenticated with valid user data
    case authenticated(User)
    /// User is not authenticated
    case unauthenticated
    
    /// Convenience property to check if authenticated
    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
    
    /// Get the current user if authenticated
    var user: User? {
        if case .authenticated(let user) = self {
            return user
        }
        return nil
    }
    
    /// Check if currently loading
    var isLoading: Bool {
        switch self {
        case .initializing, .loading:
            return true
        default:
            return false
        }
    }
    
    /// Custom equality implementation
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing),
             (.loading, .loading),
             (.unauthenticated, .unauthenticated):
            return true
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.id == rhsUser.id && lhsUser.onboarded == rhsUser.onboarded
        default:
            return false
        }
    }
}

/// Authentication service for managing user authentication state using Swift Concurrency
@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var authState: AuthState = .initializing
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    /// Convenience computed properties for backward compatibility
    var isAuthenticated: Bool { authState.isAuthenticated }
    var currentUser: User? { authState.user }
    var isLoading: Bool { authState.isLoading }
    
    private init() {
        // Attempt to restore existing auth token and user session
        // Token is persisted securely using Keychain inside APIService
        if apiService.hasAuthToken {
            Task {
                await restoreUserSession()
            }
        } else {
            // No token found, user is unauthenticated
            authState = .unauthenticated
        }
    }

    /// Internal initializer for SwiftUI previews and testing only
    init(preview: Bool) {
        // Do not perform authentication checks or restore session
        // Allows setting properties for preview/test use
    }
    
    /// Restore user session from stored token
    private func restoreUserSession() async {
        authState = .loading
        
        do {
            var user = try await apiService.getCurrentUser()
            
            // Auto-complete onboarding if user has pets but onboarded is false
            user = await checkAndCompleteOnboardingIfNeeded(user: user)
            
            // Only transition to authenticated once we have complete user data
            authState = .authenticated(user)
        } catch {
            // Failed to restore session, logout
            logout()
        }
    }
    
    /// Register a new user
    func register(
        email: String,
        password: String,
        username: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil
    ) async {
        authState = .loading
        errorMessage = nil
        
        let userCreate = UserCreate(
            email: email,
            password: password,
            username: username,
            firstName: firstName,
            lastName: lastName,
            role: .free,
            onboarded: false
        )
        
        do {
            let registrationResponse = try await apiService.register(user: userCreate)
            await handleRegistrationResponse(registrationResponse)
        } catch {
            authState = .unauthenticated
            errorMessage = error.localizedDescription
        }
    }
    
    /// Login user with email and password
    func login(email: String, password: String) async {
        authState = .loading
        errorMessage = nil
        
        do {
            let authResponse = try await apiService.login(email: email, password: password)
            await handleAuthResponse(authResponse)
        } catch let apiError as APIError {
            authState = .unauthenticated
            // Handle email verification errors as informational messages, not errors
            if case .emailNotVerified(let message) = apiError {
                errorMessage = message
            } else {
                errorMessage = apiError.localizedDescription
            }
        } catch {
            authState = .unauthenticated
            errorMessage = error.localizedDescription
        }
    }
    
    /// Reset password for user
    func resetPassword(email: String) async throws {
        try await apiService.resetPassword(email: email)
    }
    
    /// Logout current user
    /// Clears authentication state and all user-related data
    func logout() {
        apiService.clearAuthToken()
        authState = .unauthenticated
        errorMessage = nil
        
        // Clear all user data to prevent 403 errors on logout
        PetService.shared.clearPets()
        ScanService.shared.clearScans()
    }
    
    /// Update current user profile
    func updateProfile(username: String?, firstName: String?, lastName: String?, imageUrl: String? = nil) async {
        guard case .authenticated(let currentUser) = authState else { return }
        
        authState = .loading
        errorMessage = nil
        
        let userUpdate = UserUpdate(
            username: username,
            firstName: firstName,
            lastName: lastName,
            imageUrl: imageUrl,
            role: nil,
            onboarded: nil
        )
        
        do {
            let user = try await apiService.updateUser(userUpdate)
            authState = .authenticated(user)
        } catch {
            // Restore previous state on error
            authState = .authenticated(currentUser)
            errorMessage = error.localizedDescription
        }
    }
    
    /// Handle registration response
    private func handleRegistrationResponse(_ registrationResponse: RegistrationResponse) async {
        if let emailVerificationRequired = registrationResponse.emailVerificationRequired, emailVerificationRequired {
            // Email verification required - show message instead of error
            authState = .unauthenticated
            errorMessage = registrationResponse.message ?? "Please check your email and click the verification link to activate your account."
        } else if let accessToken = registrationResponse.accessToken {
            // Email already verified - proceed with login flow
            apiService.setAuthToken(accessToken)
            errorMessage = nil
            
            // Fetch fresh user data from /me endpoint to get accurate onboarded status
            do {
                var freshUser = try await apiService.getCurrentUser()
                
                // Only run auto-onboarding check if user is not already onboarded
                if !freshUser.onboarded {
                    freshUser = await checkAndCompleteOnboardingIfNeeded(user: freshUser)
                }
                
                // Only transition to authenticated once we have complete user data
                authState = .authenticated(freshUser)
            } catch {
                // Fallback to registration response user if getCurrentUser fails
                if let user = registrationResponse.user {
                    authState = .authenticated(user)
                } else {
                    authState = .unauthenticated
                    errorMessage = "Registration failed. Please try again."
                }
            }
        } else {
            // Fallback error
            authState = .unauthenticated
            errorMessage = "Registration failed. Please try again."
        }
    }
    
    /// Handle authentication response
    private func handleAuthResponse(_ authResponse: AuthResponse) async {
        // Store the access token in the API service for future requests
        apiService.setAuthToken(authResponse.accessToken)
        errorMessage = nil
        
        // Fetch fresh user data from /me endpoint to get accurate onboarded status
        // This prevents the flicker of showing onboarding screen for users who already completed it
        do {
            var freshUser = try await apiService.getCurrentUser()
            
            // Only run auto-onboarding check if user is not already onboarded
            if !freshUser.onboarded {
                freshUser = await checkAndCompleteOnboardingIfNeeded(user: freshUser)
            }
            
            // Only transition to authenticated once we have complete user data
            authState = .authenticated(freshUser)
        } catch {
            // Fallback to auth response user if getCurrentUser fails
            authState = .authenticated(authResponse.user)
        }
    }
    
    /// Handle email confirmation from URL redirect
    func handleEmailConfirmation(accessToken: String, refreshToken: String) {
        print("AuthService: Handling email confirmation")
        
        // Store the tokens
        apiService.setAuthToken(accessToken)
        authState = .loading
        errorMessage = nil
        
        // Fetch user information
        Task {
            do {
                var user = try await apiService.getCurrentUser()
                
                // Only run auto-onboarding check if user is not already onboarded
                if !user.onboarded {
                    user = await checkAndCompleteOnboardingIfNeeded(user: user)
                }
                
                authState = .authenticated(user)
                print("AuthService: Email confirmation successful")
            } catch {
                print("AuthService: Email confirmation failed - \(error)")
                logout()
            }
        }
    }
    
    /// Handle password reset from URL redirect
    func handlePasswordReset(accessToken: String) {
        print("AuthService: Handling password reset")
        
        // Store the token for password reset flow
        apiService.setAuthToken(accessToken)
        authState = .loading
        
        Task {
            do {
                let user = try await apiService.getCurrentUser()
                authState = .authenticated(user)
                print("AuthService: Password reset token validated")
            } catch {
                print("AuthService: Password reset validation failed - \(error)")
                logout()
            }
        }
    }
    
    /// Handle general auth callback
    func handleAuthCallback(accessToken: String) {
        print("AuthService: Handling auth callback")
        
        apiService.setAuthToken(accessToken)
        authState = .loading
        errorMessage = nil
        
        // Fetch user information
        Task {
            do {
                var user = try await apiService.getCurrentUser()
                
                // Only run auto-onboarding check if user is not already onboarded
                if !user.onboarded {
                    user = await checkAndCompleteOnboardingIfNeeded(user: user)
                }
                
                authState = .authenticated(user)
                print("AuthService: Auth callback successful")
            } catch {
                print("AuthService: Auth callback failed - \(error)")
                logout()
            }
        }
    }
    
    /// Refresh current user data from server
    func refreshCurrentUser() async {
        guard case .authenticated = authState else { return }
        
        do {
            let user = try await apiService.getCurrentUser()
            authState = .authenticated(user)
        } catch {
            print("Failed to refresh user data: \(error)")
        }
    }
    
    /// Check if user has pets and auto-complete onboarding if needed
    /// Returns updated user with onboarded=true if pets exist, or original user otherwise
    /// This ensures users who already have pets don't see onboarding again
    private func checkAndCompleteOnboardingIfNeeded(user: User) async -> User {
        guard !user.onboarded else {
            return user // User already completed onboarding
        }
        
        do {
            // Check if user has any pets
            let pets = try await apiService.getPets()
            
            if !pets.isEmpty {
                // User has pets but onboarded is false - auto-complete onboarding
                print("AuthService: User has \(pets.count) pet(s) but onboarded=false. Auto-completing onboarding.")
                
                let userUpdate = UserUpdate(
                    username: nil,
                    firstName: nil,
                    lastName: nil,
                    imageUrl: nil,
                    role: nil,
                    onboarded: true
                )
                
                // Update user to mark onboarding as complete
                let updatedUser = try await apiService.updateUser(userUpdate)
                print("AuthService: Onboarding auto-completed successfully")
                return updatedUser
            }
        } catch {
            // Silently fail - don't block login if this check fails
            print("AuthService: Failed to check pets for auto-onboarding: \(error)")
        }
        
        return user
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}
