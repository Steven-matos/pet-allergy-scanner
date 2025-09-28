//
//  GDPRModels.swift
//  pet-allergy-scanner
//
//  Created by Code Assistant, 2025.
//

import Foundation

/// Data retention information model
struct DataRetentionInfo: Codable {
    let retentionDays: Int
    let dataTypes: [String]
    let lastUpdated: Date
    let policyVersion: String
    
    enum CodingKeys: String, CodingKey {
        case retentionDays = "retention_days"
        case dataTypes = "data_types"
        case lastUpdated = "last_updated"
        case policyVersion = "policy_version"
    }
}

/// Data subject rights information
struct DataSubjectRights: Codable {
    let rights: [DataRight]
    let contactEmail: String
    let responseTime: String
    
    enum CodingKeys: String, CodingKey {
        case rights
        case contactEmail = "contact_email"
        case responseTime = "response_time"
    }
}

/// Individual data right
struct DataRight: Codable {
    let name: String
    let description: String
    let isAvailable: Bool
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case isAvailable = "is_available"
    }
}

/// GDPR consent model
struct GDPRConsent: Codable {
    let consentId: String
    let consentType: String
    let granted: Bool
    let grantedAt: Date
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case consentId = "consent_id"
        case consentType = "consent_type"
        case granted
        case grantedAt = "granted_at"
        case expiresAt = "expires_at"
    }
}

/// Data processing purpose
struct DataProcessingPurpose: Codable {
    let purpose: String
    let description: String
    let legalBasis: String
    let isRequired: Bool
    
    enum CodingKeys: String, CodingKey {
        case purpose
        case description
        case legalBasis = "legal_basis"
        case isRequired = "is_required"
    }
}
