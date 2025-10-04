//
//  AuthServiceTests.swift
//  SniffTestTests
//
//  Created by Steven Matos on 9/26/25.
//

import Testing
import Foundation
@testable import pet_allergy_scanner

/// Unit tests for AuthService functionality
@Suite("Auth Service Tests")
struct AuthServiceTests {
    
    /// Test AuthService singleton
    @Test("AuthService singleton")
    func testAuthServiceSingleton() {
        let service1 = AuthService.shared
        let service2 = AuthService.shared
        
        #expect(service1 === service2)
    }
    
    /// Test initial authentication state
    @Test("Initial authentication state")
    func testInitialAuthenticationState() {
        let service = AuthService.shared
        
        // Initially not authenticated
        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
        #expect(service.isLoading == false)
        #expect(service.errorMessage == nil)
    }
    
    /// Test logout functionality
    @Test("Logout functionality")
    func testLogout() {
        let service = AuthService.shared
        
        // Set some initial state
        service.isAuthenticated = true
        service.currentUser = User(
            id: "test-user",
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            role: .free,
            createdAt: Date(),
            updatedAt: Date()
        )
        service.errorMessage = "Some error"
        
        // Logout should clear all state
        service.logout()
        
        #expect(service.isAuthenticated == false)
        #expect(service.currentUser == nil)
        #expect(service.errorMessage == nil)
    }
    
    /// Test error message clearing
    @Test("Error message clearing")
    func testClearError() {
        let service = AuthService.shared
        
        // Set an error message
        service.errorMessage = "Test error"
        #expect(service.errorMessage == "Test error")
        
        // Clear error
        service.clearError()
        #expect(service.errorMessage == nil)
    }
    
    /// Test user registration with invalid data
    @Test("User registration with invalid data")
    func testUserRegistrationInvalidData() async {
        let service = AuthService.shared
        
        // Test with empty email
        await service.register(
            email: "",
            password: "password123",
            firstName: "Test",
            lastName: "User"
        )
        
        // Should have error message
        #expect(service.errorMessage != nil)
        #expect(service.isAuthenticated == false)
    }
    
    /// Test user login with invalid credentials
    @Test("User login with invalid credentials")
    func testUserLoginInvalidCredentials() async {
        let service = AuthService.shared
        
        // Test with invalid credentials
        await service.login(email: "invalid@example.com", password: "wrongpassword")
        
        // Should have error message and not be authenticated
        #expect(service.errorMessage != nil)
        #expect(service.isAuthenticated == false)
    }
    
    /// Test profile update when not authenticated
    @Test("Profile update when not authenticated")
    func testProfileUpdateNotAuthenticated() async {
        let service = AuthService.shared
        
        // Ensure not authenticated
        service.logout()
        
        // Try to update profile
        await service.updateProfile(firstName: "New", lastName: "Name")
        
        // Should not change anything
        #expect(service.currentUser == nil)
        #expect(service.isAuthenticated == false)
    }
}

/// Mock AuthService for testing purposes
class MockAuthService: AuthService {
    static let mockInstance = MockAuthService()
    
    private override init() {
        super.init()
    }
    
    override func register(email: String, password: String, firstName: String? = nil, lastName: String? = nil) async {
        // Mock successful registration
        self.isAuthenticated = true
        self.currentUser = User(
            id: "mock-user",
            email: email,
            firstName: firstName,
            lastName: lastName,
            role: .free,
            createdAt: Date(),
            updatedAt: Date()
        )
        self.isLoading = false
        self.errorMessage = nil
    }
    
    override func login(email: String, password: String) async {
        // Mock successful login
        self.isAuthenticated = true
        self.currentUser = User(
            id: "mock-user",
            email: email,
            firstName: "Mock",
            lastName: "User",
            role: .free,
            createdAt: Date(),
            updatedAt: Date()
        )
        self.isLoading = false
        self.errorMessage = nil
    }
}
