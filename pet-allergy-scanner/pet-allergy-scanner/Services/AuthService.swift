//
//  AuthService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Observation

/// Authentication service for managing user authentication state using Swift Concurrency
@Observable
@MainActor
class AuthService {
    static let shared = AuthService()
    
    var isAuthenticated = false
    var currentUser: User?
    var isLoading = false
    var errorMessage: String?
    
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
        firstName: String? = nil,
        lastName: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        
        let userCreate = UserCreate(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            role: .free
        )
        
        do {
            let authResponse = try await apiService.register(user: userCreate)
            handleAuthResponse(authResponse)
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
    func updateProfile(firstName: String?, lastName: String?) async {
        guard isAuthenticated else { return }
        
        isLoading = true
        errorMessage = nil
        
        let userUpdate = UserUpdate(
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
    
    /// Handle authentication response
    private func handleAuthResponse(_ authResponse: AuthResponse) {
        // Token is persisted securely using Keychain inside APIService
        isAuthenticated = true
        currentUser = authResponse.user
        errorMessage = nil
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}
