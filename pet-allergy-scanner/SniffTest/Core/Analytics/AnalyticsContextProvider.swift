//
//  AnalyticsContextProvider.swift
//  SniffTest
//
//  Provides global context properties that are automatically attached to all analytics events
//  Follows PostHog best practices for consistent event properties
//

import Foundation
import UIKit
import Network
import os.log

/// Provides global context properties for analytics events
/// Auto-attaches device info, app version, network status, and user/pet context
@MainActor
class AnalyticsContextProvider {
    static let shared = AnalyticsContextProvider()
    
    private let logger = Logger(subsystem: "com.snifftest.app", category: "AnalyticsContext")
    
    // MARK: - Session Management
    
    /// Session ID (UUID per app session)
    private var sessionId: String = UUID().uuidString
    private var sessionStartTime: Date = Date()
    
    /// Current pet context (set when user selects a pet)
    private var currentPetId: String?
    
    /// Current user ID (set when user is identified)
    private var currentUserId: String?
    
    // MARK: - Network Monitoring
    
    private var networkMonitor: NWPathMonitor?
    private var networkQueue = DispatchQueue(label: "com.snifftest.networkmonitor")
    private var currentNetworkType: String = "unknown"
    
    private init() {
        setupNetworkMonitoring()
        resetSession()
    }
    
    // MARK: - Public Methods
    
    /// Get current pet ID from context
    var currentPetIdValue: String? {
        return currentPetId
    }
    
    /// Get current user ID from context
    var currentUserIdValue: String? {
        return currentUserId
    }
    
    /// Get current context properties to attach to events
    /// - Returns: Dictionary of global properties
    func getContext() -> [String: Any] {
        var context: [String: Any] = [:]
        
        // App version info
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            context["app_version"] = appVersion
        }
        
        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            context["app_build"] = buildNumber
        }
        
        // Environment
        context["environment"] = Configuration.environment.rawValue
        
        // Device info
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0)
            }
        } ?? "unknown"
        context["device_model"] = modelCode
        context["device_type"] = UIDevice.current.model
        context["ios_version"] = UIDevice.current.systemVersion
        
        // Network type
        context["network_type"] = currentNetworkType
        
        // Low power mode
        if #available(iOS 9.0, *) {
            context["is_low_power_mode"] = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        
        // Locale and timezone
        context["locale"] = Locale.current.identifier
        context["timezone"] = TimeZone.current.identifier
        
        // Session info
        context["session_id"] = sessionId
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        context["session_duration_seconds"] = Int(sessionDuration)
        
        // User context (if identified)
        if let userId = currentUserId {
            context["user_id"] = userId
        }
        
        // Pet context (if pet is selected)
        if let petId = currentPetId {
            context["pet_id"] = petId
        }
        
        return context
    }
    
    /// Set current user ID for context
    /// - Parameter userId: User ID from authentication
    func setUserId(_ userId: String?) {
        currentUserId = userId
        logger.debug("User context set: \(userId ?? "nil")")
    }
    
    /// Set current pet ID for context
    /// - Parameter petId: Pet ID when user selects a pet
    func setPetId(_ petId: String?) {
        currentPetId = petId
        logger.debug("Pet context set: \(petId ?? "nil")")
    }
    
    /// Reset session (call on app launch or when user logs out)
    func resetSession() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        let newSessionId = sessionId
        logger.debug("Session reset: \(newSessionId)")
    }
    
    /// Clear user context (call on logout)
    func clearUserContext() {
        currentUserId = nil
        currentPetId = nil
        resetSession()
        logger.debug("User context cleared")
    }
    
    // MARK: - Private Methods
    
    /// Setup network monitoring to track connectivity type
    private func setupNetworkMonitoring() {
        networkMonitor = NWPathMonitor()
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        self.currentNetworkType = "wifi"
                    } else if path.usesInterfaceType(.cellular) {
                        self.currentNetworkType = "cellular"
                    } else {
                        self.currentNetworkType = "other"
                    }
                } else {
                    self.currentNetworkType = "none"
                }
                self.logger.debug("Network type updated: \(self.currentNetworkType)")
            }
        }
        networkMonitor?.start(queue: networkQueue)
    }
    
    deinit {
        networkMonitor?.cancel()
    }
}
