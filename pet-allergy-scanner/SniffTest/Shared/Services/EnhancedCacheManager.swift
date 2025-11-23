//
//  EnhancedCacheManager.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import Combine
import UIKit

/**
 * Enhanced Cache Manager - Swift/SwiftUI 2025 Best Practices
 * 
 * Implements multi-layer caching strategy:
 * 1. URLSession-level HTTP caching (URLCache)
 * 2. Application-level memory cache (NSCache)
 * 3. Disk persistence for static data
 * 
 * Features:
 * - Automatic cache invalidation on app lifecycle events
 * - Smart cache refresh on sign-in and app launch
 * - Long-term caching for static reference data
 * - Background cache warming
 * 
 * Follows SOLID principles: Single responsibility for cache coordination
 * Implements DRY by reusing existing cache infrastructure
 * Follows KISS by keeping cache policies simple and transparent
 */
@MainActor
@Observable
final class EnhancedCacheManager {
    static let shared = EnhancedCacheManager()
    
    // MARK: - Properties
    
    /// URLSession configuration with optimized caching
    private(set) var urlSessionConfiguration: URLSessionConfiguration
    
    /// URLSession with caching enabled
    private(set) var cachedURLSession: URLSession
    
    /// Cache statistics
    var cacheStats: EnhancedCacheStatistics = EnhancedCacheStatistics()
    
    /// Last cache refresh timestamp
    var lastRefreshDate: Date?
    
    /// Is cache refresh in progress
    var isRefreshing = false
    
    // MARK: - Cache Policies
    
    /**
     * Cache duration constants for different data types
     * Static data: 7 days (allergens, safe alternatives, nutritional standards)
     * User data: 30 minutes (pets, profile)
     * Dynamic data: 15 minutes (scans, feeding logs)
     */
    enum CacheDuration {
        static let staticData: TimeInterval = 7 * 24 * 60 * 60 // 7 days
        static let userData: TimeInterval = 30 * 60 // 30 minutes
        static let dynamicData: TimeInterval = 15 * 60 // 15 minutes
        static let sessionData: TimeInterval = 0 // Session only (memory)
    }
    
    // MARK: - Initialization
    
    private init() {
        // Configure URLCache for HTTP-level caching
        let memoryCapacity = 50 * 1024 * 1024 // 50 MB
        let diskCapacity = 200 * 1024 * 1024 // 200 MB
        let cache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "SniffTestURLCache"
        )
        
        // Set as shared cache for URLSession
        URLCache.shared = cache
        
        // Configure URLSession with caching
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad // Use cache if available, else load
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        
        // Enable HTTP caching headers
        config.httpShouldUsePipelining = true
        config.httpMaximumConnectionsPerHost = 4
        
        self.urlSessionConfiguration = config
        self.cachedURLSession = URLSession(configuration: config)
        
        setupAppLifecycleObservers()
        updateCacheStatistics()
    }
    
    // MARK: - Public API
    
    /**
     * Get cached data with automatic refresh if stale
     * - Parameter key: Cache key
     * - Parameter maxAge: Maximum age in seconds before refresh
     * - Returns: Cached data if available and valid
     */
    func getCachedData<T: Codable>(_ type: T.Type, forKey key: String, maxAge: TimeInterval) -> T? {
        // Check application-level cache first
        if let cached = CacheService.shared.retrieve(type, forKey: key) {
            // Check if cache is still valid
            if let entry = CacheService.shared.retrieve(CacheEntry<Data>.self, forKey: "\(key)_entry") {
                let age = Date().timeIntervalSince(entry.timestamp)
                if age < maxAge {
                    cacheStats.hits += 1
                    return cached
                }
            } else {
                // No entry metadata, assume valid if exists
                cacheStats.hits += 1
                return cached
            }
        }
        
        cacheStats.misses += 1
        return nil
    }
    
    /**
     * Store data in cache with metadata
     * - Parameter data: Data to cache
     * - Parameter key: Cache key
     * - Parameter duration: Cache duration
     */
    func storeData<T: Codable>(_ data: T, forKey key: String, duration: TimeInterval) {
        let policy: CachePolicy = duration > 0 ? .timeBased(duration) : .session
        
        // Store data
        CacheService.shared.store(data, forKey: key, policy: policy)
        
        // Store metadata entry (encode data to Data for storage)
        do {
            let encodedData = try JSONEncoder().encode(data)
            let entry = CacheEntry<Data>(
                data: encodedData,
                timestamp: Date(),
                policy: policy.toSerializableType(),
                key: key
            )
            CacheService.shared.store(entry, forKey: "\(key)_entry", policy: .permanent)
        } catch {
            // If encoding fails, just store the data without metadata
            print("⚠️ Failed to encode cache entry metadata: \(error)")
        }
        
        updateCacheStatistics()
    }
    
    /**
     * Invalidate cache for a specific key
     * - Parameter key: Cache key to invalidate
     */
    func invalidateCache(forKey key: String) {
        CacheService.shared.invalidate(forKey: key)
        CacheService.shared.invalidate(forKey: "\(key)_entry")
        updateCacheStatistics()
    }
    
    /**
     * Refresh static reference data (allergens, safe alternatives, etc.)
     * Called on app launch and sign-in
     */
    func refreshStaticData() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        let apiService = APIService.shared
        
        do {
            // Refresh common allergens (static data - 7 day cache)
            let allergens = try await apiService.getCommonAllergens()
            storeData(allergens, forKey: CacheKey.commonAllergens.rawValue, duration: CacheDuration.staticData)
            
            // Refresh safe alternatives (static data - 7 day cache)
            let safeAlternatives = try await apiService.getSafeAlternatives()
            storeData(safeAlternatives, forKey: CacheKey.safeAlternatives.rawValue, duration: CacheDuration.staticData)
            
            lastRefreshDate = Date()
            print("✅ Refreshed static reference data")
        } catch {
            print("⚠️ Failed to refresh static data: \(error.localizedDescription)")
        }
    }
    
    /**
     * Clear all caches (called on logout)
     */
    func clearAllCaches() {
        CacheService.shared.clearAll()
        
        // Clear URLSession cache
        cachedURLSession.configuration.urlCache?.removeAllCachedResponses()
        
        cacheStats = EnhancedCacheStatistics()
        lastRefreshDate = nil
        
        print("🗑️ Cleared all caches")
    }
    
    /**
     * Warm cache with frequently accessed data
     * Called in background after app launch
     */
    func warmCache() async {
        guard AuthService.shared.currentUser != nil else { return }
        
        // Refresh static data in background
        await refreshStaticData()
        
        // Preload user data if available
        if let userId = AuthService.shared.currentUser?.id {
            await preloadUserData(userId: userId)
        }
    }
    
    /**
     * Check if cache needs refresh based on last refresh time
     * - Returns: True if cache should be refreshed
     */
    func shouldRefreshCache() -> Bool {
        guard let lastRefresh = lastRefreshDate else { return true }
        
        // Refresh if last refresh was more than 1 hour ago
        let timeSinceRefresh = Date().timeIntervalSince(lastRefresh)
        return timeSinceRefresh > 3600 // 1 hour
    }
    
    // MARK: - Private Methods
    
    /**
     * Setup app lifecycle observers for cache management
     */
    private func setupAppLifecycleObservers() {
        // Refresh cache when app becomes active after being in background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppBecameActive()
            }
        }
        
        // Clear session cache on memory warning
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
        
        // Observe sign-in events
        NotificationCenter.default.addObserver(
            forName: .userDidLogin,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleUserSignIn()
            }
        }
        
        // Observe sign-out events
        NotificationCenter.default.addObserver(
            forName: .userDidLogout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleUserSignOut()
            }
        }
    }
    
    /**
     * Handle app becoming active
     */
    private func handleAppBecameActive() async {
        // Refresh static data if stale
        if shouldRefreshCache() {
            await refreshStaticData()
        }
        
        // Warm cache in background
        Task.detached(priority: .background) {
            await EnhancedCacheManager.shared.warmCache()
        }
    }
    
    /**
     * Handle memory warning
     */
    private func handleMemoryWarning() {
        // Clear session-only cache entries
        let sessionKeys = CacheKey.allCases.filter { key in
            // Clear session data, keep persistent data
            switch key {
            case .scans, .scanHistory:
                return true
            default:
                return false
            }
        }
        
        sessionKeys.forEach { key in
            CacheService.shared.invalidate(forKey: key.rawValue)
        }
        
        print("⚠️ Cleared session cache due to memory warning")
    }
    
    /**
     * Handle user sign-in
     */
    private func handleUserSignIn() async {
        // Refresh all caches on sign-in
        await refreshStaticData()
        
        // Warm user-specific cache
        if let userId = AuthService.shared.currentUser?.id {
            await preloadUserData(userId: userId)
        }
    }
    
    /**
     * Handle user sign-out
     */
    private func handleUserSignOut() {
        clearAllCaches()
    }
    
    /**
     * Preload user-specific data
     * - Parameter userId: User ID
     */
    private func preloadUserData(userId: String) async {
        // Preload pets (foundation for other data)
        let petService = CachedPetService.shared
        petService.loadPets(forceRefresh: false)
        
        // Wait a bit for pets to load
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Preload pet-specific data if pets exist
        guard !petService.pets.isEmpty else { return }
        
        // Preload in parallel for all pets
        await withTaskGroup(of: Void.self) { group in
            for pet in petService.pets {
                group.addTask { [weak self] in
                    await self?.preloadPetData(petId: pet.id)
                }
            }
        }
    }
    
    /**
     * Preload data for a specific pet
     * - Parameter petId: Pet ID
     */
    private func preloadPetData(petId: String) async {
        // Preload weight data
        let weightService = CachedWeightTrackingService.shared
        try? await weightService.loadWeightData(for: petId)
        
        // Preload nutrition data
        let nutritionService = CachedNutritionService.shared
        try? await nutritionService.loadFeedingRecords(for: petId)
    }
    
    /**
     * Update cache statistics
     */
    private func updateCacheStatistics() {
        let stats = CacheService.shared.getCacheStats()
        cacheStats.memoryEntries = stats["memory_entries"] as? Int ?? 0
        cacheStats.diskEntries = stats["disk_entries"] as? Int ?? 0
        cacheStats.totalSizeMB = Double(stats["disk_size_mb"] as? String ?? "0") ?? 0
    }
}

// MARK: - Enhanced Cache Statistics

/**
 * Enhanced cache statistics for monitoring
 * Separate from CacheStatistics in CacheModels to avoid conflicts
 */
struct EnhancedCacheStatistics {
    var hits: Int = 0
    var misses: Int = 0
    var memoryEntries: Int = 0
    var diskEntries: Int = 0
    var totalSizeMB: Double = 0
    
    var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total)
    }
}

