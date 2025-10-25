//
//  CachedProfileService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/**
 * Cached Profile Service
 * 
 * Provides intelligent caching for user profile data to reduce server calls.
 * Implements cache-first strategy with background refresh and smart invalidation.
 * 
 * Follows SOLID principles with single responsibility for profile caching
 * Implements DRY by reusing existing cache infrastructure
 * Follows KISS by keeping the caching logic simple and reliable
 */
@MainActor
class CachedProfileService: ObservableObject {
    static let shared = CachedProfileService()
    
    @Published var currentUser: User?
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    private let authService = AuthService.shared
    private var currentUserId: String? { authService.currentUser?.id }
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // Observe authentication state changes
        authService.$authState
            .sink { [weak self] authState in
                Task { @MainActor in
                    await self?.handleAuthStateChange(authState)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public API
    
    /**
     * Get current user with cache-first approach
     * - Returns: Current user from cache or server
     */
    func getCurrentUser(forceRefresh: Bool = false) async throws -> User {
        // Try cache first
        if !forceRefresh, let userId = currentUserId {
            let cacheKey = CacheKey.currentUser.scoped(forUserId: userId)
            if let cached = cacheService.retrieve(User.self, forKey: cacheKey) {
                currentUser = cached
                return cached
            }
        }
        
        // Fallback to server
        let user = try await apiService.getCurrentUser()
        
        // Cache the result
        let userId = user.id
        let cacheKey = CacheKey.currentUser.scoped(forUserId: userId)
        cacheService.store(user, forKey: cacheKey)
        
        currentUser = user
        return user
    }
    
    /**
     * Get user profile with cache-first approach
     * - Returns: User profile from cache or server
     */
    func getUserProfile(forceRefresh: Bool = false) async throws -> UserProfile {
        // Try cache first
        if !forceRefresh, let userId = currentUserId {
            let cacheKey = CacheKey.userProfile.scoped(forUserId: userId)
            if let cached = cacheService.retrieve(UserProfile.self, forKey: cacheKey) {
                userProfile = cached
                return cached
            }
        }
        
        // Fallback to server
        let user = try await apiService.getCurrentUser()
        let profile = UserProfile(
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
        
        // Cache the result
        let userId = user.id
        let cacheKey = CacheKey.userProfile.scoped(forUserId: userId)
        cacheService.store(profile, forKey: cacheKey)
        
        userProfile = profile
        return profile
    }
    
    /**
     * Update user profile with cache invalidation
     * - Parameter userUpdate: The user update data
     * - Returns: Updated user
     */
    func updateProfile(_ userUpdate: UserUpdate) async throws -> User {
        isLoading = true
        error = nil
        
        do {
            let updatedUser = try await apiService.updateUser(userUpdate)
            
            // Update cache
            let userId = updatedUser.id
            let userCacheKey = CacheKey.currentUser.scoped(forUserId: userId)
            cacheService.store(updatedUser, forKey: userCacheKey)
            
            // Update profile cache
            let profile = UserProfile(
                id: updatedUser.id,
                email: updatedUser.email,
                username: updatedUser.username,
                firstName: updatedUser.firstName,
                lastName: updatedUser.lastName,
                imageUrl: updatedUser.imageUrl,
                role: updatedUser.role,
                onboarded: updatedUser.onboarded,
                createdAt: updatedUser.createdAt,
                updatedAt: updatedUser.updatedAt
            )
            let profileCacheKey = CacheKey.userProfile.scoped(forUserId: userId)
            cacheService.store(profile, forKey: profileCacheKey)
            
            currentUser = updatedUser
            userProfile = UserProfile(
                id: updatedUser.id,
                email: updatedUser.email,
                username: updatedUser.username,
                firstName: updatedUser.firstName,
                lastName: updatedUser.lastName,
                imageUrl: updatedUser.imageUrl,
                role: updatedUser.role,
                onboarded: updatedUser.onboarded,
                createdAt: updatedUser.createdAt,
                updatedAt: updatedUser.updatedAt
            )
            
            isLoading = false
            return updatedUser
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    /**
     * Refresh user data in background
     * - Parameter userId: The user's ID
     */
    func refreshUserDataInBackground(for userId: String) async {
        do {
            let user = try await apiService.getCurrentUser()
            
            // Update if different from current
            if user != currentUser {
                await MainActor.run {
                    currentUser = user
                    
                    // Update profile
                    let profile = UserProfile(
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
                    userProfile = profile
                    
                    // Cache the updated data
                    let userCacheKey = CacheKey.currentUser.scoped(forUserId: userId)
                    let profileCacheKey = CacheKey.userProfile.scoped(forUserId: userId)
                    cacheService.store(user, forKey: userCacheKey)
                    cacheService.store(profile, forKey: profileCacheKey)
                }
            }
        } catch {
            // Silent failure for background refresh
            print("⚠️ Background user data refresh failed: \(error.localizedDescription)")
        }
    }
    
    /**
     * Check if we have cached user data
     * - Parameter userId: The user's ID
     * - Returns: True if we have cached user data
     */
    func hasCachedUserData(for userId: String) -> Bool {
        let hasUser = currentUser != nil
        let hasProfile = userProfile != nil
        return hasUser || hasProfile
    }
    
    /**
     * Clear user cache
     * Called on logout
     */
    func clearCache() {
        currentUser = nil
        userProfile = nil
        error = nil
    }
    
    // MARK: - Private Methods
    
    /**
     * Handle authentication state changes
     * - Parameter authState: Current authentication state
     */
    private func handleAuthStateChange(_ authState: AuthState) async {
        switch authState {
        case .authenticated(let user):
            // User signed in, load profile data
            currentUser = user
            await loadUserProfileData()
        case .unauthenticated:
            // User signed out, clear cache
            clearCache()
        case .loading, .initializing:
            // Still loading, do nothing
            break
        }
    }
    
    /**
     * Load user profile data with cache-first approach
     */
    private func loadUserProfileData() async {
        guard let userId = currentUserId else { return }
        
        // Check if we have cached data
        if hasCachedUserData(for: userId) {
            print("✅ Using cached user profile data")
            return
        }
        
        // Load from server if no cache
        do {
            _ = try await getCurrentUser()
            _ = try await getUserProfile()
        } catch {
            print("⚠️ Failed to load user profile data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Extensions for Service Integration

extension CachedProfileService {
    /**
     * Check if we have cached profile data for a user
     * - Parameter userId: The user's ID
     * - Returns: True if we have any cached profile data
     */
    func hasCachedProfileData(for userId: String) -> Bool {
        let hasUser = currentUser != nil
        let hasProfile = userProfile != nil
        return hasUser || hasProfile
    }
}
