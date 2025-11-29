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
     */
    private func startPolling() {
        guard syncTimer == nil else { return }
        
        let interval = currentPollInterval()
        print("⏱️ Starting poll timer - interval: \(Int(interval))s")
        
        // Perform immediate sync
        Task {
            await performSync()
        }
        
        // Setup recurring timer
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
     */
    private func performSync() async {
        guard !activePets.isEmpty else { return }
        guard !isSyncing else {
            print("⏭️ Sync already in progress, skipping")
            return
        }
        
        isSyncing = true
        syncError = nil
        
        print("🔄 Syncing data for \(activePets.count) pet(s)")
        
        // Sync each active pet
        for petId in activePets {
            do {
                // Check if we have cached data
                let hadData = weightService.hasCachedWeightData(for: petId)
                let oldRecordCount = weightService.weightHistory(for: petId).count
                
                // Force refresh from server (bypasses cache)
                try await weightService.refreshWeightData(petId: petId)
                
                // Check if data changed
                let newRecordCount = weightService.weightHistory(for: petId).count
                
                if newRecordCount != oldRecordCount {
                    print("✅ Data updated for pet \(petId): \(oldRecordCount) → \(newRecordCount) records")
                } else if !hadData && newRecordCount > 0 {
                    print("✅ New data loaded for pet \(petId): \(newRecordCount) records")
                } else {
                    print("ℹ️ No changes for pet \(petId)")
                }
                
            } catch {
                print("❌ Sync failed for pet \(petId): \(error.localizedDescription)")
                syncError = error
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

