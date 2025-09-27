//
//  APIServiceTests.swift
//  pet-allergy-scannerTests
//
//  Created by Steven Matos on 9/26/25.
//

import Testing
import Foundation
@testable import pet_allergy_scanner

/// Unit tests for APIService functionality
@Suite("API Service Tests")
struct APIServiceTests {
    
    /// Test APIService singleton
    @Test("APIService singleton")
    func testAPIServiceSingleton() {
        let service1 = APIService.shared
        let service2 = APIService.shared
        
        #expect(service1 === service2)
    }
    
    /// Test authentication token management
    @Test("Authentication token management")
    func testAuthTokenManagement() {
        let service = APIService.shared
        
        // Initially no token
        #expect(service.hasAuthToken == false)
        
        // Set token
        service.setAuthToken("test-token-123")
        #expect(service.hasAuthToken == true)
        
        // Clear token
        service.clearAuthToken()
        #expect(service.hasAuthToken == false)
    }
    
    /// Test URL request creation
    @Test("URL request creation")
    func testURLRequestCreation() {
        let service = APIService.shared
        let url = URL(string: "https://api.example.com/test")!
        
        // Test GET request without auth
        let getRequest = service.createRequest(url: url, method: "GET")
        #expect(getRequest.httpMethod == "GET")
        #expect(getRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(getRequest.value(forHTTPHeaderField: "Authorization") == nil)
        
        // Set auth token and test request with auth
        service.setAuthToken("test-token")
        let authRequest = service.createRequest(url: url, method: "POST")
        #expect(authRequest.httpMethod == "POST")
        #expect(authRequest.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        
        // Clean up
        service.clearAuthToken()
    }
    
    /// Test URL request with body
    @Test("URL request with body")
    func testURLRequestWithBody() {
        let service = APIService.shared
        let url = URL(string: "https://api.example.com/test")!
        let bodyData = "test data".data(using: .utf8)!
        
        let request = service.createRequest(url: url, method: "POST", body: bodyData)
        #expect(request.httpMethod == "POST")
        #expect(request.httpBody == bodyData)
    }
    
    /// Test base URL configuration
    @Test("Base URL configuration")
    func testBaseURLConfiguration() {
        let service = APIService.shared
        
        // The base URL should be set (either from Bundle or default)
        // We can't easily test the exact value without mocking Bundle,
        // but we can verify the service is properly configured
        #expect(service.baseURL.contains("api/v1"))
    }
}

/// Mock APIService for testing purposes
class MockAPIService: APIService {
    static let mockInstance = MockAPIService()
    
    private override init() {
        super.init()
    }
    
    override var baseURL: String {
        return "https://mock-api.example.com/api/v1"
    }
    
    override func createRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        return super.createRequest(url: url, method: method, body: body)
    }
}

/// Integration tests for APIService (requires network)
@Suite("API Service Integration Tests")
struct APIServiceIntegrationTests {
    
    /// Test network request error handling
    @Test("Network request error handling")
    func testNetworkRequestErrorHandling() async throws {
        let service = APIService.shared
        
        // Test with invalid URL
        do {
            let _ = try await service.getCurrentUser()
            #expect(Bool(false), "Should have thrown an error")
        } catch APIError.invalidURL {
            // Expected error
        } catch {
            #expect(Bool(false), "Unexpected error type: \(error)")
        }
    }
    
    /// Test authentication flow
    @Test("Authentication flow")
    func testAuthenticationFlow() async throws {
        let service = APIService.shared
        
        // Test login with invalid credentials
        do {
            let _ = try await service.login(email: "invalid@example.com", password: "wrongpassword")
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            // Expected to fail with network error or authentication error
            #expect(error is APIError)
        }
    }
}
