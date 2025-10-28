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
                kSecValueData as String: data
            ]
            
            // Delete existing item first
            SecItemDelete(query as CFDictionary)
            
            // Add new item
            let status = SecItemAdd(query as CFDictionary, nil)
            
            // Handle specific error codes
            switch status {
            case errSecSuccess:
                print("🔐 KeychainHelper: Successfully saved value for \(key)")
            case errSecDuplicateItem:
                print("🔐 KeychainHelper: Duplicate item for \(key) - attempting update")
                // Try to update instead
                let updateQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: key
                ]
                let updateData: [String: Any] = [
                    kSecValueData as String: data
                ]
                let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateData as CFDictionary)
                print("🔐 KeychainHelper: Update status for \(key): \(updateStatus)")
            case errSecAuthFailed:
                print("🔐 KeychainHelper: Authentication failed for \(key)")
            default:
                print("❌ KeychainHelper: Failed to save value for \(key) with status: \(status)")
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
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            print("🔐 KeychainHelper: Read status for \(key): \(status)")
            
            if status == errSecSuccess, let data = result as? Data {
                let value = String(data: data, encoding: .utf8)
                print("🔐 KeychainHelper: Successfully read value for \(key): \(value?.prefix(20) ?? "nil")...")
                return value
            } else {
                // Handle specific error codes
                switch status {
                case errSecItemNotFound:
                    print("🔐 KeychainHelper: Item not found for key: \(key)")
                case errSecAuthFailed:
                    print("🔐 KeychainHelper: Authentication failed for key: \(key)")
                default:
                    print("❌ KeychainHelper: Failed to read value for \(key) with status: \(status)")
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
                kSecAttrAccount as String: key
            ]
            
            let status = SecItemDelete(query as CFDictionary)
            print("🔐 KeychainHelper: Delete status for \(key): \(status)")
        }.value
    }
}
