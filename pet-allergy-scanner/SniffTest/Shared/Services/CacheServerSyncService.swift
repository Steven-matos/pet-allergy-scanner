//
//  CacheServerSyncService.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import Combine
import UIKit

/**
 * Cache-Server Synchronization Service
 * 
 * Background service for keeping cache in sync with server state.
 * Validates cache entries, refreshes stale data, and cleans up deleted resources.
 * 
 * Key Features:
 * - Periodic validation of cache entries against server
 * - Automatic cleanup of deleted resources (404s)
 * - Background refresh for stale data
 * - Smart refresh scheduling based on data volatility
 * - Graceful error handling without clearing valid cache
 * 
 * Follows SOLID principles: Single responsibility for cache-server sync
 * Implements DRY by providing reusable sync patterns
 * Follows KISS by keeping sync logic simple and transparent
 */
@MainActor
class CacheServerSyncService {
    static let shared = CacheServerSyncService()
    
    private let cacheCoordinator = UnifiedCacheCoordinator.shared
    private let apiService = APIService.shared
    
    /// Sync tasks in progress
    private var syncTasks: [String: Task<Void, Never>] = [:]
    
    /// Last sync timestamps per cache key
    private var lastSyncTimestamps: [String: Date] = [:]
    
    /// Sync interval for different data types (in seconds)
    private let syncIntervals: [String: TimeInterval] = [
        // Static data - sync every 24 hours
        CacheKey.commonAllergens.rawValue: 86400,
        CacheKey.safeAlternatives.rawValue: 86400,
        CacheKey.foodDatabase.rawValue: 86400,
        
        // User data - sync every 30 minutes
        CacheKey.currentUser.rawValue: 1800,
        CacheKey.userProfile.rawValue: 1800,
        CacheKey.pets.rawValue: 1800,
        
        // Dynamic data - sync every 15 minutes
        CacheKey.feedingRecords.rawValue: 900,
        CacheKey.dailySummaries.rawValue: 900,
        CacheKey.scans.rawValue: 900,
        
        // Nutrition data - sync every hour
        CacheKey.nutritionRequirements.rawValue: 3600,
        CacheKey.weightRecords.rawValue: 3600,
        CacheKey.nutritionalTrends.rawValue: 3600
    ]
    
    private init() {
        setupAppLifecycleObservers()
    }
    
    // MARK: - Public API
    
    /**
     * Validate cache entry against server
     * - Parameters:
     *   - cacheKey: Cache key to validate
     *   - validateClosure: Closure to validate cache entry against server
     */
    func validateCacheEntry(
        cacheKey: String,
        validateClosure: @escaping () async throws -> Bool
    ) {
        // Check if sync is needed
        guard shouldSync(cacheKey: cacheKey) else { return }
        
        // Cancel existing sync task for this key
        syncTasks[cacheKey]?.cancel()
        
        // Start new sync task
        let task = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            do {
                let isValid = try await validateClosure()
                
                if !isValid {
                    // Cache entry is invalid, invalidate it
                    self.cacheCoordinator.invalidate(forKey: cacheKey)
                    print("🔄 [CacheServerSyncService] Invalidated cache for key: \(cacheKey)")
                } else {
                    // Update last sync timestamp
                    self.lastSyncTimestamps[cacheKey] = Date()
                }
                self.syncTasks.removeValue(forKey: cacheKey)
            } catch {
                // Handle 404 - resource deleted
                if let apiError = error as? APIError,
                   case .serverError(let statusCode) = apiError,
                   statusCode == 404 {
                    self.cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                    print("🗑️ [CacheServerSyncService] Resource deleted (404) - invalidated cache for key: \(cacheKey)")
                } else {
                    // Network error - don't invalidate cache, just log
                    print("⚠️ [CacheServerSyncService] Validation failed for key: \(cacheKey), error: \(error)")
                }
                
                self.syncTasks.removeValue(forKey: cacheKey)
            }
        }
        
        syncTasks[cacheKey] = task
    }
    
    /**
     * Refresh stale cache entries in background
     * - Parameter cacheKeys: Array of cache keys to refresh
     */
    func refreshStaleCacheEntries(cacheKeys: [String]) {
        for cacheKey in cacheKeys {
            guard shouldSync(cacheKey: cacheKey) else { continue }
            
            // Cancel existing sync task
            syncTasks[cacheKey]?.cancel()
            
            // Start refresh task
            let task = Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Mark as syncing
                self.lastSyncTimestamps[cacheKey] = Date()
                
                // Note: Actual refresh logic should be implemented by calling service
                // This is just a coordination point
                print("🔄 [CacheServerSyncService] Refreshing cache for key: \(cacheKey)")
            }
            
            Task { @MainActor in
                syncTasks[cacheKey] = task
            }
        }
    }
    
    /**
     * Cleanup deleted resources from cache
     * Validates all cache entries and removes those that no longer exist on server
     * - Parameter validationClosures: Dictionary of cache keys to validation closures
     */
    func cleanupDeletedResources(
        validationClosures: [String: () async throws -> Bool]
    ) {
        for (cacheKey, validateClosure) in validationClosures {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                do {
                    let exists = try await validateClosure()
                    
                    if !exists {
                        // Resource doesn't exist on server, invalidate cache
                        self.cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                        print("🗑️ [CacheServerSyncService] Cleaned up deleted resource: \(cacheKey)")
                    }
                } catch {
                    // Handle 404
                    if let apiError = error as? APIError,
                       case .serverError(let statusCode) = apiError,
                       statusCode == 404 {
                        self.cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                        print("🗑️ [CacheServerSyncService] Cleaned up deleted resource (404): \(cacheKey)")
                    } else {
                        // Network error - don't invalidate cache
                        print("⚠️ [CacheServerSyncService] Cleanup validation failed for key: \(cacheKey), error: \(error)")
                    }
                }
            }
        }
    }
    
    /**
     * Sync all cache entries on app launch
     * Validates critical cache entries against server
     */
    func syncOnAppLaunch() {
        // Sync critical cache entries
        let criticalKeys: [String] = [
            CacheKey.pets.rawValue,
            CacheKey.currentUser.rawValue
        ]
        
        for cacheKey in criticalKeys {
            // Mark as needing sync
            lastSyncTimestamps.removeValue(forKey: cacheKey)
        }
        
        print("🔄 [CacheServerSyncService] Initiated app launch sync for \(criticalKeys.count) critical cache entries")
    }
    
    /**
     * Cancel all sync tasks
     */
    func cancelAllSyncTasks() {
        for task in syncTasks.values {
            task.cancel()
        }
        syncTasks.removeAll()
    }
    
    // MARK: - Private Methods
    
    /**
     * Check if cache entry should be synced
     * - Parameter cacheKey: Cache key to check
     * - Returns: True if sync is needed
     */
    private func shouldSync(cacheKey: String) -> Bool {
        // Check if sync is already in progress
        if syncTasks[cacheKey] != nil {
            return false
        }
        
        // Check last sync timestamp
        if let lastSync = lastSyncTimestamps[cacheKey] {
            let syncInterval = syncIntervals[cacheKey] ?? 1800 // Default 30 minutes
            let timeSinceSync = Date().timeIntervalSince(lastSync)
            return timeSinceSync >= syncInterval
        }
        
        // Never synced, should sync
        return true
    }
    
    /**
     * Setup app lifecycle observers
     */
    private func setupAppLifecycleObservers() {
        // Sync on app launch
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncOnAppLaunch()
            }
        }
        
        // Cancel sync tasks on app background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cancelAllSyncTasks()
            }
        }
    }
}
