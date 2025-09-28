//
//  URLHandler.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/28/25.
//

import Foundation
import SwiftUI

/// Handles URL redirects from Supabase email authentication
@MainActor
class URLHandler: ObservableObject {
    static let shared = URLHandler()
    
    private init() {}
    
    /// Handle incoming URL from email authentication
    func handleURL(_ url: URL) -> Bool {
        guard url.scheme == "sniffsafe" else { return false }
        
        // Parse URL components
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.path ?? ""
        let queryItems = components?.queryItems ?? []
        
        print("URLHandler: Received URL - \(url)")
        print("URLHandler: Path - \(path)")
        print("URLHandler: Query items - \(queryItems)")
        
        // Handle different authentication flows
        switch path {
        case "/auth/confirm":
            handleEmailConfirmation(queryItems: queryItems)
        case "/auth/reset":
            handlePasswordReset(queryItems: queryItems)
        case "/auth/callback":
            handleAuthCallback(queryItems: queryItems)
        default:
            // Default authentication handling
            handleDefaultAuth(queryItems: queryItems)
        }
        
        return true
    }
    
    /// Handle email confirmation redirect
    private func handleEmailConfirmation(queryItems: [URLQueryItem]) {
        print("URLHandler: Handling email confirmation")
        
        // Extract tokens and handle email confirmation
        if let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value,
           let refreshToken = queryItems.first(where: { $0.name == "refresh_token" })?.value {
            
            print("URLHandler: Found tokens - access_token: \(accessToken.prefix(20))...")
            
            // Store tokens and update authentication state
            AuthService.shared.handleEmailConfirmation(
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        } else {
            print("URLHandler: Missing required tokens for email confirmation")
        }
    }
    
    /// Handle password reset redirect
    private func handlePasswordReset(queryItems: [URLQueryItem]) {
        print("URLHandler: Handling password reset")
        
        if let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value,
           let type = queryItems.first(where: { $0.name == "type" })?.value {
            
            if type == "recovery" {
                print("URLHandler: Found password reset token")
                // Handle password reset flow
                AuthService.shared.handlePasswordReset(accessToken: accessToken)
            }
        } else {
            print("URLHandler: Missing required tokens for password reset")
        }
    }
    
    /// Handle general auth callback
    private func handleAuthCallback(queryItems: [URLQueryItem]) {
        print("URLHandler: Handling auth callback")
        
        // Handle general authentication callbacks
        if let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value {
            print("URLHandler: Found access token for callback")
            AuthService.shared.handleAuthCallback(accessToken: accessToken)
        } else {
            print("URLHandler: Missing access token for callback")
        }
    }
    
    /// Handle default authentication flow
    private func handleDefaultAuth(queryItems: [URLQueryItem]) {
        print("URLHandler: Handling default auth")
        
        // Handle general authentication tokens
        if let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value {
            print("URLHandler: Found access token for default auth")
            AuthService.shared.handleAuthCallback(accessToken: accessToken)
        } else {
            print("URLHandler: No access token found in default auth")
        }
    }
}
