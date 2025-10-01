//
//  UserModelTests.swift
//  pet-allergy-scannerTests
//
//  Created by Steven Matos on 9/26/25.
//

import Testing
import Foundation
@testable import pet_allergy_scanner

/// Unit tests for User model and related types
@Suite("User Model Tests")
struct UserModelTests {
    
    /// Test User model creation
    @Test("User model creation")
    func testUserModelCreation() {
        let user = User(
            id: "user123",
            email: "test@example.com",
            firstName: "John",
            lastName: "Doe",
            role: .premium,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        #expect(user.id == "user123")
        #expect(user.email == "test@example.com")
        #expect(user.firstName == "John")
        #expect(user.lastName == "Doe")
        #expect(user.role == .premium)
    }
    
    /// Test UserCreate model validation
    @Test("UserCreate model validation")
    func testUserCreateValidation() {
        let validUserCreate = UserCreate(
            email: "test@example.com",
            password: "securePassword123",
            firstName: "John",
            lastName: "Doe",
            role: .free
        )
        
        #expect(validUserCreate.email == "test@example.com")
        #expect(validUserCreate.password == "securePassword123")
        #expect(validUserCreate.firstName == "John")
        #expect(validUserCreate.lastName == "Doe")
        #expect(validUserCreate.role == .free)
    }
    
    /// Test UserUpdate model
    @Test("UserUpdate model")
    func testUserUpdateModel() {
        let userUpdate = UserUpdate(
            username: nil,
            firstName: "Jane",
            lastName: "Smith",
            imageUrl: nil,
            role: .premium,
            onboarded: nil
        )
        
        #expect(userUpdate.firstName == "Jane")
        #expect(userUpdate.lastName == "Smith")
        #expect(userUpdate.role == .premium)
    }
    
    /// Test UserRole enum
    @Test("UserRole enum")
    func testUserRoleEnum() {
        #expect(UserRole.free.rawValue == "free")
        #expect(UserRole.premium.rawValue == "premium")
        #expect(UserRole.admin.rawValue == "admin")
        
        #expect(UserRole.allCases.count == 3)
        #expect(UserRole.allCases.contains(.free))
        #expect(UserRole.allCases.contains(.premium))
        #expect(UserRole.allCases.contains(.admin))
    }
    
    /// Test AuthResponse model
    @Test("AuthResponse model")
    func testAuthResponseModel() {
        let user = User(
            id: "user123",
            email: "test@example.com",
            firstName: "John",
            lastName: "Doe",
            role: .free,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let authResponse = AuthResponse(
            user: user,
            token: "jwt-token-123"
        )
        
        #expect(authResponse.user.id == "user123")
        #expect(authResponse.token == "jwt-token-123")
    }
    
    /// Test User model JSON encoding/decoding
    @Test("User model JSON encoding/decoding")
    func testUserJSONEncodingDecoding() throws {
        let originalUser = User(
            id: "user123",
            email: "test@example.com",
            firstName: "John",
            lastName: "Doe",
            role: .premium,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalUser)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedUser = try decoder.decode(User.self, from: data)
        
        #expect(decodedUser.id == originalUser.id)
        #expect(decodedUser.email == originalUser.email)
        #expect(decodedUser.firstName == originalUser.firstName)
        #expect(decodedUser.lastName == originalUser.lastName)
        #expect(decodedUser.role == originalUser.role)
    }
    
    /// Test UserCreate model JSON encoding
    @Test("UserCreate model JSON encoding")
    func testUserCreateJSONEncoding() throws {
        let userCreate = UserCreate(
            email: "test@example.com",
            password: "securePassword123",
            firstName: "John",
            lastName: "Doe",
            role: .free
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(userCreate)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        #expect(json["email"] as? String == "test@example.com")
        #expect(json["password"] as? String == "securePassword123")
        #expect(json["first_name"] as? String == "John")
        #expect(json["last_name"] as? String == "Doe")
        #expect(json["role"] as? String == "free")
    }
    
    /// Test UserUpdate model JSON encoding
    @Test("UserUpdate model JSON encoding")
    func testUserUpdateJSONEncoding() throws {
        let userUpdate = UserUpdate(
            username: nil,
            firstName: "Jane",
            lastName: "Smith",
            imageUrl: nil,
            role: .premium,
            onboarded: nil
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(userUpdate)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        #expect(json["first_name"] as? String == "Jane")
        #expect(json["last_name"] as? String == "Smith")
        #expect(json["role"] as? String == "premium")
    }
}
