//
//  AutomaticTokenRefreshService.swift
//  SniffTest
//
//  Created by Steven Matos on 12/8/25.
//
//  Automatic silent token refresh service that proactively refreshes
//  authentication tokens before they expire to prevent authentication errors.
//
//  SOLID Principles:
//  - Single Responsibility: Only handles automatic token refresh
//  - Open/Closed: Extensible through configuration
//  - Liskov Substitution: Conforms to expected service patterns
//  - Interface Segregation: Minimal, focused public API
//  - Dependency Inversion: Depends on abstractions (APIService protocol)
//
//  DRY: Centralizes token refresh logic, preventing duplication
//  KISS: Simple timer-based approach with clear state management

import Foundation
import Combine
import UIKit

/// Service that automatically refreshes authentication tokens before they expire
/// Prevents authentication errors by proactively refreshing tokens
@MainActor
final class AutomaticTokenRefreshService: ObservableObject {
    // MARK: - Singleton
    
    static let shared = AutomaticTokenRefreshService()
    
    // MARK: - Configuration
    
    /// How long before token expiry to trigger refresh (default: 5 minutes)
    private let refreshLeadTime: TimeInterval = 5 * 60
    
    /// How often to check if refresh is needed when app is active (default: 1 minute)
    private let checkInterval: TimeInterval = 60
    
    /// Minimum time between refresh attempts to prevent thrashing (default: 30 seconds)
    private let minimumRefreshInterval: TimeInterval = 30
    
    // MARK: - State
    
    /// Whether automatic refresh is currently enabled
    @Published private(set) var isEnabled: Bool = false
    
    /// Last time a token refresh was attempted
    private var lastRefreshAttempt: Date?
    
    /// Timer for periodic token checks
    private var refreshTimer: Timer?
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Whether a refresh is currently in progress
    private var isRefreshing = false
    
    // MARK: - Initialization
    
    private init() {
        #if DEBUG
        print("🔄 [AutomaticTokenRefreshService] Initialized")
        #endif
    }
    
    // MARK: - Public API
    
    /**
     * Start automatic token refresh monitoring
     * Should be called when user logs in or app launches with valid session
     */
    func start() {
        guard !isEnabled else {
            #if DEBUG
            print("⚠️ [AutomaticTokenRefreshService] Already started")
            #endif
            return
        }
        
        isEnabled = true
        
        // Perform immediate check
        Task {
            await checkAndRefreshIfNeeded()
        }
        
        // Set up periodic checks
        setupPeriodicChecks()
        
        // Listen to app lifecycle events
        setupAppLifecycleObservers()
        
        #if DEBUG
        print("✅ [AutomaticTokenRefreshService] Started - will check every \(checkInterval)s")
        #endif
    }
    
    /**
     * Stop automatic token refresh monitoring
     * Should be called when user logs out
     */
    func stop() {
        guard isEnabled else { return }
        
        isEnabled = false
        refreshTimer?.invalidate()
        refreshTimer = nil
        cancellables.removeAll()
        lastRefreshAttempt = nil
        
        #if DEBUG
        print("🛑 [AutomaticTokenRefreshService] Stopped")
        #endif
    }
    
    /**
     * Force an immediate token refresh check (useful for testing)
     */
    func forceRefresh() async {
        #if DEBUG
        print("🔄 [AutomaticTokenRefreshService] Force refresh requested")
        #endif
        
        await checkAndRefreshIfNeeded(force: true)
    }
    
    // MARK: - Private Implementation
    
    /**
     * Set up periodic timer to check token expiry
     */
    private func setupPeriodicChecks() {
        // Invalidate existing timer
        refreshTimer?.invalidate()
        
        // Create new timer
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: checkInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkAndRefreshIfNeeded()
            }
        }
        
        // Keep timer running even when app is in background (for a short time)
        RunLoop.current.add(refreshTimer!, forMode: .common)
    }
    
    /**
     * Listen to app lifecycle events to optimize refresh timing
     */
    private func setupAppLifecycleObservers() {
        // Check token when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    #if DEBUG
                    print("🔄 [AutomaticTokenRefreshService] App became active - checking token")
                    #endif
                    await self?.checkAndRefreshIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        // Pause checks when app enters background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { _ in
                #if DEBUG
                print("⏸️ [AutomaticTokenRefreshService] App entered background")
                #endif
                // Timer will continue for a short time, then iOS will suspend it
            }
            .store(in: &cancellables)
    }
    
    /**
     * Check if token needs refresh and perform refresh if necessary
     *
     * - Parameter force: If true, bypass throttling and force refresh
     */
    private func checkAndRefreshIfNeeded(force: Bool = false) async {
        // Prevent concurrent refreshes
        guard !isRefreshing else {
            #if DEBUG
            print("⏭️ [AutomaticTokenRefreshService] Refresh already in progress - skipping")
            #endif
            return
        }
        
        // Throttle refresh attempts to prevent thrashing
        if !force, let lastAttempt = lastRefreshAttempt {
            let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
            if timeSinceLastAttempt < minimumRefreshInterval {
                #if DEBUG
                print("⏭️ [AutomaticTokenRefreshService] Too soon since last attempt (\(Int(timeSinceLastAttempt))s) - skipping")
                #endif
                return
            }
        }
        
        // Check if token needs refresh
        let needsRefresh = await shouldRefreshToken()
        
        guard needsRefresh || force else {
            #if DEBUG
            let expiryInfo = await getTokenExpiryInfo()
            print("✅ [AutomaticTokenRefreshService] Token is fresh - no refresh needed \(expiryInfo)")
            #endif
            return
        }
        
        // Perform refresh
        isRefreshing = true
        lastRefreshAttempt = Date()
        
        #if DEBUG
        print("🔄 [AutomaticTokenRefreshService] Token needs refresh - attempting...")
        #endif
        
        do {
            // Use APIService's public refresh method
            try await APIService.shared.refreshAuthToken()
            
            #if DEBUG
            print("✅ [AutomaticTokenRefreshService] Token refreshed successfully")
            #endif
            
        } catch {
            #if DEBUG
            print("❌ [AutomaticTokenRefreshService] Token refresh failed: \(error)")
            #endif
            
            // If refresh fails with auth error, stop automatic refresh
            // User will need to re-login
            if case APIError.authenticationError = error {
                stop()
                
                // Notify app that user needs to re-login
                NotificationCenter.default.post(
                    name: .userNeedsReAuthentication,
                    object: nil
                )
            }
        }
        
        isRefreshing = false
    }
    
    /**
     * Check if token should be refreshed based on expiry time
     *
     * - Returns: True if token should be refreshed
     */
    private func shouldRefreshToken() async -> Bool {
        // Get token expiry from APIService
        let expiry = await APIService.shared.getTokenExpiry()
        
        guard let expiry = expiry else {
            #if DEBUG
            print("⚠️ [AutomaticTokenRefreshService] No token expiry found")
            #endif
            return false
        }
        
        // Check if token expires within refresh lead time
        let now = Date()
        let refreshThreshold = now.addingTimeInterval(refreshLeadTime)
        
        let shouldRefresh = expiry <= refreshThreshold
        
        #if DEBUG
        let timeUntilExpiry = expiry.timeIntervalSince(now)
        let minutesUntilExpiry = Int(timeUntilExpiry / 60)
        
        if shouldRefresh {
            print("⚠️ [AutomaticTokenRefreshService] Token expires in \(minutesUntilExpiry)m - needs refresh")
        }
        #endif
        
        return shouldRefresh
    }
    
    /**
     * Get human-readable token expiry information (debug only)
     *
     * - Returns: String describing token expiry status
     */
    private func getTokenExpiryInfo() async -> String {
        #if DEBUG
        guard let expiry = await APIService.shared.getTokenExpiry() else {
            return "(no expiry found)"
        }
        
        let timeUntilExpiry = expiry.timeIntervalSince(Date())
        let minutesUntilExpiry = Int(timeUntilExpiry / 60)
        
        if timeUntilExpiry < 0 {
            return "(expired \(abs(minutesUntilExpiry))m ago)"
        } else {
            return "(expires in \(minutesUntilExpiry)m)"
        }
        #else
        return ""
        #endif
    }
}

// MARK: - APIService Extension

extension APIService {
    /**
     * Get current token expiry date (public accessor)
     *
     * - Returns: Token expiry date if available
     */
    func getTokenExpiry() async -> Date? {
        return await self.tokenExpiry
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when user needs to re-authenticate (refresh token expired)
    static let userNeedsReAuthentication = Notification.Name("userNeedsReAuthentication")
}
