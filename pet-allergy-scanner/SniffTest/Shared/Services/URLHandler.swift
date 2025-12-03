//
//  URLHandler.swift
//  SniffTest
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
    /// Supports both custom URL schemes (snifftest://) and HTTP/HTTPS redirects
    func handleURL(_ url: URL) -> Bool {
        // Support both custom scheme and HTTP/HTTPS URLs from Supabase
        let isCustomScheme = url.scheme?.lowercased() == "snifftest" || url.scheme?.lowercased() == "snifftest"
        let isHTTPScheme = url.scheme == "http" || url.scheme == "https"
        
        guard isCustomScheme || isHTTPScheme else {
            print("URLHandler: Unsupported URL scheme - \(url.scheme ?? "nil")")
            return false
        }
        
        // Parse URL components
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.path ?? ""
        let queryItems = components?.queryItems ?? []
        let fragment = components?.fragment
        
        print("URLHandler: Received URL - \(url)")
        print("URLHandler: Scheme - \(url.scheme ?? "nil")")
        print("URLHandler: Path - \(path)")
        print("URLHandler: Query items - \(queryItems)")
        print("URLHandler: Fragment - \(fragment ?? "nil")")
        
        // Extract tokens from query items or fragment (Supabase uses fragment for OAuth)
        var allQueryItems = queryItems
        
        // If tokens are in fragment (common with Supabase OAuth), parse them
        if let fragment = fragment, !fragment.isEmpty {
            let fragmentComponents = URLComponents(string: "?\(fragment)")
            if let fragmentItems = fragmentComponents?.queryItems {
                allQueryItems.append(contentsOf: fragmentItems)
            }
        }
        
        // Handle different authentication flows based on path or query parameters
        if path.contains("/auth/confirm") || path.contains("confirm") || 
           allQueryItems.contains(where: { $0.name == "access_token" && $0.value != nil && !allQueryItems.contains(where: { $0.name == "type" && $0.value == "recovery" }) }) {
            handleEmailConfirmation(queryItems: allQueryItems)
        } else if path.contains("/auth/reset") || path.contains("reset") ||
                  allQueryItems.contains(where: { $0.name == "type" && $0.value == "recovery" }) {
            handlePasswordReset(queryItems: allQueryItems)
        } else if path.contains("/auth/callback") || path.contains("callback") {
            handleAuthCallback(queryItems: allQueryItems)
        } else {
            // Default authentication handling - try to extract tokens
            handleDefaultAuth(queryItems: allQueryItems)
        }
        
        return true
    }
    
    /// Handle email confirmation redirect
    private func handleEmailConfirmation(queryItems: [URLQueryItem]) {
        print("URLHandler: Handling email confirmation")
        
        // Extract tokens and handle email confirmation
        // Try access_token and refresh_token first (standard format)
        if let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value,
           let refreshToken = queryItems.first(where: { $0.name == "refresh_token" })?.value {
            
            print("URLHandler: Found tokens - access_token: \(accessToken.prefix(20))...")
            
            // Store tokens and update authentication state
            AuthService.shared.handleEmailConfirmation(
                accessToken: accessToken,
                refreshToken: refreshToken
            )
        } else if let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value {
            // If only access token is available, use auth callback
            print("URLHandler: Found access token only, using auth callback")
            AuthService.shared.handleAuthCallback(accessToken: accessToken)
        } else {
            print("URLHandler: Missing required tokens for email confirmation")
            print("URLHandler: Available query items: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" })")
        }
    }
    
    /// Handle password reset redirect
    private func handlePasswordReset(queryItems: [URLQueryItem]) {
        print("URLHandler: Handling password reset")
        
        // Check for recovery type first
        let isRecovery = queryItems.contains(where: { $0.name == "type" && $0.value == "recovery" })
        
        if let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value {
            if isRecovery {
                print("URLHandler: Found password reset token (recovery type)")
                // Handle password reset flow - user needs to set new password
                AuthService.shared.handlePasswordReset(accessToken: accessToken)
            } else {
                // Token without recovery type - might be from email confirmation
                print("URLHandler: Found access token but not recovery type, treating as auth callback")
                AuthService.shared.handleAuthCallback(accessToken: accessToken)
            }
        } else {
            print("URLHandler: Missing access token for password reset")
            // Try to extract from hash fragment if present
            print("URLHandler: Query items available: \(queryItems.map { "\($0.name)=\($0.value ?? "nil")" })")
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
