//
//  AuthService+SessionRecovery.swift
//  SniffTest
//
//  Created by GPT-5.1 Codex on 11/17/25.
//

import Foundation

/// Session recovery helpers extracted from `AuthService` to keep the core file manageable.
@MainActor
extension AuthService {
    private static let lastAuthenticatedUserDefaultsKey = "com.snifftest.auth.last_user_id"
    
    /// Store the authenticated user in cache and persist the identifier for offline usage.
    /// - Parameter user: The authenticated user to cache.
    func cacheAuthenticatedUser(_ user: User) {
        CacheService.shared.storeUserData(user, forKey: .currentUser, userId: user.id)
        
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
        CacheService.shared.storeUserData(userProfile, forKey: .userProfile, userId: user.id)
        persistAuthenticatedUserId(user.id)
    }
    
    /// Handle failures that occur while restoring a persisted session.
    /// - Parameter error: The error thrown during session restoration.
    func handleSessionRestorationFailure(_ error: Error) async {
        if Self.shouldInvalidateSession(for: error) {
            print("AuthService: Session invalidated during restore: \(error)")
            await logout()
            return
        }
        
        guard let cachedUser = loadCachedUser() else {
            print("AuthService: Unable to load cached user after restore failure: \(error)")
            await MainActor.run {
                authState = .unauthenticated
                errorMessage = "Unable to confirm your session. Check your connection and try again."
            }
            return
        }
        
        print("AuthService: Falling back to cached session due to connectivity issue: \(error.localizedDescription)")
        cacheAuthenticatedUser(cachedUser)
        
        await MainActor.run {
            authState = .authenticated(cachedUser)
            errorMessage = "You appear to be offline. Showing the most recent data."
        }
    }
    
    /// Determine whether the session should be invalidated for the supplied error.
    /// - Parameter error: The error encountered while refreshing the session.
    /// - Returns: True when the error indicates an invalid or revoked token.
    nonisolated static func shouldInvalidateSession(for error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        
        switch apiError {
        case .authenticationError:
            return true
        case .serverMessage(let message):
            let lowercased = message.lowercased()
            return lowercased.contains("token") ||
                lowercased.contains("credential") ||
                lowercased.contains("expired")
        case .emailVerificationRequired,
             .emailNotVerified:
            return true
        default:
            return false
        }
    }
    
    /// Remove the stored identifier for the last authenticated user.
    func clearPersistedUserId() {
        UserDefaults.standard.removeObject(forKey: Self.lastAuthenticatedUserDefaultsKey)
    }
    
    /// Persist the identifier of the authenticated user for later retrieval.
    /// - Parameter userId: The identifier to persist.
    private func persistAuthenticatedUserId(_ userId: String) {
        UserDefaults.standard.set(userId, forKey: Self.lastAuthenticatedUserDefaultsKey)
    }
    
    /// Load the cached user associated with the last persisted identifier.
    /// - Returns: Cached `User` data if available.
    private func loadCachedUser() -> User? {
        guard let userId = UserDefaults.standard.string(forKey: Self.lastAuthenticatedUserDefaultsKey) else {
            return nil
        }
        return CacheService.shared.retrieveUserData(User.self, forKey: .currentUser, userId: userId)
    }
}
