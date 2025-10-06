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
        guard let data = value.data(using: .utf8) else { return }
        
        await Task.detached {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data
            ]
            
            SecItemDelete(query as CFDictionary)
            SecItemAdd(query as CFDictionary, nil)
        }.value
    }

    /// Read a value from the keychain asynchronously
    /// - Parameter key: The key to read
    /// - Returns: The string value if found, nil otherwise
    static func read(forKey key: String) async -> String? {
        await Task.detached {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess, let data = result as? Data {
                return String(data: data, encoding: .utf8)
            } else {
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
            
            SecItemDelete(query as CFDictionary)
        }.value
    }
}
