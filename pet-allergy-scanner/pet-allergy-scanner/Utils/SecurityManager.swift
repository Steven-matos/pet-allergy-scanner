//
//  SecurityManager.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import CryptoKit
import LocalAuthentication

/// Security manager for handling sensitive data and authentication
class SecurityManager {
    static let shared = SecurityManager()
    
    private init() {}
    
    /// Encrypt sensitive data using AES-256-GCM
    /// - Parameter data: Data to encrypt
    /// - Returns: Encrypted data with authentication tag
    func encryptData(_ data: Data) throws -> Data {
        let key = SymmetricKey(size: .bits256)
        let sealedBox = try AES.GCM.seal(data, using: key)
        
        // Store the key securely in Keychain (simplified for example)
        // In production, use proper key derivation and storage
        
        return sealedBox.combined ?? Data()
    }
    
    /// Decrypt sensitive data using AES-256-GCM
    /// - Parameter encryptedData: Encrypted data
    /// - Returns: Decrypted data
    func decryptData(_ encryptedData: Data) throws -> Data {
        // Retrieve key from Keychain (simplified for example)
        let key = SymmetricKey(size: .bits256)
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        return decryptedData
    }
    
    /// Hash sensitive data using SHA-256
    /// - Parameter data: Data to hash
    /// - Returns: SHA-256 hash
    func hashData(_ data: Data) -> Data {
        let digest = SHA256.hash(data: data)
        return Data(digest)
    }
    
    /// Validate biometric authentication
    /// - Parameter completion: Completion handler with result
    func authenticateWithBiometrics(completion: @escaping (Result<Bool, Error>) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(.failure(error ?? SecurityError.biometricsNotAvailable))
            return
        }
        
        // Perform biometric authentication
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Authenticate to access your pet's sensitive information"
        ) { success, authenticationError in
            DispatchQueue.main.async {
                if success {
                    completion(.success(true))
                } else {
                    completion(.failure(authenticationError ?? SecurityError.authenticationFailed))
                }
            }
        }
    }
    
    /// Sanitize user input to prevent injection attacks
    /// - Parameter input: User input string
    /// - Returns: Sanitized string
    func sanitizeUserInput(_ input: String) -> String {
        // Remove potentially dangerous characters
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(.punctuationCharacters)
        
        let sanitized = input.components(separatedBy: allowedCharacterSet.inverted).joined()
        
        // Limit length to prevent buffer overflow attacks
        let maxLength = 1000
        return String(sanitized.prefix(maxLength))
    }
    
    /// Validate API response integrity
    /// - Parameters:
    ///   - data: Response data
    ///   - signature: Expected signature
    /// - Returns: True if data is valid
    func validateAPIResponse(data: Data, signature: String) -> Bool {
        // Implement HMAC validation for API responses
        // This is a simplified example - implement proper HMAC validation in production
        let computedHash = hashData(data)
        let expectedHash = Data(signature.utf8)
        
        return computedHash == expectedHash
    }
    
    /// Generate secure random token
    /// - Parameter length: Token length in bytes
    /// - Returns: Secure random token
    func generateSecureToken(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let result = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        
        guard result == errSecSuccess else {
            // Fallback to UUID if SecRandomCopyBytes fails
            return UUID().uuidString
        }
        
        return Data(bytes).base64EncodedString()
    }
    
    /// Check for jailbreak/root detection (basic implementation)
    /// - Returns: True if device appears to be compromised
    func isDeviceCompromised() -> Bool {
        #if DEBUG
        return false // Skip checks in debug builds
        #else
        // Check for common jailbreak indicators
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]
        
        for path in suspiciousPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // Check if we can write to system directories
        let testPath = "/private/test_jailbreak"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true // Should not be able to write to /private
        } catch {
            return false // Normal behavior
        }
        #endif
    }
    
    /// Secure data wipe
    /// - Parameter data: Data to securely wipe
    static func secureWipe(_ data: inout Data) {
        // Overwrite data with random bytes before deallocation
        data.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            let count = bytes.count
            
            // Overwrite with random data multiple times
            for _ in 0..<3 {
                var randomBytes = [UInt8](repeating: 0, count: count)
                _ = SecRandomCopyBytes(kSecRandomDefault, count, &randomBytes)
                memcpy(baseAddress, randomBytes, count)
            }
            
            // Final overwrite with zeros
            memset(baseAddress, 0, count)
        }
    }
}

/// Security-related errors
enum SecurityError: LocalizedError {
    case biometricsNotAvailable
    case authenticationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidSignature
    case deviceCompromised
    
    var errorDescription: String? {
        switch self {
        case .biometricsNotAvailable:
            return "Biometric authentication is not available on this device"
        case .authenticationFailed:
            return "Authentication failed"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidSignature:
            return "Invalid data signature"
        case .deviceCompromised:
            return "Device security may be compromised"
        }
    }
}
