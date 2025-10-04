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
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        await withCheckedContinuation { continuation in
            // Perform keychain operations on background queue
            DispatchQueue.global(qos: .userInitiated).async {
                SecItemDelete(query as CFDictionary)
                SecItemAdd(query as CFDictionary, nil)
                continuation.resume()
            }
        }
    }

    /// Read a value from the keychain asynchronously
    /// - Parameter key: The key to read
    /// - Returns: The string value if found, nil otherwise
    static func read(forKey key: String) async -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                
                if status == errSecSuccess, let data = result as? Data {
                    let value = String(data: data, encoding: .utf8)
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Delete a value from the keychain asynchronously
    /// - Parameter key: The key to delete
    static func delete(forKey key: String) async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                SecItemDelete(query as CFDictionary)
                continuation.resume()
            }
        }
    }
}
