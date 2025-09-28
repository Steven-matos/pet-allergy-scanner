//
//  User.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// User data model representing the authenticated user
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let role: UserRole
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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
    let firstName: String?
    let lastName: String?
    let role: UserRole
    
    enum CodingKeys: String, CodingKey {
        case email
        case password
        case firstName = "first_name"
        case lastName = "last_name"
        case role
    }
}

/// User update model for profile updates
struct UserUpdate: Codable {
    let firstName: String?
    let lastName: String?
    let role: UserRole?
    
    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
        case role
    }
}

/// Authentication response model
struct AuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case user
    }
}

/// Registration response model for email verification scenarios
struct RegistrationResponse: Codable {
    let message: String?
    let emailVerificationRequired: Bool?
    let accessToken: String?
    let tokenType: String?
    let user: User?
    
    enum CodingKeys: String, CodingKey {
        case message
        case emailVerificationRequired = "email_verification_required"
        case accessToken = "access_token"
        case tokenType = "token_type"
        case user
    }
}
