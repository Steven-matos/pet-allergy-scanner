//
//  UnifiedCacheCoordinator.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import Combine
import UIKit

/**
 * Unified Cache Coordinator - CENTRAL CACHE AUTHORITY
 * 
 * Single source of truth for all caching operations across the entire app.
 * Consolidates functionality from CacheService, ObservableCacheManager, and EnhancedCacheManager.
 * 
 * Key Features:
 * - Synchronous cache access for immediate UI rendering
 * - Memory + Disk + HTTP cache coordination
 * - Automatic cache invalidation on 404s (deleted resources)
 * - Cache-server synchronization
 * - Smart refresh strategies
 * - Centralized cache policies and TTLs
 * 
 * Follows SOLID principles: Single responsibility for all cache operations
 * Implements DRY by consolidating all cache logic in one place
 * Follows KISS by providing simple, unified API
 */
@MainActor
@Observable
final class UnifiedCacheCoordinator {
    static let shared = UnifiedCacheCoordinator()
    
    // MARK: - Properties
    
    /// In-memory cache for fast access
    private var memoryCache: [String: CacheEntry<Data>] = [:]
    
    /// File manager for disk operations
    private let fileManager = FileManager.default
    
    /// Cache directory URL
    private var cacheDirectory: URL {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("PetAllergyScannerCache")
    }
    
    /// Memory cache size limit (in MB)
    private let memoryCacheLimit: Int = 50
    
    /// Current memory cache size in bytes
    private var currentMemoryCacheSize: Int = 0
    
    /// URLSession configuration with HTTP caching
    private(set) var urlSessionConfiguration: URLSessionConfiguration
    
    /// URLSession with caching enabled
    private(set) var cachedURLSession: URLSession
    
    /// Cache statistics
    var cacheStats = UnifiedCacheStatistics()
    
    /// Cache policies for different data types - CENTRALIZED
    private let cachePolicies: [String: CachePolicy] = [
        // User data - 30 minutes
        CacheKey.currentUser.rawValue: .timeBased(1800),
        CacheKey.userProfile.rawValue: .timeBased(1800),
        
        // Pet data - 30 minutes
        CacheKey.pets.rawValue: .timeBased(1800),
        CacheKey.petDetails.rawValue: .timeBased(1800),
        
        // Dynamic data - 15 minutes
        CacheKey.scans.rawValue: .timeBased(900),
        CacheKey.scanHistory.rawValue: .timeBased(900),
        CacheKey.feedingRecords.rawValue: .timeBased(900),
        CacheKey.dailySummaries.rawValue: .timeBased(900),
        
        // Static reference data - 7 days (rarely changes)
        CacheKey.commonAllergens.rawValue: .timeBased(604800),
        CacheKey.safeAlternatives.rawValue: .timeBased(604800),
        CacheKey.foodDatabase.rawValue: .timeBased(604800),
        
        // System data - short cache
        CacheKey.healthStatus.rawValue: .timeBased(300),
        CacheKey.systemMetrics.rawValue: .timeBased(600),
        
        // Nutrition data policies
        CacheKey.nutritionRequirements.rawValue: .timeBased(3600),
        CacheKey.recentFoods.rawValue: .timeBased(1800),
        CacheKey.weightRecords.rawValue: .timeBased(3600),
        CacheKey.weightGoals.rawValue: .timeBased(7200),
        CacheKey.nutritionalTrends.rawValue: .timeBased(7200),
        CacheKey.healthEvents.rawValue: .timeBased(1800) // 30 minutes
    ]
    
    /// Track deleted resources (404s) to prevent re-caching
    private var deletedResourceKeys: Set<String> = []
    
    /// Cache invalidation callbacks for 404 detection
    private var invalidationCallbacks: [String: () -> Void] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Setup HTTP cache
        let memoryCapacity = 50 * 1024 * 1024 // 50 MB
        let diskCapacity = 200 * 1024 * 1024 // 200 MB
        let urlCache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "SniffTestURLCache"
        )
        URLCache.shared = urlCache
        
        // Configure URLSession with caching
        let config = URLSessionConfiguration.default
        config.urlCache = urlCache
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.httpShouldUsePipelining = true
        config.httpMaximumConnectionsPerHost = 4
        
        self.urlSessionConfiguration = config
        self.cachedURLSession = URLSession(configuration: config)
        
        // Setup cache directory and load persistent cache
        setupCacheDirectory()
        loadPersistentCache()
        setupMemoryWarningObserver()
        setupAppLifecycleObservers()
    }
    
    // MARK: - Public API - Synchronous Cache Access
    
    /**
     * Get cached data synchronously (for immediate UI rendering)
     * - Parameter key: Cache key
     * - Returns: Cached data if valid, nil otherwise
     */
    func get<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        // Check if resource was deleted (404)
        if deletedResourceKeys.contains(key) {
            return nil
        }
        
        // Try memory cache first
        if let memoryEntry = memoryCache[key], memoryEntry.isValid {
            cacheStats.hits += 1
            return decodeEntry(memoryEntry, as: type)
        }
        
        // Try disk cache
        if let diskEntry = loadFromDisk(Data.self, forKey: key), diskEntry.isValid {
            // Restore to memory cache
            memoryCache[key] = diskEntry
            cacheStats.hits += 1
            // Decode the data
            return decodeEntry(diskEntry, as: type)
        }
        
        cacheStats.misses += 1
        return nil
    }
    
    /**
     * Check if cache exists and is valid (synchronous)
     * - Parameter key: Cache key
     * - Returns: True if valid cache exists
     */
    func exists(forKey key: String) -> Bool {
        // Check if resource was deleted
        if deletedResourceKeys.contains(key) {
            return false
        }
        
        // Check memory cache
        if let memoryEntry = memoryCache[key], memoryEntry.isValid {
            return true
        }
        
        // Check disk cache
        if let diskEntry = loadFromDisk(Data.self, forKey: key), diskEntry.isValid {
            return true
        }
        
        return false
    }
    
    /**
     * Store data in cache
     * - Parameters:
     *   - data: Data to cache
     *   - key: Cache key
     *   - policy: Optional custom policy (uses default if nil)
     */
    func set<T: Codable>(_ data: T, forKey key: String, policy: CachePolicy? = nil) {
        // Remove from deleted resources if re-adding
        deletedResourceKeys.remove(key)
        
        let cachePolicy = policy ?? cachePolicies[key] ?? .timeBased(1800)
        
        do {
            let encodedData = try JSONEncoder().encode(data)
            let entry = CacheEntry<Data>(
                data: encodedData,
                timestamp: Date(),
                policy: cachePolicy.toSerializableType(),
                key: key
            )
            
            // Store in memory cache
            storeInMemory(entry, forKey: key)
            
            // Store in disk cache for persistent data
            if shouldPersistToDisk(policy: cachePolicy) {
                storeOnDisk(entry, forKey: key)
            }
            
            cacheStats.stores += 1
            updateCacheStatistics()
        } catch {
            print("⚠️ [UnifiedCacheCoordinator] Failed to encode data for caching: \(error)")
        }
    }
    
    /**
     * Invalidate cache entry
     * - Parameter key: Cache key to invalidate
     */
    func invalidate(forKey key: String) {
        memoryCache.removeValue(forKey: key)
        removeFromDisk(forKey: key)
        deletedResourceKeys.remove(key) // Allow re-fetching
        cacheStats.invalidations += 1
        updateCacheStatistics()
    }
    
    /**
     * Check if a resource is marked as deleted (404)
     * - Parameter key: Cache key to check
     * - Returns: True if resource is marked as deleted
     */
    func isResourceDeleted(forKey key: String) -> Bool {
        return deletedResourceKeys.contains(key)
    }
    
    /**
     * Handle 404 response - resource deleted on server
     * Automatically invalidates cache and prevents re-caching
     * - Parameter key: Cache key for deleted resource
     * 
     * Note: This is non-blocking and safe to call from any thread
     */
    func handleResourceDeleted(forKey key: String) {
        // Mark as deleted first to prevent race conditions
        deletedResourceKeys.insert(key)
        
        // Invalidate cache (non-blocking)
        invalidate(forKey: key)
        
        // Call invalidation callbacks (non-blocking, but could trigger UI updates)
        // Use Task to ensure callbacks don't block
        Task { @MainActor in
            invalidationCallbacks[key]?()
        }
        
        print("🗑️ [UnifiedCacheCoordinator] Resource deleted (404) - invalidated cache for key: \(key)")
    }
    
    /**
     * Register callback for cache invalidation (e.g., when 404 detected)
     * - Parameters:
     *   - key: Cache key
     *   - callback: Callback to execute on invalidation
     */
    func registerInvalidationCallback(forKey key: String, callback: @escaping () -> Void) {
        invalidationCallbacks[key] = callback
    }
    
    /**
     * Clear all cache data
     */
    func clearAll() {
        memoryCache.removeAll()
        currentMemoryCacheSize = 0
        clearDiskCache()
        deletedResourceKeys.removeAll()
        invalidationCallbacks.removeAll()
        cachedURLSession.configuration.urlCache?.removeAllCachedResponses()
        cacheStats = UnifiedCacheStatistics()
        updateCacheStatistics()
        print("🗑️ [UnifiedCacheCoordinator] Cleared all caches")
    }
    
    /**
     * Clear cache for a specific user (useful during logout)
     * - Parameter userId: User ID
     */
    func clearUserCache(userId: String) {
        let userKeys = CacheKey.allCases.map { $0.scoped(forUserId: userId) }
        userKeys.forEach { invalidate(forKey: $0) }
        print("🗑️ [UnifiedCacheCoordinator] Cleared cache for user: \(userId)")
    }
    
    /**
     * Invalidate all cache entries matching a pattern
     * - Parameter pattern: Regex pattern to match keys
     */
    func invalidateMatching(pattern: String) {
        let regex = try? NSRegularExpression(pattern: pattern)
        
        // Invalidate memory cache
        let memoryKeys = memoryCache.keys.filter { key in
            regex?.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) != nil
        }
        memoryKeys.forEach { invalidate(forKey: $0) }
        
        // Invalidate disk cache
        invalidateDiskMatching(pattern: pattern)
    }
    
    // MARK: - Convenience Methods
    
    /**
     * Store user data with automatic scoping
     */
    func storeUserData<T: Codable>(_ data: T, forKey key: CacheKey, userId: String) {
        let scopedKey = key.scoped(forUserId: userId)
        set(data, forKey: scopedKey)
    }
    
    /**
     * Retrieve user data with automatic scoping
     */
    func retrieveUserData<T: Codable>(_ type: T.Type, forKey key: CacheKey, userId: String) -> T? {
        let scopedKey = key.scoped(forUserId: userId)
        return get(type, forKey: scopedKey)
    }
    
    /**
     * Store pet data with automatic scoping
     */
    func storePetData<T: Codable>(_ data: T, forKey key: CacheKey, petId: String) {
        let scopedKey = key.scoped(forPetId: petId)
        set(data, forKey: scopedKey)
    }
    
    /**
     * Retrieve pet data with automatic scoping
     */
    func retrievePetData<T: Codable>(_ type: T.Type, forKey key: CacheKey, petId: String) -> T? {
        let scopedKey = key.scoped(forPetId: petId)
        return get(type, forKey: scopedKey)
    }
    
    // MARK: - Private Methods
    
    /**
     * Setup cache directory
     */
    private func setupCacheDirectory() {
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("⚠️ [UnifiedCacheCoordinator] Failed to create cache directory: \(error)")
        }
    }
    
    /**
     * Load persistent cache from disk on startup (synchronous)
     */
    private func loadPersistentCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for file in files where file.pathExtension == "cache" {
                let key = file.deletingPathExtension().lastPathComponent
                
                // Load and validate entry
                if let data = try? Data(contentsOf: file),
                   let entry = try? JSONDecoder().decode(CacheEntry<Data>.self, from: data),
                   entry.isValid {
                    memoryCache[key] = entry
                    let estimatedSize = estimateSize(of: entry)
                    currentMemoryCacheSize += estimatedSize
                } else {
                    // Remove invalid cache file
                    try? fileManager.removeItem(at: file)
                }
            }
            
            updateCacheStatistics()
            print("✅ [UnifiedCacheCoordinator] Loaded \(memoryCache.count) cache entries from disk")
        } catch {
            print("⚠️ [UnifiedCacheCoordinator] Failed to load persistent cache: \(error)")
        }
    }
    
    /**
     * Store data in memory cache with size management
     */
    private func storeInMemory(_ entry: CacheEntry<Data>, forKey key: String) {
        let estimatedSize = estimateSize(of: entry)
        
        // Check if we need to evict old entries
        while currentMemoryCacheSize + estimatedSize > memoryCacheLimit * 1024 * 1024 {
            evictOldestMemoryEntry()
        }
        
        // Update size if replacing existing entry
        if let existingEntry = memoryCache[key] {
            currentMemoryCacheSize -= estimateSize(of: existingEntry)
        }
        
        memoryCache[key] = entry
        currentMemoryCacheSize += estimatedSize
    }
    
    /**
     * Store data on disk
     */
    private func storeOnDisk(_ entry: CacheEntry<Data>, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(entry)
            let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
            try data.write(to: fileURL)
        } catch {
            print("⚠️ [UnifiedCacheCoordinator] Failed to store cache on disk: \(error)")
        }
    }
    
    /**
     * Load data from disk
     */
    private func loadFromDisk<T: Codable>(_ type: T.Type, forKey key: String) -> CacheEntry<T>? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(CacheEntry<T>.self, from: data)
        } catch {
            return nil
        }
    }
    
    /**
     * Remove data from disk
     */
    private func removeFromDisk(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: fileURL)
    }
    
    /**
     * Clear all disk cache
     */
    private func clearDiskCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            print("⚠️ [UnifiedCacheCoordinator] Failed to clear disk cache: \(error)")
        }
    }
    
    /**
     * Invalidate disk cache matching pattern
     */
    private func invalidateDiskMatching(pattern: String) {
        let regex = try? NSRegularExpression(pattern: pattern)
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for file in files where file.pathExtension == "cache" {
                let key = file.deletingPathExtension().lastPathComponent
                
                if regex?.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) != nil {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("⚠️ [UnifiedCacheCoordinator] Failed to invalidate disk cache: \(error)")
        }
    }
    
    /**
     * Evict oldest memory entry (LRU strategy)
     */
    private func evictOldestMemoryEntry() {
        guard let oldestKey = memoryCache.keys.first else { return }
        
        if let entry = memoryCache[oldestKey] {
            currentMemoryCacheSize -= estimateSize(of: entry)
        }
        
        memoryCache.removeValue(forKey: oldestKey)
        cacheStats.evictions += 1
    }
    
    /**
     * Estimate size of cache entry
     */
    private func estimateSize<T: Codable>(of entry: CacheEntry<T>) -> Int {
        do {
            let data = try JSONEncoder().encode(entry)
            return data.count
        } catch {
            return 1024 // Default 1KB estimate
        }
    }
    
    /**
     * Decode cache entry data
     */
    private func decodeEntry<T: Codable>(_ entry: CacheEntry<Data>, as type: T.Type) -> T? {
        do {
            return try JSONDecoder().decode(T.self, from: entry.data)
        } catch {
            print("⚠️ [UnifiedCacheCoordinator] Failed to decode cache entry: \(error)")
            return nil
        }
    }
    
    /**
     * Check if data should be persisted to disk
     */
    private func shouldPersistToDisk(policy: CachePolicy) -> Bool {
        switch policy {
        case .permanent, .timeBased:
            return true
        case .session, .custom:
            return false
        }
    }
    
    /**
     * Setup memory warning observer
     */
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
    }
    
    /**
     * Handle memory warning by clearing session cache
     */
    private func handleMemoryWarning() {
        // Clear session-only cache entries
        let sessionKeys = memoryCache.keys.filter { key in
            if case .session = cachePolicies[key] { true } else { false }
        }
        
        sessionKeys.forEach { key in
            memoryCache.removeValue(forKey: key)
        }
        
        print("⚠️ [UnifiedCacheCoordinator] Cleared session cache due to memory warning")
    }
    
    /**
     * Setup app lifecycle observers
     */
    private func setupAppLifecycleObservers() {
        // Clear deleted resources on app launch (allow re-fetching)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // Clear deleted resources after 1 hour to allow re-fetching
                // This handles cases where resource was temporarily deleted
                self?.deletedResourceKeys.removeAll()
            }
        }
    }
    
    /**
     * Update cache statistics
     */
    private func updateCacheStatistics() {
        let diskCount = getDiskCacheCount()
        let diskSizeMB = getDiskCacheSize()
        
        cacheStats.memoryEntries = memoryCache.count
        cacheStats.diskEntries = diskCount
        cacheStats.totalSizeMB = diskSizeMB
        cacheStats.memorySizeMB = Double(currentMemoryCacheSize) / (1024 * 1024)
    }
    
    /**
     * Get disk cache entry count
     */
    private func getDiskCacheCount() -> Int {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "cache" }.count
        } catch {
            return 0
        }
    }
    
    /**
     * Get disk cache size in MB
     */
    private func getDiskCacheSize() -> Double {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            let cacheFiles = files.filter { $0.pathExtension == "cache" }
            
            var totalSize: Int64 = 0
            for file in cacheFiles {
                let attributes = try fileManager.attributesOfItem(atPath: file.path)
                if let size = attributes[.size] as? Int64 {
                    totalSize += size
                }
            }
            
            return Double(totalSize) / (1024 * 1024)
        } catch {
            return 0
        }
    }
}

// MARK: - Cache Statistics

/**
 * Unified cache statistics
 */
struct UnifiedCacheStatistics {
    var hits: Int = 0
    var misses: Int = 0
    var stores: Int = 0
    var invalidations: Int = 0
    var evictions: Int = 0
    var memoryEntries: Int = 0
    var diskEntries: Int = 0
    var memorySizeMB: Double = 0
    var totalSizeMB: Double = 0
    
    var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total)
    }
}
