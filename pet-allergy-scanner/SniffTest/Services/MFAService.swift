//
//  MFAService.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import Combine

/// Multi-Factor Authentication service for managing MFA setup and verification
@MainActor
class MFAService: ObservableObject {
    static let shared = MFAService()
    
    @Published var isMFASetup = false
    @Published var isMFAEnabled = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var qrCodeImage: String?
    @Published var backupCodes: [String] = []
    
    private let apiService = APIService.shared
    private let securityManager = SecurityManager.shared
    
    private init() {}
    
    /// Check MFA status for current user
    func checkMFAStatus() async {
        guard await apiService.hasAuthToken else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let status = try await apiService.getMFAStatus()
            isMFAEnabled = status.isEnabled
            isMFASetup = status.isEnabled || status.hasBackupCodes
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Setup MFA for current user
    func setupMFA() async {
        guard await apiService.hasAuthToken else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.setupMFA()
            qrCodeImage = response.qrCodeImage
            isMFASetup = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Enable MFA with verification token
    func enableMFA(token: String) async {
        guard await apiService.hasAuthToken else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiService.enableMFA(token: token)
            isMFAEnabled = true
            qrCodeImage = nil // Clear QR code after successful setup
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Verify MFA token
    func verifyMFA(token: String) async -> Bool {
        guard await apiService.hasAuthToken else {
            errorMessage = "Authentication required"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiService.verifyMFA(token: token)
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    /// Generate backup codes
    func generateBackupCodes() -> [String] {
        return securityManager.generateBackupCodes()
    }
    
    /// Validate MFA token format
    func validateMFAToken(_ token: String) -> Bool {
        // TOTP tokens are typically 6 digits
        return token.count == 6 && token.allSatisfy { $0.isNumber }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Reset MFA state
    func reset() {
        isMFASetup = false
        isMFAEnabled = false
        qrCodeImage = nil
        backupCodes = []
        errorMessage = nil
    }
}

// MARK: - SecurityManager Extension for MFA

extension SecurityManager {
    /// Generate backup codes for MFA
    func generateBackupCodes() -> [String] {
        var codes: [String] = []
        for _ in 0..<10 {
            let code = generateSecureToken(length: 8)
            codes.append(code)
        }
        return codes
    }
}
