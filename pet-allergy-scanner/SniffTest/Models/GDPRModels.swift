//
//  GDPRModels.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation

/// Data retention information model
struct DataRetentionInfo: Codable {
    let userId: String
    let createdAt: Date
    let retentionDays: Int
    let retentionDate: Date
    let shouldDelete: Bool
    let daysUntilDeletion: Int
    let legalBasis: String
    let purpose: String
    let dataCategories: [String]
    let dataTypes: [String]
    let lastUpdated: Date
    let policyVersion: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case createdAt = "created_at"
        case retentionDays = "retention_days"
        case retentionDate = "retention_date"
        case shouldDelete = "should_delete"
        case daysUntilDeletion = "days_until_deletion"
        case legalBasis = "legal_basis"
        case purpose
        case dataCategories = "data_categories"
        case dataTypes = "data_types"
        case lastUpdated = "last_updated"
        case policyVersion = "policy_version"
    }
}

/// Data subject rights information
struct DataSubjectRights: Codable {
    let dataSubjectRights: DataRights
    let dataController: DataController
    let dataRetention: DataRetention
    let contactInformation: ContactInformation
    
    enum CodingKeys: String, CodingKey {
        case dataSubjectRights = "data_subject_rights"
        case dataController = "data_controller"
        case dataRetention = "data_retention"
        case contactInformation = "contact_information"
    }
}

/// Data rights container
struct DataRights: Codable {
    let rightOfAccess: DataRight
    let rightToRectification: DataRight
    let rightToErasure: DataRight
    let rightToRestrictProcessing: DataRight
    let rightToDataPortability: DataRight
    let rightToObject: DataRight
    
    enum CodingKeys: String, CodingKey {
        case rightOfAccess = "right_of_access"
        case rightToRectification = "right_to_rectification"
        case rightToErasure = "right_to_erasure"
        case rightToRestrictProcessing = "right_to_restrict_processing"
        case rightToDataPortability = "right_to_data_portability"
        case rightToObject = "right_to_object"
    }
    
    /// Convert to array for easy iteration
    var rights: [DataRight] {
        return [
            rightOfAccess,
            rightToRectification,
            rightToErasure,
            rightToRestrictProcessing,
            rightToDataPortability,
            rightToObject
        ]
    }
}

/// Data controller information
struct DataController: Codable {
    let name: String
    let contact: String
    let legalBasis: String
    let purpose: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case contact
        case legalBasis = "legal_basis"
        case purpose
    }
}

/// Data retention information
struct DataRetention: Codable {
    let period: String
    let criteria: String
}

/// Contact information
struct ContactInformation: Codable {
    let dataProtectionOfficer: String
    let privacyPolicy: String
    let termsOfService: String
    
    enum CodingKeys: String, CodingKey {
        case dataProtectionOfficer = "data_protection_officer"
        case privacyPolicy = "privacy_policy"
        case termsOfService = "terms_of_service"
    }
}

/// Individual data right
struct DataRight: Codable {
    let article: String
    let description: String
    let howToExercise: String
    
    enum CodingKeys: String, CodingKey {
        case article
        case description
        case howToExercise = "how_to_exercise"
    }
    
    /// Computed property for display name
    var name: String {
        switch article {
        case "GDPR Article 15":
            return "Right of Access"
        case "GDPR Article 16":
            return "Right to Rectification"
        case "GDPR Article 17":
            return "Right to Erasure"
        case "GDPR Article 18":
            return "Right to Restrict Processing"
        case "GDPR Article 20":
            return "Right to Data Portability"
        case "GDPR Article 21":
            return "Right to Object"
        default:
            return "Data Right"
        }
    }
    
    /// All rights are available in our implementation
    var isAvailable: Bool {
        return true
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
