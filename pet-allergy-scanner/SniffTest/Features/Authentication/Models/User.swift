//
//  User.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// User data model representing the authenticated user
struct User: Codable, Identifiable, Equatable {
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case imageUrl = "image_url"
        case role
        case onboarded
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Memberwise initializer for direct instantiation (e.g., mock data)
    /// - Parameters:
    ///   - id: Unique user identifier
    ///   - email: User's email address
    ///   - username: Optional username
    ///   - firstName: Optional first name
    ///   - lastName: Optional last name
    ///   - imageUrl: Optional profile image URL
    ///   - role: User role (free or premium)
    ///   - onboarded: Whether user has completed onboarding
    ///   - createdAt: Account creation timestamp
    ///   - updatedAt: Last update timestamp
    init(
        id: String,
        email: String,
        username: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        imageUrl: String? = nil,
        role: UserRole,
        onboarded: Bool = false,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.email = email
        self.username = username
        self.firstName = firstName
        self.lastName = lastName
        self.imageUrl = imageUrl
        self.role = role
        self.onboarded = onboarded
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Custom decoder initializer to handle potential missing fields from server
    /// - Parameter decoder: Decoder instance
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        role = try container.decode(UserRole.self, forKey: .role)
        onboarded = try container.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    /// Debug description for logging
    var description: String {
        return "User(id: \(id), email: \(email), username: \(username ?? "nil"), firstName: \(firstName ?? "nil"), lastName: \(lastName ?? "nil"), imageUrl: \(imageUrl ?? "nil"), role: \(role), onboarded: \(onboarded))"
    }
}

/// User role enumeration
enum UserRole: String, Codable, CaseIterable {
    case free = "free"
    case premium = "premium"
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .premium:
            return "Premium"
        }
    }
}

/// User creation model for registration
struct UserCreate: Codable {
    let email: String
    let password: String
    let username: String?
    let firstName: String?
    let lastName: String?
    let role: UserRole
    let onboarded: Bool
    
    enum CodingKeys: String, CodingKey {
        case email
        case password
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case role
        case onboarded
    }
}

/// User update model for profile updates
struct UserUpdate: Codable {
    let username: String?
    let firstName: String?
    let lastName: String?
    let imageUrl: String?
    let role: UserRole?
    let onboarded: Bool?
    
    enum CodingKeys: String, CodingKey {
        case username
        case firstName = "first_name"
        case lastName = "last_name"
        case imageUrl = "image_url"
        case role
        case onboarded
    }
}

/// Authentication response model
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: Int?
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}

/// Registration response model for email verification scenarios
struct RegistrationResponse: Codable {
    let message: String?
    let emailVerificationRequired: Bool?
    let accessToken: String?
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Int?
    let user: User?
    
    enum CodingKeys: String, CodingKey {
        case message
        case emailVerificationRequired = "email_verification_required"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case user
    }
}
