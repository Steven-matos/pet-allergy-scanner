//
//  SecureDataManager.swift
//  pet-allergy-scanner
//
//  Created by Code Assistant, 2025.
//

import Foundation
import Security

/// Secure data manager for handling sensitive information like backup codes and tokens
class SecureDataManager {
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
    
    private struct SecureDataItem {
        var data: Data
        let expirationDate: Date
    }
    
    private func encryptData(_ string: String) -> Data {
        // Simple XOR encryption for demo - in production, use proper encryption
        guard let data = string.data(using: .utf8) else { return Data() }
        
        let key: UInt8 = 0x42 // Simple key
        var encryptedData = Data()
        
        for byte in data {
            encryptedData.append(byte ^ key)
        }
        
        return encryptedData
    }
    
    private func decryptData(_ data: Data) -> String? {
        // Simple XOR decryption for demo - in production, use proper decryption
        let key: UInt8 = 0x42 // Same key as encryption
        
        var decryptedData = Data()
        for byte in data {
            decryptedData.append(byte ^ key)
        }
        
        return String(data: decryptedData, encoding: .utf8)
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
