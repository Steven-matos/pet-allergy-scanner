//
//  SessionLifecycleManager.swift
//  SniffTest
//
//  Created by GPT-5.1 Codex on 11/17/25.
//

import Foundation
import SwiftUI

/// Centralizes session lifecycle rules to match Apple's 2025 secure session guidelines.
@MainActor
final class SessionLifecycleManager: ObservableObject {
    static let shared = SessionLifecycleManager()
    
    private enum Keys: String {
        case lastSessionValidation
        case lastBackgroundTimestamp
        case lastVersionSignature
    }
    
    private enum Constants {
        /// Re-validate the authenticated session every 6 hours per Apple's resilience guidance.
        static let validationRefreshInterval: TimeInterval = 6 * 60 * 60
        /// Force a logout if the app has not been foregrounded for 30 days (matches Supabase refresh token TTL).
        static let inactivityLogoutInterval: TimeInterval = 30 * 24 * 60 * 60
    }
    
    private let userDefaults = UserDefaults.standard
    private let authService = AuthService.shared
    private let apiService = APIService.shared
    
    private init() {
        if userDefaults.object(forKey: Keys.lastBackgroundTimestamp.rawValue) == nil {
            recordBackgroundTimestamp()
        }
        if userDefaults.string(forKey: Keys.lastVersionSignature.rawValue) == nil {
            userDefaults.set(currentBuildSignature(), forKey: Keys.lastVersionSignature.rawValue)
        }
    }
    
    /// Respond to SwiftUI scene phase changes so session refreshes follow Apple's lifecycle rules.
    /// - Parameter phase: The new scene phase.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Task { await self.processAppDidBecomeActive() }
        case .background:
            recordBackgroundTimestamp()
        default:
            break
        }
    }
    
    /// Record the last successful session validation timestamp.
    func recordSessionValidation() {
        userDefaults.set(Date().timeIntervalSince1970, forKey: Keys.lastSessionValidation.rawValue)
    }
    
    /// Determine if the authenticated session must be refreshed.
    /// - Parameter force: Whether the caller wants to override the interval check.
    func shouldRefreshSession(force: Bool = false) -> Bool {
        if force { return true }
        guard let last = userDefaults.object(forKey: Keys.lastSessionValidation.rawValue) as? TimeInterval else {
            return true
        }
        return Date().timeIntervalSince1970 - last > Constants.validationRefreshInterval
    }
    
    // MARK: - Private Helpers
    
    private func processAppDidBecomeActive() async {
        // CRITICAL: Try to refresh tokens BEFORE checking inactivity policy
        // This allows us to refresh even if access token is expired (up to 30 days)
        // Only logout if refresh token itself is expired (30+ days of inactivity)
        await apiService.ensureValidToken()
        
        // After attempting token refresh, check inactivity policy
        // If tokens were cleared during refresh, inactivity check will see we're already logged out
        await enforceInactivityPolicyIfRequired()
        
        let forceRefresh = detectAppUpdate()
        await authService.resumeSessionIfNeeded(forceRefresh: forceRefresh)
    }
    
    private func detectAppUpdate() -> Bool {
        let currentSignature = currentBuildSignature()
        let storedSignature = userDefaults.string(forKey: Keys.lastVersionSignature.rawValue)
        
        guard storedSignature != currentSignature else { return false }
        userDefaults.set(currentSignature, forKey: Keys.lastVersionSignature.rawValue)
        return storedSignature != nil
    }
    
    private func recordBackgroundTimestamp() {
        userDefaults.set(Date().timeIntervalSince1970, forKey: Keys.lastBackgroundTimestamp.rawValue)
    }
    
    private func enforceInactivityPolicyIfRequired() async {
        // Only enforce inactivity logout if we don't have valid tokens
        // This ensures we try to refresh first (in processAppDidBecomeActive) before logging out
        // If refresh succeeds, tokens are valid and we don't need to logout
        // If refresh fails (refresh token expired >30 days), tokens will be cleared and we're already logged out
        guard await apiService.hasAuthToken else {
            // No tokens - already logged out, no need to enforce inactivity policy
            return
        }
        
        guard let lastBackground = userDefaults.object(forKey: Keys.lastBackgroundTimestamp.rawValue) as? TimeInterval else {
            recordBackgroundTimestamp()
            return
        }
        
        let elapsed = Date().timeIntervalSince1970 - lastBackground
        if elapsed > Constants.inactivityLogoutInterval {
            #if DEBUG
            print("🔐 SessionLifecycleManager: Enforcing inactivity logout - app inactive for \(Int(elapsed / (24 * 60 * 60))) days (>30 days)")
            #endif
            await authService.logout()
        }
    }
    
    private func currentBuildSignature() -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "0"
        let build = info["CFBundleVersion"] as? String ?? "0"
        return "\(version)-\(build)"
    }
}
