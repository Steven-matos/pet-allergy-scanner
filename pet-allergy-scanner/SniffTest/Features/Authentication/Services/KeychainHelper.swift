//
//  KeychainHelper.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import Security

/// Thread-safe Keychain operations using async/await to prevent main thread blocking
struct KeychainHelper {
    
    /// Verify that a value can be saved and read back from keychain
    /// This is useful for debugging keychain access issues
    /// - Parameter key: The key to test
    /// - Returns: True if save/read cycle works, false otherwise
    static func verifyKeychainAccess(forKey key: String) async -> Bool {
        let testValue = "keychain_verification_test_\(UUID().uuidString)"
        
        // Try to save
        await save(testValue, forKey: key)
        
        // Try to read back
        if let readValue = await read(forKey: key) {
            // Clean up test value
            await delete(forKey: key)
            
            // Verify it matches
            let matches = readValue == testValue
            return matches
        } else {
            // Clean up if it was saved but can't be read
            await delete(forKey: key)
            return false
        }
    }
    
    /// Save a value to the keychain asynchronously
    /// - Parameters:
    ///   - value: The string value to save
    ///   - key: The key to associate with the value
    static func save(_ value: String, forKey key: String) async {
        guard let data = value.data(using: .utf8) else { 
            return 
        }
        
        await Task.detached {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: "com.snifftest.app",
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            
            // Delete existing item first
            SecItemDelete(query as CFDictionary)
            
            // Add new item
            let status = SecItemAdd(query as CFDictionary, nil)
            
            // Handle specific error codes
            switch status {
            case errSecSuccess:
                // Verify the save by reading it back
                let verifyQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: key,
                    kSecAttrService as String: "com.snifftest.app",
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]
                var verifyResult: AnyObject?
                SecItemCopyMatching(verifyQuery as CFDictionary, &verifyResult)
            case errSecDuplicateItem:
                // Try to update instead
                let updateQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: key,
                    kSecAttrService as String: "com.snifftest.app"
                ]
                let updateData: [String: Any] = [
                    kSecValueData as String: data,
                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                ]
                SecItemUpdate(updateQuery as CFDictionary, updateData as CFDictionary)
            case errSecAuthFailed:
                break
            default:
                break
            }
        }.value
    }

    /// Read a value from the keychain asynchronously
    /// - Parameter key: The key to read
    /// - Returns: The string value if found, nil otherwise
    static func read(forKey key: String) async -> String? {
        return await Task.detached {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: "com.snifftest.app",
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess, let data = result as? Data {
                let value = String(data: data, encoding: .utf8)
                return value
            } else {
                // Handle specific error codes
                switch status {
                case errSecItemNotFound:
                    // This is expected when item doesn't exist yet - not an error
                    break
                case errSecAuthFailed:
                    break
                case errSecInteractionNotAllowed:
                    break
                default:
                    break
                }
                return nil
            }
        }.value
    }

    /// Delete a value from the keychain asynchronously
    /// - Parameter key: The key to delete
    static func delete(forKey key: String) async {
        await Task.detached {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrService as String: "com.snifftest.app"
            ]
            
            SecItemDelete(query as CFDictionary)
        }.value
    }
    
    /// Verify all authentication tokens are properly stored and accessible
    /// This is useful for debugging keychain issues after login
    /// - Returns: Dictionary with verification results for each auth key
    static func verifyAuthTokens() async -> [String: Bool] {
        let authKeys = ["authToken", "refreshToken", "tokenExpiry"]
        var results: [String: Bool] = [:]
        
        for key in authKeys {
            let hasValue = await read(forKey: key) != nil
            results[key] = hasValue
        }
        
        return results
    }
}
