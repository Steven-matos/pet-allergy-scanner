//
//  DailyScanCounter.swift
//  SniffTest
//
//  Service for tracking daily scan usage for free tier limits
//

import Foundation

/// Service for tracking daily scan counts
@MainActor
class DailyScanCounter: ObservableObject {
    static let shared = DailyScanCounter()
    
    @Published private(set) var todaysScanCount: Int = 0
    
    private let userDefaults = UserDefaults.standard
    private let scanCountKey = "dailyScanCount"
    private let lastScanDateKey = "lastScanDate"
    
    private init() {
        loadTodaysScanCount()
    }
    
    /// Load today's scan count from UserDefaults
    private func loadTodaysScanCount() {
        let lastScanDate = userDefaults.object(forKey: lastScanDateKey) as? Date ?? Date.distantPast
        
        // Check if last scan was today
        if Calendar.current.isDateInToday(lastScanDate) {
            todaysScanCount = userDefaults.integer(forKey: scanCountKey)
        } else {
            // New day, reset counter
            todaysScanCount = 0
            userDefaults.set(0, forKey: scanCountKey)
            userDefaults.set(Date(), forKey: lastScanDateKey)
        }
    }
    
    /// Increment scan count for today
    func incrementScanCount() {
        let now = Date()
        let lastScanDate = userDefaults.object(forKey: lastScanDateKey) as? Date ?? Date.distantPast
        
        // Check if we need to reset for new day
        if !Calendar.current.isDateInToday(lastScanDate) {
            todaysScanCount = 0
        }
        
        todaysScanCount += 1
        userDefaults.set(todaysScanCount, forKey: scanCountKey)
        userDefaults.set(now, forKey: lastScanDateKey)
    }
    
    /// Reset scan count (useful for testing or manual reset)
    func resetScanCount() {
        todaysScanCount = 0
        userDefaults.set(0, forKey: scanCountKey)
        userDefaults.set(Date(), forKey: lastScanDateKey)
    }
    
    /// Get remaining scans for free tier users
    /// - Returns: Number of scans remaining today, or nil for premium users
    func getRemainingScans() -> Int? {
        let gatekeeper = SubscriptionGatekeeper.shared
        return gatekeeper.getRemainingDailyScans(currentDailyScans: todaysScanCount)
    }
    
    /// Check if user can perform another scan
    /// - Returns: True if scan is allowed, false if limit reached
    func canPerformScan() -> Bool {
        let gatekeeper = SubscriptionGatekeeper.shared
        return gatekeeper.canPerformScan(currentDailyScans: todaysScanCount)
    }
}

