//
//  InputValidator.swift
//  pet-allergy-scanner
//
//  Created by Code Assistant, 2025.
//

import Foundation

/// Input validation utility for secure user input handling
struct InputValidator {
    
    /// Validate email format
    /// - Parameter email: Email string to validate
    /// - Returns: True if email is valid
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// Validate password strength
    /// - Parameter password: Password string to validate
    /// - Returns: Password validation result
    static func validatePassword(_ password: String) -> PasswordValidationResult {
        var issues: [String] = []
        
        if password.count < 8 {
            issues.append("Password must be at least 8 characters long")
        }
        
        if password.count > 64 {
            issues.append("Password must be less than 64 characters")
        }
        
        if !password.contains(where: { $0.isUppercase }) {
            issues.append("Password must contain at least one uppercase letter")
        }
        
        if !password.contains(where: { $0.isLowercase }) {
            issues.append("Password must contain at least one lowercase letter")
        }
        
        if !password.contains(where: { $0.isNumber }) {
            issues.append("Password must contain at least one number")
        }
        
        let specialCharacters = "!@#$%^&*(),.?\":{}|<>"
        if !password.contains(where: { specialCharacters.contains($0) }) {
            issues.append("Password must contain at least one special character")
        }
        
        return PasswordValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// Sanitize user input to prevent injection attacks
    /// - Parameters:
    ///   - input: Input string to sanitize
    ///   - maxLength: Maximum allowed length
    /// - Returns: Sanitized string
    static func sanitizeInput(_ input: String, maxLength: Int = 255) -> String {
        // Remove HTML tags and potentially dangerous characters
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(.punctuationCharacters)
            .union(.symbols)
        
        let sanitized = input.components(separatedBy: allowedCharacterSet.inverted).joined()
        
        // Truncate to max length
        return String(sanitized.prefix(maxLength))
    }
    
    /// Validate phone number format (E.164)
    /// - Parameter phoneNumber: Phone number string
    /// - Returns: True if phone number is valid
    static func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        let phoneRegex = "^\\+[1-9]\\d{1,14}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phoneNumber)
    }
    
    /// Validate pet name
    /// - Parameter name: Pet name string
    /// - Returns: True if pet name is valid
    static func isValidPetName(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && trimmedName.count <= 50
    }
    
    /// Validate ingredient text
    /// - Parameter text: Ingredient text string
    /// - Returns: True if ingredient text is valid
    static func isValidIngredientText(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedText.isEmpty && trimmedText.count <= 10000
    }
    
    /// Validate file size
    /// - Parameters:
    ///   - size: File size in bytes
    ///   - maxSizeMB: Maximum allowed size in MB
    /// - Returns: True if file size is valid
    static func isValidFileSize(_ size: Int64, maxSizeMB: Int = 10) -> Bool {
        let maxSizeBytes = Int64(maxSizeMB) * 1024 * 1024
        return size <= maxSizeBytes
    }
    
    /// Validate MFA token format
    /// - Parameter token: MFA token string
    /// - Returns: True if token format is valid
    static func isValidMFAToken(_ token: String) -> Bool {
        return token.count == 6 && token.allSatisfy { $0.isNumber }
    }
    
    /// Validate backup code format
    /// - Parameter code: Backup code string
    /// - Returns: True if backup code format is valid
    static func isValidBackupCode(_ code: String) -> Bool {
        return code.count == 8 && code.allSatisfy { $0.isLetter || $0.isNumber }
    }
}

/// Password validation result
struct PasswordValidationResult {
    let isValid: Bool
    let issues: [String]
    
    var strength: PasswordStrength {
        if issues.isEmpty {
            return .strong
        } else if issues.count <= 2 {
            return .medium
        } else {
            return .weak
        }
    }
}

/// Password strength levels
enum PasswordStrength {
    case weak
    case medium
    case strong
    
    var color: String {
        switch self {
        case .weak:
            return "red"
        case .medium:
            return "orange"
        case .strong:
            return "green"
        }
    }
    
    var description: String {
        switch self {
        case .weak:
            return "Weak"
        case .medium:
            return "Medium"
        case .strong:
            return "Strong"
        }
    }
}
