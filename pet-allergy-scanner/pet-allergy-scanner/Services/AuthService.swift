//
//  AuthService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/// Authentication service for managing user authentication state
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Check for existing authentication on app launch
        checkAuthenticationStatus()
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
    ) {
        isLoading = true
        errorMessage = nil
        
        let userCreate = UserCreate(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            role: .free
        )
        
        apiService.register(user: userCreate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] authResponse in
                    self?.handleAuthResponse(authResponse)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Login user with email and password
    func login(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        
        apiService.login(email: email, password: password)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] authResponse in
                    self?.handleAuthResponse(authResponse)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Logout current user
    func logout() {
        apiService.clearAuthToken()
        isAuthenticated = false
        currentUser = nil
        errorMessage = nil
    }
    
    /// Update current user profile
    func updateProfile(firstName: String?, lastName: String?) {
        guard isAuthenticated else { return }
        
        isLoading = true
        errorMessage = nil
        
        let userUpdate = UserUpdate(
            firstName: firstName,
            lastName: lastName,
            role: nil
        )
        
        apiService.updateUser(userUpdate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] user in
                    self?.currentUser = user
                }
            )
            .store(in: &cancellables)
    }
    
    /// Handle authentication response
    private func handleAuthResponse(_ authResponse: AuthResponse) {
        apiService.setAuthToken(authResponse.accessToken)
        isAuthenticated = true
        currentUser = authResponse.user
        errorMessage = nil
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}
