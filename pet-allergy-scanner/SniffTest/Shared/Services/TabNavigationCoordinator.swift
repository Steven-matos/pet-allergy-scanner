//
//  TabNavigationCoordinator.swift
//  SniffTest
//
//  Created to prevent freezing during rapid tab switches
//

import Foundation

/**
 * Tab Navigation Coordinator
 * 
 * Prevents expensive operations during rapid tab switches to avoid freezes and crashes
 * Views should check this coordinator before starting expensive operations in onAppear
 * 
 * Follows SOLID principles with single responsibility for navigation state management
 * Implements DRY by providing centralized navigation state
 * Follows KISS by using simple time-based cooldown mechanism
 */
@MainActor
class TabNavigationCoordinator: ObservableObject {
    static let shared = TabNavigationCoordinator()
    
    @Published private(set) var isInCooldown = false
    @Published private(set) var lastTabChangeTime: Date?
    
    private var cooldownTask: Task<Void, Never>?
    
    private init() {}
    
    /**
     * Record a tab change and start cooldown if rapid switch detected
     * - Parameter fromTab: Previous tab index
     * - Parameter toTab: New tab index
     */
    func recordTabChange(fromTab: Int, toTab: Int) {
        let now = Date()
        let tabNames = ["Pets", "Trackers", "Scan", "Nutrition", "Profile"]
        let fromTabName = fromTab < tabNames.count ? tabNames[fromTab] : "Unknown"
        let toTabName = toTab < tabNames.count ? tabNames[toTab] : "Unknown"
        
        // Detect problematic switches (these have expensive operations)
        // These combinations have expensive operations that can cause freezes when switching rapidly
        let isProblematicSwitch = (fromTabName == "Profile" && toTabName == "Nutrition") || 
                                 (fromTabName == "Nutrition" && toTabName == "Profile") ||
                                 (fromTabName == "Pets" && toTabName == "Trackers") ||
                                 (fromTabName == "Trackers" && toTabName == "Pets") ||
                                 (fromTabName == "Nutrition" && toTabName == "Trackers") ||
                                 (fromTabName == "Trackers" && toTabName == "Nutrition")
        
        // Check if rapid switch (< 0.5 seconds)
        let isRapidSwitch: Bool
        if let lastChange = lastTabChangeTime {
            isRapidSwitch = now.timeIntervalSince(lastChange) < 0.5
        } else {
            isRapidSwitch = false
        }
        
        if isRapidSwitch {
            // ANY rapid switch triggers cooldown - this catches all edge cases
            let timeSinceLastChange = lastTabChangeTime.map { now.timeIntervalSince($0) } ?? 0
            print("⚠️ TabNavigationCoordinator: Rapid switch detected from \(fromTabName) to \(toTabName) (\(String(format: "%.2f", timeSinceLastChange))s) - starting cooldown")
            
            // Cancel any existing cooldown
            cooldownTask?.cancel()
            
            // Start cooldown period - longer for problematic switches
            isInCooldown = true
            let cooldownDuration: UInt64 = isProblematicSwitch ? 700_000_000 : 500_000_000 // 0.7s for problematic, 0.5s for others
            cooldownTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: cooldownDuration)
                guard !Task.isCancelled else { return }
                isInCooldown = false
                print("✅ TabNavigationCoordinator: Cooldown ended")
            }
        } else if isProblematicSwitch {
            // Problematic switch but not rapid - shorter cooldown to be safe
            print("⚠️ TabNavigationCoordinator: Problematic switch from \(fromTabName) to \(toTabName) - starting short cooldown")
            isInCooldown = true
            cooldownTask?.cancel()
            cooldownTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                guard !Task.isCancelled else { return }
                isInCooldown = false
            }
        }
        
        lastTabChangeTime = now
    }
    
    /**
     * Check if operations should be blocked due to cooldown
     * Views should call this before starting expensive operations
     */
    func shouldBlockOperations() -> Bool {
        return isInCooldown
    }
    
    /**
     * Wait for cooldown to end if currently active
     * Views can call this to ensure cooldown completes before proceeding
     */
    func waitForCooldownIfNeeded() async {
        guard isInCooldown else { return }
        
        // Wait until cooldown ends
        while isInCooldown {
            try? await Task.sleep(nanoseconds: 50_000_000) // Check every 0.05 seconds
            await Task.yield()
        }
    }
}

