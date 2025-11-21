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
    
    /// Map Security Framework status codes to human-readable descriptions
    /// - Parameter status: The OSStatus code from Security Framework
    /// - Returns: Human-readable description of the status code
    private static func statusDescription(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item Not Found"
        case errSecDuplicateItem:
            return "Duplicate Item"
        case errSecAuthFailed:
            return "Authentication Failed"
        case errSecInteractionNotAllowed:
            return "Interaction Not Allowed"
        default:
            return "Error (code: \(status))"
        }
    }
    
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
            if matches {
                print("✅ KeychainHelper: Verification passed for key: \(key)")
            } else {
                print("❌ KeychainHelper: Verification failed - read value doesn't match for key: \(key)")
            }
            return matches
        } else {
            // Clean up if it was saved but can't be read
            await delete(forKey: key)
            print("❌ KeychainHelper: Verification failed - cannot read value for key: \(key)")
            return false
        }
    }
    
    /// Save a value to the keychain asynchronously
    /// - Parameters:
    ///   - value: The string value to save
    ///   - key: The key to associate with the value
    static func save(_ value: String, forKey key: String) async {
        guard let data = value.data(using: .utf8) else { 
            print("❌ KeychainHelper: Failed to convert value to data for key: \(key)")
            return 
        }
        
        print("🔐 KeychainHelper: Saving value for key: \(key)")
        
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
                print("✅ KeychainHelper: Successfully saved value for \(key)")
                // Verify the save by reading it back
                let verifyQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: key,
                    kSecAttrService as String: "com.snifftest.app",
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]
                var verifyResult: AnyObject?
                let verifyStatus = SecItemCopyMatching(verifyQuery as CFDictionary, &verifyResult)
                if verifyStatus == errSecSuccess {
                    print("✅ KeychainHelper: Verified saved value for \(key) - readback successful")
                } else {
                    print("⚠️ KeychainHelper: Save succeeded but readback failed for \(key) - status: \(statusDescription(verifyStatus))")
                }
            case errSecDuplicateItem:
                print("🔐 KeychainHelper: Duplicate item for \(key) - attempting update")
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
                let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateData as CFDictionary)
                if updateStatus == errSecSuccess {
                    print("✅ KeychainHelper: Successfully updated value for \(key)")
                } else {
                    print("❌ KeychainHelper: Update failed for \(key) - status: \(statusDescription(updateStatus))")
                }
            case errSecAuthFailed:
                print("❌ KeychainHelper: Authentication failed for \(key) - may need device unlock")
            default:
                print("❌ KeychainHelper: Failed to save value for \(key) - status: \(statusDescription(status))")
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
                if let value = value {
                    print("✅ KeychainHelper: Successfully read value for \(key) (length: \(value.count) chars)")
                    return value
                } else {
                    print("❌ KeychainHelper: Read data but failed to decode as string for key: \(key)")
                    return nil
                }
            } else {
                // Handle specific error codes
                switch status {
                case errSecItemNotFound:
                    // This is expected when item doesn't exist yet - not an error
                    print("ℹ️ KeychainHelper: Item not found for key: \(key) (status: \(statusDescription(status)))")
                case errSecAuthFailed:
                    print("❌ KeychainHelper: Authentication failed for key: \(key) - may need device unlock")
                case errSecInteractionNotAllowed:
                    print("❌ KeychainHelper: Interaction not allowed for key: \(key) - device may be locked")
                default:
                    print("❌ KeychainHelper: Failed to read value for \(key) - status: \(statusDescription(status))")
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
            
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound {
                print("✅ KeychainHelper: Successfully deleted value for \(key) (status: \(statusDescription(status)))")
            } else {
                print("❌ KeychainHelper: Failed to delete value for \(key) - status: \(statusDescription(status))")
            }
        }.value
    }
    
    /// Verify all authentication tokens are properly stored and accessible
    /// This is useful for debugging keychain issues after login
    /// - Returns: Dictionary with verification results for each auth key
    static func verifyAuthTokens() async -> [String: Bool] {
        let authKeys = ["authToken", "refreshToken", "tokenExpiry"]
        var results: [String: Bool] = [:]
        
        print("🔍 KeychainHelper: Verifying all auth tokens...")
        
        for key in authKeys {
            let hasValue = await read(forKey: key) != nil
            results[key] = hasValue
            if hasValue {
                print("✅ KeychainHelper: \(key) is accessible")
            } else {
                print("❌ KeychainHelper: \(key) is NOT accessible")
            }
        }
        
        return results
    }
}
