//
//  CertificatePinning.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import Security

/// Certificate pinning utility for enhanced security
class CertificatePinning {
    
    /// Pinned certificate data (base64 encoded)
    private static let pinnedCertificates: [String] = [
        // Add your server's certificate data here
        // This should be the actual certificate data from your server
        // Example: "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."
    ]
    
    /// Validate server certificate against pinned certificates
    /// - Parameters:
    ///   - serverTrust: Server trust object
    ///   - host: Host name
    /// - Returns: True if certificate is valid
    static func validateCertificate(_ serverTrust: SecTrust, host: String) -> Bool {
        #if DEBUG
        // Skip certificate pinning in debug builds
        return true
        #else
        
        // Get server certificate
        guard let serverCertificate = SecTrustCopyCertificateChain(serverTrust) else {
            return false
        }
        
        // Get the first certificate from the chain
        guard CFArrayGetCount(serverCertificate) > 0 else {
            return false
        }
        
        let certificate = CFArrayGetValueAtIndex(serverCertificate, 0)
        guard let serverCert = Unmanaged<SecCertificate>.fromOpaque(certificate!).takeUnretainedValue() as SecCertificate? else {
            return false
        }
        
        // Get certificate data
        let serverCertificateData = SecCertificateCopyData(serverCert)
        let data = CFDataGetBytePtr(serverCertificateData)
        let size = CFDataGetLength(serverCertificateData)
        let serverCertData = Data(bytes: data!, count: size)
        
        // Check against pinned certificates
        for pinnedCertString in pinnedCertificates {
            guard let pinnedCertData = Data(base64Encoded: pinnedCertString) else {
                continue
            }
            
            if serverCertData == pinnedCertData {
                return true
            }
        }
        
        return false
        #endif
    }
    
    /// Create custom URL session with certificate pinning
    /// - Returns: Configured URL session
    static func createSecureURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        
        let session = URLSession(
            configuration: configuration,
            delegate: CertificatePinningDelegate(),
            delegateQueue: nil
        )
        
        return session
    }
}

/// URL session delegate for certificate pinning
class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let host = challenge.protectionSpace.host
        
        // Validate certificate
        if CertificatePinning.validateCertificate(serverTrust, host: host) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

/// Security configuration for the app
struct SecurityConfiguration {
    
    /// Enable certificate pinning
    static let enableCertificatePinning = true
    
    /// Enable biometric authentication
    static let enableBiometricAuth = true
    
    /// Enable jailbreak detection
    static let enableJailbreakDetection = true
    
    /// Maximum login attempts before lockout
    static let maxLoginAttempts = 5
    
    /// Lockout duration in minutes
    static let lockoutDurationMinutes = 15
    
    /// Session timeout in minutes
    static let sessionTimeoutMinutes = 30
    
    /// Enable automatic logout on app background
    static let autoLogoutOnBackground = true
    
    /// Enable secure data wiping
    static let enableSecureDataWiping = true
    
    /// Enable input validation
    static let enableInputValidation = true
    
    /// Enable rate limiting
    static let enableRateLimiting = true
}
