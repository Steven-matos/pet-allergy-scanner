//
//  AppleSignInService.swift
//  SniffTest
//
//  Created by Steven Matos on 12/13/25.
//

import AuthenticationServices
import CryptoKit
import Foundation

/**
 * Apple Sign-In Service - Handles native Sign in with Apple authentication
 *
 * This service manages the ASAuthorizationController flow and provides
 * credentials to be exchanged with Supabase for session tokens.
 *
 * Key responsibilities:
 * - Generate secure nonce for replay attack prevention
 * - Present Apple Sign-In sheet
 * - Handle authorization success/failure
 * - Provide identity token for Supabase authentication
 *
 * Follows SOLID principles:
 * - Single Responsibility: Only handles Apple Sign-In logic
 * - Open/Closed: Extensible through AppleSignInDelegate protocol
 *
 * Security considerations:
 * - Uses SHA256 hashed nonce per Apple's guidelines
 * - Apple only provides email on first authorization
 */

// MARK: - Apple Sign-In Credential

/// Represents the credential received from Apple Sign-In
struct AppleSignInCredential {
    /// The identity token (JWT) to send to Supabase
    let identityToken: String
    /// The authorization code for server-side verification
    let authorizationCode: String
    /// User's email (only provided on first sign-in)
    let email: String?
    /// User's full name (only provided on first sign-in)
    let fullName: PersonNameComponents?
    /// The nonce used for this authentication request
    let nonce: String
    /// The user identifier from Apple
    let userIdentifier: String
}

// MARK: - Apple Sign-In Error

/// Errors that can occur during Apple Sign-In
enum AppleSignInError: LocalizedError {
    case invalidCredential
    case missingIdentityToken
    case missingAuthorizationCode
    case authorizationFailed(Error)
    case userCancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid Apple Sign-In credential received."
        case .missingIdentityToken:
            return "Apple Sign-In identity token was not provided."
        case .missingAuthorizationCode:
            return "Apple Sign-In authorization code was not provided."
        case .authorizationFailed(let error):
            return "Apple Sign-In failed: \(error.localizedDescription)"
        case .userCancelled:
            return "Apple Sign-In was cancelled."
        case .unknown:
            return "An unknown error occurred during Apple Sign-In."
        }
    }
}

// MARK: - Apple Sign-In Service

/// Service for handling Sign in with Apple authentication flow
@MainActor
final class AppleSignInService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isAuthenticating = false
    @Published private(set) var error: AppleSignInError?
    
    // MARK: - Private Properties
    
    /// Current nonce used for authentication (SHA256 hashed version sent to Apple)
    private var currentNonce: String?
    
    /// Continuation for async/await support
    private var authContinuation: CheckedContinuation<AppleSignInCredential, Error>?
    
    // MARK: - Public Methods
    
    /// Start the Apple Sign-In flow
    /// - Returns: AppleSignInCredential on success
    /// - Throws: AppleSignInError on failure
    func signIn() async throws -> AppleSignInCredential {
        // Prevent multiple simultaneous auth attempts
        guard !isAuthenticating else {
            throw AppleSignInError.unknown
        }
        
        isAuthenticating = true
        error = nil
        
        defer {
            isAuthenticating = false
        }
        
        // Generate a secure random nonce
        let nonce = generateNonce()
        currentNonce = nonce
        
        return try await withCheckedThrowingContinuation { continuation in
            self.authContinuation = continuation
            
            // Create the Apple ID authorization request
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
            
            // Create and configure the authorization controller
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            authorizationController.performRequests()
        }
    }
    
    /// Check if the user has previously signed in with Apple
    /// - Parameter userIdentifier: The Apple user identifier to check
    /// - Returns: Credential state for the user
    func getCredentialState(for userIdentifier: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Generate a secure random nonce string
    /// - Parameter length: Length of the nonce (default: 32)
    /// - Returns: Random string suitable for use as a nonce
    private func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        
        if errorCode != errSecSuccess {
            // Fallback to UUID-based nonce if SecRandomCopyBytes fails
            return UUID().uuidString + UUID().uuidString
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    /// Hash a string using SHA256
    /// - Parameter input: The string to hash
    /// - Returns: SHA256 hash as a hex string
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { byte in
            String(format: "%02x", byte)
        }.joined()
        
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInService: ASAuthorizationControllerDelegate {
    
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            handleAuthorizationSuccess(authorization)
        }
    }
    
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            handleAuthorizationError(error)
        }
    }
    
    // MARK: - Private Authorization Handlers
    
    private func handleAuthorizationSuccess(_ authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            error = .invalidCredential
            authContinuation?.resume(throwing: AppleSignInError.invalidCredential)
            authContinuation = nil
            return
        }
        
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            error = .missingIdentityToken
            authContinuation?.resume(throwing: AppleSignInError.missingIdentityToken)
            authContinuation = nil
            return
        }
        
        guard let authorizationCodeData = appleIDCredential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            error = .missingAuthorizationCode
            authContinuation?.resume(throwing: AppleSignInError.missingAuthorizationCode)
            authContinuation = nil
            return
        }
        
        guard let nonce = currentNonce else {
            error = .unknown
            authContinuation?.resume(throwing: AppleSignInError.unknown)
            authContinuation = nil
            return
        }
        
        let credential = AppleSignInCredential(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            email: appleIDCredential.email,
            fullName: appleIDCredential.fullName,
            nonce: nonce,
            userIdentifier: appleIDCredential.user
        )
        
        // Log successful authorization (without sensitive data)
        print("AppleSignInService: Authorization successful for user: \(appleIDCredential.user.prefix(8))...")
        
        authContinuation?.resume(returning: credential)
        authContinuation = nil
        currentNonce = nil
    }
    
    private func handleAuthorizationError(_ authError: Error) {
        let asError = authError as? ASAuthorizationError
        
        switch asError?.code {
        case .canceled:
            error = .userCancelled
            authContinuation?.resume(throwing: AppleSignInError.userCancelled)
        case .failed, .invalidResponse, .notHandled, .notInteractive, .unknown:
            error = .authorizationFailed(authError)
            authContinuation?.resume(throwing: AppleSignInError.authorizationFailed(authError))
        default:
            error = .authorizationFailed(authError)
            authContinuation?.resume(throwing: AppleSignInError.authorizationFailed(authError))
        }
        
        authContinuation = nil
        currentNonce = nil
        
        print("AppleSignInService: Authorization failed - \(authError.localizedDescription)")
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInService: ASAuthorizationControllerPresentationContextProviding {
    
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Use MainActor.assumeIsolated to safely access main actor-isolated properties
        // This is safe because ASAuthorizationController always calls this on the main thread
        return MainActor.assumeIsolated {
            // Get the key window for presenting the Apple Sign-In sheet
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first(where: { $0.isKeyWindow }) else {
                // Fallback to first window if key window not found
                let scenes = UIApplication.shared.connectedScenes
                let windowScene = scenes.first as? UIWindowScene
                return windowScene?.windows.first ?? UIWindow()
            }
            return window
        }
    }
}

