//
//  CachedAuthService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/// Enhanced authentication service with intelligent caching
/// Implements SOLID principles: Single responsibility for auth + caching
/// Implements DRY principle by extending AuthService functionality
@MainActor
class CachedAuthService: ObservableObject {
    static let shared = CachedAuthService()
    
    // MARK: - Properties
    
    @Published var authState: AuthState = .initializing
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    
    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private let authService = AuthService.shared
    
    /// Cache refresh timer for background updates
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        setupCacheRefreshTimer()
        observeAuthChanges()
    }
    
    // MARK: - Public Interface
    
    /// Convenience computed properties for backward compatibility
    var isAuthenticated: Bool { authState.isAuthenticated }
    var currentUser: User? { authState.user }
    var isLoading: Bool { authState.isLoading }
    
    /// Register a new user with cache management
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
    
    /// Login user with caching
    func login(email: String, password: String) async {
        authState = .loading
        errorMessage = nil
        
        do {
            let authResponse = try await apiService.login(email: email, password: password)
            await handleAuthResponse(authResponse)
        } catch let apiError as APIError {
            authState = .unauthenticated
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
    
    /// Logout current user with cache cleanup
    func logout() {
        // Clear all caches
        if let userId = currentUser?.id {
            cacheService.clearUserCache(userId: userId)
        }
        
        // Clear auth token
        apiService.clearAuthToken()
        authState = .unauthenticated
        errorMessage = nil
        
        // Clear all user data
        PetService.shared.clearPets()
        ScanService.shared.clearScans()
        
        // Stop refresh timer
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    /// Update current user profile with cache invalidation
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
            
            // Update cache
            await updateUserCache(user)
            
        } catch {
            // Restore previous state on error
            authState = .authenticated(currentUser)
            errorMessage = error.localizedDescription
        }
    }
    
    /// Refresh current user data with caching
    func refreshCurrentUser() async {
        guard case .authenticated = authState else { return }
        
        isRefreshing = true
        
        do {
            let user = try await apiService.getCurrentUser()
            authState = .authenticated(user)
            
            // Update cache
            await updateUserCache(user)
            
        } catch {
            print("Failed to refresh user data: \(error)")
        }
        
        isRefreshing = false
    }
    
    /// Handle email confirmation with caching
    func handleEmailConfirmation(accessToken: String, refreshToken: String) {
        print("CachedAuthService: Handling email confirmation")
        
        apiService.setAuthToken(accessToken)
        authState = .loading
        errorMessage = nil
        
        Task {
            do {
                var user = try await apiService.getCurrentUser()
                
                // Auto-complete onboarding if needed
                if !user.onboarded {
                    user = await checkAndCompleteOnboardingIfNeeded(user: user)
                }
                
                authState = .authenticated(user)
                
                // Update cache
                await updateUserCache(user)
                
                print("CachedAuthService: Email confirmation successful")
            } catch {
                print("CachedAuthService: Email confirmation failed - \(error)")
                logout()
            }
        }
    }
    
    /// Handle password reset with caching
    func handlePasswordReset(accessToken: String) {
        print("CachedAuthService: Handling password reset")
        
        apiService.setAuthToken(accessToken)
        authState = .loading
        
        Task {
            do {
                let user = try await apiService.getCurrentUser()
                authState = .authenticated(user)
                
                // Update cache
                await updateUserCache(user)
                
                print("CachedAuthService: Password reset token validated")
            } catch {
                print("CachedAuthService: Password reset validation failed - \(error)")
                logout()
            }
        }
    }
    
    /// Handle general auth callback with caching
    func handleAuthCallback(accessToken: String) {
        print("CachedAuthService: Handling auth callback")
        
        apiService.setAuthToken(accessToken)
        authState = .loading
        errorMessage = nil
        
        Task {
            do {
                var user = try await apiService.getCurrentUser()
                
                // Auto-complete onboarding if needed
                if !user.onboarded {
                    user = await checkAndCompleteOnboardingIfNeeded(user: user)
                }
                
                authState = .authenticated(user)
                
                // Update cache
                await updateUserCache(user)
                
                print("CachedAuthService: Auth callback successful")
            } catch {
                print("CachedAuthService: Auth callback failed - \(error)")
                logout()
            }
        }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// Handle registration response with caching
    private func handleRegistrationResponse(_ registrationResponse: RegistrationResponse) async {
        if let emailVerificationRequired = registrationResponse.emailVerificationRequired, emailVerificationRequired {
            authState = .unauthenticated
            errorMessage = registrationResponse.message ?? "Please check your email and click the verification link to activate your account."
        } else if let accessToken = registrationResponse.accessToken {
            apiService.setAuthToken(accessToken)
            errorMessage = nil
            
            do {
                var freshUser = try await apiService.getCurrentUser()
                
                if !freshUser.onboarded {
                    freshUser = await checkAndCompleteOnboardingIfNeeded(user: freshUser)
                }
                
                authState = .authenticated(freshUser)
                
                // Update cache
                await updateUserCache(freshUser)
                
            } catch {
                if let user = registrationResponse.user {
                    authState = .authenticated(user)
                    await updateUserCache(user)
                } else {
                    authState = .unauthenticated
                    errorMessage = "Registration failed. Please try again."
                }
            }
        } else {
            authState = .unauthenticated
            errorMessage = "Registration failed. Please try again."
        }
    }
    
    /// Handle authentication response with caching
    private func handleAuthResponse(_ authResponse: AuthResponse) async {
        apiService.setAuthToken(authResponse.accessToken)
        errorMessage = nil
        
        do {
            var freshUser = try await apiService.getCurrentUser()
            
            if !freshUser.onboarded {
                freshUser = await checkAndCompleteOnboardingIfNeeded(user: freshUser)
            }
            
            authState = .authenticated(freshUser)
            
            // Update cache
            await updateUserCache(freshUser)
            
        } catch {
            authState = .authenticated(authResponse.user)
            await updateUserCache(authResponse.user)
        }
    }
    
    /// Update user cache
    private func updateUserCache(_ user: User) async {
        // Cache current user
        cacheService.storeUserData(user, forKey: .currentUser, userId: user.id)
        
        // Cache user profile (subset of user data)
        let userProfile = UserProfile(
            id: user.id,
            email: user.email,
            username: user.username,
            firstName: user.firstName,
            lastName: user.lastName,
            imageUrl: user.imageUrl,
            role: user.role,
            onboarded: user.onboarded,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt
        )
        cacheService.storeUserData(userProfile, forKey: .userProfile, userId: user.id)
    }
    
    /// Check if user has pets and auto-complete onboarding if needed
    private func checkAndCompleteOnboardingIfNeeded(user: User) async -> User {
        guard !user.onboarded else { return user }
        
        do {
            let pets = try await apiService.getPets()
            
            if !pets.isEmpty {
                print("CachedAuthService: User has \(pets.count) pet(s) but onboarded=false. Auto-completing onboarding.")
                
                let userUpdate = UserUpdate(
                    username: nil,
                    firstName: nil,
                    lastName: nil,
                    imageUrl: nil,
                    role: nil,
                    onboarded: true
                )
                
                let updatedUser = try await apiService.updateUser(userUpdate)
                print("CachedAuthService: Onboarding auto-completed successfully")
                
                // Update cache
                await updateUserCache(updatedUser)
                
                return updatedUser
            }
        } catch {
            print("CachedAuthService: Failed to check pets for auto-onboarding: \(error)")
        }
        
        return user
    }
    
    /// Setup cache refresh timer
    private func setupCacheRefreshTimer() {
        // Refresh user cache every 30 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshCurrentUser()
            }
        }
    }
    
    /// Observe authentication changes
    private func observeAuthChanges() {
        // This would typically use Combine or NotificationCenter
        // For now, we'll handle it in the individual methods
    }
}

// MARK: - User Profile Model

/// Lightweight user profile model for caching
struct UserProfile: Codable {
    let id: String
    let email: String
    let username: String?
    let firstName: String?
    let lastName: String?
    let imageUrl: String?
    let role: UserRole
    let onboarded: Bool
    let createdAt: Date
    let updatedAt: Date
    
    /// Convert to full User model
    func toUser() -> User {
        return User(
            id: id,
            email: email,
            username: username,
            firstName: firstName,
            lastName: lastName,
            imageUrl: imageUrl,
            role: role,
            onboarded: onboarded,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Cache Analytics Extension

extension CachedAuthService {
    /// Get cache statistics for authentication
    func getCacheStats() -> [String: Any] {
        var stats = cacheService.getCacheStats()
        
        // Add auth-specific stats
        stats["is_authenticated"] = isAuthenticated
        stats["is_loading"] = isLoading
        stats["is_refreshing"] = isRefreshing
        stats["has_error"] = errorMessage != nil
        stats["user_id"] = currentUser?.id
        
        return stats
    }
}
