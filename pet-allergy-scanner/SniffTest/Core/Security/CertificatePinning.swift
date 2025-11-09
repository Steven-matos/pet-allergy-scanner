//
//  CertificatePinning.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import Security

/// Certificate pinning utility for enhanced security
/// 
/// **IMPORTANT**: Certificate pinning is currently DISABLED in production.
/// To enable it, you must:
/// 1. Obtain your server's SSL certificate in DER format
/// 2. Convert it to base64: `base64 -i certificate.der`
/// 3. Add the base64 string to pinnedCertificates array below
/// 4. Test thoroughly before deploying
///
/// Without proper certificates, this provides NO security enhancement.
class CertificatePinning {
    
    /// Pinned certificate data (base64 encoded DER format)
    /// **WARNING**: Empty array means certificate pinning is DISABLED
    private static let pinnedCertificates: [String] = [
        // TODO: Add your Railway/production server's certificate data here
        // Example: "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA..."
    ]
    
    /// Certificate pinning is disabled when no certificates are provided
    private static var isPinningEnabled: Bool {
        return !pinnedCertificates.isEmpty
    }
    
    /// Validate server certificate against pinned certificates
    /// - Parameters:
    ///   - serverTrust: Server trust object
    ///   - host: Host name
    /// - Returns: True if certificate is valid or pinning is disabled
    static func validateCertificate(_ serverTrust: SecTrust, host: String) -> Bool {
        // Certificate pinning is disabled if no certificates are pinned
        guard isPinningEnabled else {
            #if DEBUG
            print("⚠️ Certificate pinning is DISABLED (no certificates configured)")
            #endif
            return true
        }
        
        #if DEBUG
        // Skip certificate pinning validation in debug builds for easier development
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
class CertificatePinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    
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
