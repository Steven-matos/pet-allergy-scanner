//
//  MFAModels.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation

/// MFA setup response model
struct MFASetupResponse: Codable {
    let mfaSecret: String
    let qrCodeImage: String
    let provisioningUri: String
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case mfaSecret = "mfa_secret"
        case qrCodeImage = "qr_code_image"
        case provisioningUri = "provisioning_uri"
        case message
    }
}

/// MFA status model
struct MFAStatus: Codable {
    let isEnabled: Bool
    let hasBackupCodes: Bool
    let lastUsed: Date?
    
    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case hasBackupCodes = "has_backup_codes"
        case lastUsed = "last_used"
    }
}

/// MFA verification request
struct MFAVerificationRequest: Codable {
    let token: String
    let backupCode: String?
    
    enum CodingKeys: String, CodingKey {
        case token
        case backupCode = "backup_code"
    }
}

/// MFA backup codes response
struct MFABackupCodesResponse: Codable {
    let backupCodes: [String]
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case backupCodes = "backup_codes"
        case message
    }
}
