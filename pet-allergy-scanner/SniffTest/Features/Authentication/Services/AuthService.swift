//
//  AuthService.swift
//  SniffTest
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
class AuthService: ObservableObject, @unchecked Sendable {
    static let shared = AuthService()
    
    @Published var authState: AuthState = .initializing
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private lazy var cacheHydrationService = CacheHydrationService.shared
    
    /// Convenience computed properties for backward compatibility
    var isAuthenticated: Bool { authState.isAuthenticated }
    var currentUser: User? { authState.user }
    var isLoading: Bool { authState.isLoading }
    
    private init() {
        // Attempt to restore existing auth token and user session
        // Token is persisted securely using Keychain inside APIService
        Task { @MainActor in
            if await apiService.hasAuthToken {
                await restoreUserSession()
            } else {
                // No token found, user is unauthenticated
                authState = .unauthenticated
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
        await MainActor.run {
            authState = .loading
        }
        
        // First, ensure token is valid by refreshing if needed
        await apiService.ensureValidToken()
        
        do {
            let user = try await apiService.getCurrentUser()
            
            // Auto-complete onboarding if user has pets but onboarded is false
            let finalUser = await checkAndCompleteOnboardingIfNeeded(user: user)
            
            // Hydrate all caches before transitioning to authenticated state
            await cacheHydrationService.hydrateAllCaches()
            
            // Only transition to authenticated once cache hydration is complete
            await MainActor.run {
                authState = .authenticated(finalUser)
            }
        } catch {
            // Failed to restore session, logout
            await logout()
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
        await MainActor.run {
            authState = .loading
            errorMessage = nil
        }
        
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
            await MainActor.run {
                authState = .unauthenticated
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Login user with email and password
    func login(email: String, password: String) async {
        await MainActor.run {
            authState = .loading
            errorMessage = nil
        }
        
        do {
            let authResponse = try await apiService.login(email: email, password: password)
            await handleAuthResponse(authResponse)
        } catch let apiError as APIError {
            await MainActor.run {
                authState = .unauthenticated
                // Handle email verification errors as informational messages, not errors
                if case .emailNotVerified(let message) = apiError {
                    errorMessage = message
                } else {
                    errorMessage = apiError.localizedDescription
                }
            }
        } catch {
            await MainActor.run {
                authState = .unauthenticated
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Reset password for user
    func resetPassword(email: String) async throws {
        try await apiService.resetPassword(email: email)
    }
    
    /// Logout current user
    /// Clears authentication state and all user-related data
    func logout() async {
        await apiService.clearAuthToken()
        await MainActor.run {
            authState = .unauthenticated
            errorMessage = nil
        }
        
        // Clear all caches
        cacheHydrationService.clearAllCaches()
    }
    
    /// Update current user profile
    func updateProfile(username: String?, firstName: String?, lastName: String?, imageUrl: String? = nil) async {
        guard case .authenticated(let currentUser) = authState else { return }
        
        await MainActor.run {
            authState = .loading
            errorMessage = nil
        }
        
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
            await MainActor.run {
                authState = .authenticated(user)
            }
        } catch {
            // Restore previous state on error
            await MainActor.run {
                authState = .authenticated(currentUser)
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Handle registration response
    private func handleRegistrationResponse(_ registrationResponse: RegistrationResponse) async {
        if let emailVerificationRequired = registrationResponse.emailVerificationRequired, emailVerificationRequired {
            // Email verification required - show message instead of error
            await MainActor.run {
                authState = .unauthenticated
                errorMessage = registrationResponse.message ?? "Please check your email and click the verification link to activate your account."
            }
        } else if let accessToken = registrationResponse.accessToken {
            // Email already verified - proceed with login flow
            await apiService.setAuthToken(
                accessToken,
                refreshToken: registrationResponse.refreshToken,
                expiresIn: registrationResponse.expiresIn
            )
            
            await MainActor.run {
                errorMessage = nil
            }
            
            // Fetch fresh user data from /me endpoint to get accurate onboarded status
            do {
                let freshUser = try await apiService.getCurrentUser()
                
                // Only run auto-onboarding check if user is not already onboarded
                let finalUser = if !freshUser.onboarded {
                    await checkAndCompleteOnboardingIfNeeded(user: freshUser)
                } else {
                    freshUser
                }
                
                // Hydrate all caches before transitioning to authenticated state
                await cacheHydrationService.hydrateAllCaches()
                
                // Only transition to authenticated once cache hydration is complete
                await MainActor.run {
                    authState = .authenticated(finalUser)
                }
            } catch {
                // Fallback to registration response user if getCurrentUser fails
                await MainActor.run {
                    if let user = registrationResponse.user {
                        authState = .authenticated(user)
                    } else {
                        authState = .unauthenticated
                        errorMessage = "Registration failed. Please try again."
                    }
                }
            }
        } else {
            // Fallback error
            await MainActor.run {
                authState = .unauthenticated
                errorMessage = "Registration failed. Please try again."
            }
        }
    }
    
    /// Handle authentication response
    private func handleAuthResponse(_ authResponse: AuthResponse) async {
        // Store the access token and refresh token in the API service for future requests
        await apiService.setAuthToken(
            authResponse.accessToken,
            refreshToken: authResponse.refreshToken,
            expiresIn: authResponse.expiresIn
        )
        
        await MainActor.run {
            errorMessage = nil
        }
        
        // Fetch fresh user data from /me endpoint to get accurate onboarded status
        // This prevents the flicker of showing onboarding screen for users who already completed it
        do {
            let freshUser = try await apiService.getCurrentUser()
            
            // Only run auto-onboarding check if user is not already onboarded
            let finalUser = if !freshUser.onboarded {
                await checkAndCompleteOnboardingIfNeeded(user: freshUser)
            } else {
                freshUser
            }
            
            // Hydrate all caches before transitioning to authenticated state
            await cacheHydrationService.hydrateAllCaches()
            
            // Only transition to authenticated once cache hydration is complete
            await MainActor.run {
                authState = .authenticated(finalUser)
            }
        } catch {
            // Fallback to auth response user if getCurrentUser fails
            // Still hydrate caches even on fallback
            await cacheHydrationService.hydrateAllCaches()
            
            await MainActor.run {
                authState = .authenticated(authResponse.user)
            }
        }
    }
    
    /// Handle email confirmation from URL redirect
    func handleEmailConfirmation(accessToken: String, refreshToken: String) {
        print("AuthService: Handling email confirmation")
        
        Task {
            // Store the tokens
            await apiService.setAuthToken(accessToken, refreshToken: refreshToken)
            
            await MainActor.run {
                authState = .loading
                errorMessage = nil
            }
            
            // Fetch user information
            do {
                let user = try await apiService.getCurrentUser()
                
                // Only run auto-onboarding check if user is not already onboarded
                let finalUser = if !user.onboarded {
                    await checkAndCompleteOnboardingIfNeeded(user: user)
                } else {
                    user
                }
                
                // Hydrate all caches before transitioning to authenticated state
                await cacheHydrationService.hydrateAllCaches()
                
                await MainActor.run {
                    authState = .authenticated(finalUser)
                }
                print("AuthService: Email confirmation successful")
            } catch {
                print("AuthService: Email confirmation failed - \(error)")
                await logout()
            }
        }
    }
    
    /// Handle password reset from URL redirect
    func handlePasswordReset(accessToken: String) {
        print("AuthService: Handling password reset")
        
        Task {
            // Store the token for password reset flow
            await apiService.setAuthToken(accessToken)
            
            await MainActor.run {
                authState = .loading
            }
            
            do {
                let user = try await apiService.getCurrentUser()
                
                // Hydrate all caches before transitioning to authenticated state
                await cacheHydrationService.hydrateAllCaches()
                
                await MainActor.run {
                    authState = .authenticated(user)
                }
                print("AuthService: Password reset token validated")
            } catch {
                print("AuthService: Password reset validation failed - \(error)")
                await logout()
            }
        }
    }
    
    /// Handle general auth callback
    func handleAuthCallback(accessToken: String) {
        print("AuthService: Handling auth callback")
        
        Task {
            await apiService.setAuthToken(accessToken)
            
            await MainActor.run {
                authState = .loading
                errorMessage = nil
            }
            
            // Fetch user information
            do {
                let user = try await apiService.getCurrentUser()
                
                // Only run auto-onboarding check if user is not already onboarded
                let finalUser = if !user.onboarded {
                    await checkAndCompleteOnboardingIfNeeded(user: user)
                } else {
                    user
                }
                
                // Hydrate all caches before transitioning to authenticated state
                await cacheHydrationService.hydrateAllCaches()
                
                await MainActor.run {
                    authState = .authenticated(finalUser)
                }
                
                print("AuthService: Auth callback successful")
            } catch {
                print("AuthService: Auth callback failed - \(error)")
                await logout()
            }
        }
    }
    
    /// Refresh current user data from server
    func refreshCurrentUser() async {
        guard case .authenticated = authState else { return }
        
        do {
            let user = try await apiService.getCurrentUser()
            await MainActor.run {
                authState = .authenticated(user)
            }
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
        Task { @MainActor in
            errorMessage = nil
        }
    }
}
