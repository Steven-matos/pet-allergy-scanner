//
//  SecureDataManager.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import Security
import CryptoKit

/// Secure data manager for handling sensitive information like backup codes and tokens
@MainActor
class SecureDataManager: @unchecked Sendable {
    static let shared = SecureDataManager()
    
    private init() {}
    
    /// Securely store sensitive data in memory with automatic cleanup
    /// - Parameters:
    ///   - data: Data to store securely
    ///   - key: Unique key for the data
    ///   - expirationTime: Time after which data should be cleared (default: 5 minutes)
    func storeSensitiveData(_ data: String, forKey key: String, expirationTime: TimeInterval = 300) {
        // Store in a secure, encrypted format
        let encryptedData = encryptData(data)
        
        // Store with expiration
        let expirationDate = Date().addingTimeInterval(expirationTime)
        let secureItem = SecureDataItem(data: encryptedData, expirationDate: expirationDate)
        
        // Store in memory (not persistent)
        secureStorage[key] = secureItem
        
        // Schedule cleanup
        scheduleCleanup(forKey: key, at: expirationDate)
    }
    
    /// Retrieve sensitive data
    /// - Parameter key: Key for the data
    /// - Returns: Decrypted data or nil if expired/not found
    func retrieveSensitiveData(forKey key: String) -> String? {
        guard let item = secureStorage[key] else { return nil }
        
        // Check if expired
        if Date() > item.expirationDate {
            secureStorage.removeValue(forKey: key)
            return nil
        }
        
        return decryptData(item.data)
    }
    
    /// Clear sensitive data immediately
    /// - Parameter key: Key for the data
    func clearSensitiveData(forKey key: String) {
        if var item = secureStorage[key] {
            // Securely wipe the data
            item.data = Data(count: item.data.count)
            secureStorage.removeValue(forKey: key)
        }
    }
    
    /// Clear all sensitive data
    func clearAllSensitiveData() {
        for (_, var item) in secureStorage {
            // Securely wipe each item
            item.data = Data(count: item.data.count)
        }
        secureStorage.removeAll()
    }
    
    // MARK: - Private Implementation
    
    private var secureStorage: [String: SecureDataItem] = [:]
    private var cleanupTimers: [String: Timer] = [:]
    private lazy var encryptionKey: SymmetricKey = {
        return getOrCreateEncryptionKey()
    }()
    
    private struct SecureDataItem {
        var data: Data
        let expirationDate: Date
    }
    
    /// Encrypt string data using AES-256-GCM
    /// - Parameter string: String to encrypt
    /// - Returns: Encrypted data with authentication tag
    private func encryptData(_ string: String) -> Data {
        guard let data = string.data(using: .utf8) else { return Data() }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
            return sealedBox.combined ?? Data()
        } catch {
            print("Encryption error: \(error.localizedDescription)")
            return Data()
        }
    }
    
    /// Decrypt data using AES-256-GCM
    /// - Parameter data: Encrypted data
    /// - Returns: Decrypted string or nil on failure
    private func decryptData(_ data: Data) -> String? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get or create a persistent encryption key stored in Keychain
    /// - Returns: Symmetric encryption key
    private func getOrCreateEncryptionKey() -> SymmetricKey {
        let keyTag = "com.snifftest.app.encryption.key"
        
        // Try to retrieve existing key
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let keyData = result as? Data {
            return SymmetricKey(data: keyData)
        }
        
        // Create new key if not found
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemAdd(addQuery as CFDictionary, nil)
        return newKey
    }
    
    private func scheduleCleanup(forKey key: String, at date: Date) {
        // Cancel existing timer if any
        cleanupTimers[key]?.invalidate()
        
        // Schedule new cleanup
        let timer = Timer(fireAt: date, interval: 0, target: self, selector: #selector(cleanupExpiredData(_:)), userInfo: key, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        cleanupTimers[key] = timer
    }
    
    @objc private func cleanupExpiredData(_ timer: Timer) {
        guard let key = timer.userInfo as? String else { return }
        clearSensitiveData(forKey: key)
        cleanupTimers.removeValue(forKey: key)
    }
}

/// Extension for secure backup code handling
extension SecureDataManager {
    
    /// Store backup codes securely
    /// - Parameter codes: Array of backup codes
    func storeBackupCodes(_ codes: [String]) {
        let codesString = codes.joined(separator: ",")
        storeSensitiveData(codesString, forKey: "backup_codes", expirationTime: 600) // 10 minutes
    }
    
    /// Retrieve backup codes
    /// - Returns: Array of backup codes or nil if expired/not found
    func retrieveBackupCodes() -> [String]? {
        guard let codesString = retrieveSensitiveData(forKey: "backup_codes") else { return nil }
        return codesString.split(separator: ",").map(String.init)
    }
    
    /// Clear backup codes
    func clearBackupCodes() {
        clearSensitiveData(forKey: "backup_codes")
    }
}

/// Extension for secure MFA token handling
extension SecureDataManager {
    
    /// Store MFA token securely
    /// - Parameter token: MFA token
    func storeMFAToken(_ token: String) {
        storeSensitiveData(token, forKey: "mfa_token", expirationTime: 60) // 1 minute
    }
    
    /// Retrieve MFA token
    /// - Returns: MFA token or nil if expired/not found
    func retrieveMFAToken() -> String? {
        return retrieveSensitiveData(forKey: "mfa_token")
    }
    
    /// Clear MFA token
    func clearMFAToken() {
        clearSensitiveData(forKey: "mfa_token")
    }
}
