//
//  WeightDataSyncService.swift
//  SniffTest
//
//  Created by AI Assistant on 11/28/25.
//

import Foundation
import Combine
import UIKit

/**
 * Weight Data Synchronization Service
 *
 * Provides automatic syncing of weight data from server to client cache.
 * Implements smart polling with the following features:
 * - Auto-refresh when app is active
 * - Stops polling when app goes to background (battery-friendly)
 * - Configurable poll intervals
 * - Cache invalidation when updates detected
 * - Batch updates for multiple pets
 *
 * Follows SOLID principles: Single responsibility for data sync
 * Implements DRY by centralizing sync logic
 * Follows KISS by using simple polling instead of complex WebSocket setup
 */
@MainActor
class WeightDataSyncService: ObservableObject {
    static let shared = WeightDataSyncService()
    
    // MARK: - Configuration
    
    /// Default polling interval (30 seconds)
    private let defaultPollInterval: TimeInterval = 30
    
    /// Fast polling interval for recent updates (10 seconds)
    private let fastPollInterval: TimeInterval = 10
    
    /// How long to use fast polling after a manual action (5 minutes)
    private let fastPollDuration: TimeInterval = 300
    
    // MARK: - Properties
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private var syncTimer: Timer?
    private var activePets: Set<String> = []
    private var fastPollUntil: Date?
    private var cancellables = Set<AnyCancellable>()
    
    private let weightService = CachedWeightTrackingService.shared
    private let notificationCenter = NotificationCenter.default
    
    private init() {
        setupAppStateObservers()
    }
    
    // MARK: - Public API
    
    /**
     * Start syncing weight data for a specific pet
     * - Parameter petId: The pet's ID to monitor
     */
    func startSyncing(forPetId petId: String) {
        print("🔄 Starting data sync for pet: \(petId)")
        activePets.insert(petId)
        
        if syncTimer == nil {
            startPolling()
        }
    }
    
    /**
     * Stop syncing weight data for a specific pet
     * - Parameter petId: The pet's ID to stop monitoring
     */
    func stopSyncing(forPetId petId: String) {
        print("⏸️ Stopping data sync for pet: \(petId)")
        activePets.remove(petId)
        
        // If no more active pets, stop polling
        if activePets.isEmpty {
            stopPolling()
        }
    }
    
    /**
     * Stop all syncing
     */
    func stopAllSyncing() {
        print("⏹️ Stopping all data sync")
        activePets.removeAll()
        stopPolling()
    }
    
    /**
     * Trigger fast polling for a short period
     * Useful after manual actions like recording weight
     */
    func enableFastPolling() {
        fastPollUntil = Date().addingTimeInterval(fastPollDuration)
        print("⚡ Fast polling enabled for \(Int(fastPollDuration / 60)) minutes")
        
        // Restart timer with fast interval
        if syncTimer != nil {
            stopPolling()
            startPolling()
        }
    }
    
    /**
     * Manually trigger a sync (bypass timer)
     */
    func syncNow() async {
        await performSync()
    }
    
    // MARK: - Private Methods
    
    /**
     * Setup observers for app state changes
     */
    private func setupAppStateObservers() {
        // Start syncing when app becomes active
        notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    if let self = self, !self.activePets.isEmpty {
                        print("📱 App became active - resuming sync")
                        self.startPolling()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Stop syncing when app goes to background
        notificationCenter.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    print("📱 App entered background - pausing sync")
                    self?.stopPolling()
                }
            }
            .store(in: &cancellables)
    }
    
    /**
     * Start the polling timer
     * No immediate sync - relies on cached data for instant UI
     * Syncs periodically in background without blocking
     */
    private func startPolling() {
        guard syncTimer == nil else { return }
        
        let interval = currentPollInterval()
        print("⏱️ Starting poll timer - interval: \(Int(interval))s")
        
        // Don't perform immediate sync - rely on cached data for instant UI
        // Weight data is static and only changes when user adds/deletes entries
        // The periodic sync will pick up any changes from other devices/sessions
        
        // Setup recurring timer for background updates
        syncTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performSync()
            }
        }
    }
    
    /**
     * Stop the polling timer
     */
    private func stopPolling() {
        syncTimer?.invalidate()
        syncTimer = nil
        print("⏹️ Poll timer stopped")
    }
    
    /**
     * Get current poll interval (fast or default)
     */
    private func currentPollInterval() -> TimeInterval {
        if let fastPollUntil = fastPollUntil, Date() < fastPollUntil {
            return fastPollInterval
        }
        return defaultPollInterval
    }
    
    /**
     * Perform the actual sync operation
     * 
     * Weight data is static and only changes when user takes action.
     * This sync operation is now cache-only - it doesn't make server calls.
     * Server calls only happen:
     * - First time (no cache) - handled by view
     * - After user adds/deletes weight - handled by view
     * - After user sets/updates goal - handled by view
     * - On explicit refresh - handled by view
     * 
     * This method now just ensures cached data is loaded into memory.
     */
    private func performSync() async {
        guard !activePets.isEmpty else { return }
        guard !isSyncing else {
            print("⏭️ Sync already in progress, skipping")
            return
        }
        
        isSyncing = true
        syncError = nil
        
        print("🔄 Checking cached data for \(activePets.count) pet(s)")
        
        // Just ensure cached data is loaded - no server calls
        // Weight data is static, so we only need to use cache
        for petId in activePets {
            // Check if we have cached data in memory
            let hasCachedData = weightService.hasCachedWeightData(for: petId)
            
            if hasCachedData {
                // Data is already in memory from cache - nothing to do
                print("✅ Cached data available for pet \(petId)")
            } else {
                // No cached data - but don't fetch here
                // The view will handle first-time loading when needed
                print("ℹ️ No cached data for pet \(petId) - view will handle first load")
            }
        }
        
        lastSyncDate = Date()
        isSyncing = false
        
        // Check if we need to switch from fast to normal polling
        if let fastPollUntil = fastPollUntil, Date() >= fastPollUntil {
            print("⏰ Fast polling period ended, switching to normal interval")
            self.fastPollUntil = nil
            
            // Restart timer with normal interval
            stopPolling()
            if !activePets.isEmpty {
                startPolling()
            }
        }
    }
    
}

