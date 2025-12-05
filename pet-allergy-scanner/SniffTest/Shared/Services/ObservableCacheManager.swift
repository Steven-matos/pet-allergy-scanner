//
//  ObservableCacheManager.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import SwiftUI

/**
 * Observable Cache Manager
 * 
 * A reliable, SwiftUI-compatible caching solution that properly triggers view updates.
 * Uses class-based cache entries instead of dictionaries to ensure SwiftUI observation works correctly.
 * 
 * Key Features:
 * - Proper SwiftUI observation with @Published
 * - Automatic cache expiration
 * - Thread-safe operations
 * - Clear cache invalidation
 * 
 * Follows SOLID principles with single responsibility for observable caching
 * Implements DRY by providing reusable cache patterns
 * Follows KISS by keeping the implementation simple and reliable
 * 
 * @deprecated Use UnifiedCacheCoordinator instead. This service is being phased out.
 */
@available(*, deprecated, message: "Use UnifiedCacheCoordinator.shared instead")
@MainActor
class ObservableCacheManager<Key: Hashable, Value>: ObservableObject {
    
    // MARK: - Cache Entry
    
    /**
     * Cache entry that holds data with metadata
     * Using a class ensures SwiftUI can observe changes properly
     */
    final class CacheEntry: ObservableObject {
        let key: Key
        var value: Value
        let createdAt: Date
        let expiresAt: Date?
        var lastAccessed: Date
        
        init(key: Key, value: Value, ttl: TimeInterval? = nil) {
            self.key = key
            self.value = value
            self.createdAt = Date()
            self.lastAccessed = Date()
            self.expiresAt = ttl.map { Date().addingTimeInterval($0) }
        }
        
        var isExpired: Bool {
            guard let expiresAt = expiresAt else { return false }
            return Date() > expiresAt
        }
        
        func touch() {
            lastAccessed = Date()
        }
    }
    
    // MARK: - Published Properties
    
    /**
     * Published cache entries - using array instead of dictionary for reliable observation
     * SwiftUI observes array changes more reliably than dictionary mutations
     */
    @Published private var _entries: [CacheEntry] = []
    
    /**
     * Cache statistics
     */
    @Published var cacheStats = CacheStats()
    
    // MARK: - Private Properties
    
    private let defaultTTL: TimeInterval?
    private let maxCacheSize: Int?
    
    // MARK: - Initialization
    
    /**
     * Initialize cache manager
     * 
     * - Parameters:
     *   - defaultTTL: Default time-to-live for cache entries (nil = no expiration)
     *   - maxCacheSize: Maximum number of entries (nil = unlimited)
     */
    init(defaultTTL: TimeInterval? = nil, maxCacheSize: Int? = nil) {
        self.defaultTTL = defaultTTL
        self.maxCacheSize = maxCacheSize
    }
    
    // MARK: - Public API
    
    /**
     * Get value from cache
     * 
     * - Parameter key: Cache key
     * - Returns: Cached value or nil if not found/expired
     */
    func get(_ key: Key) -> Value? {
        guard let entry = findEntry(for: key) else {
            return nil
        }
        
        // Check expiration
        if entry.isExpired {
            // Defer removal to avoid publishing during view updates
            Task { @MainActor in
                self.remove(key)
            }
            return nil
        }
        
        // Update access time
        entry.touch()
        
        // Defer stats update to avoid publishing during view updates
        Task { @MainActor in
            self.updateStats()
        }
        
        return entry.value
    }
    
    /**
     * Set value in cache
     * 
     * - Parameters:
     *   - value: Value to cache
     *   - forKey: Cache key
     *   - ttl: Optional time-to-live (uses default if nil)
     */
    func set(_ value: Value, forKey key: Key, ttl: TimeInterval? = nil) {
        let effectiveTTL = ttl ?? defaultTTL
        
        // Remove existing entry if present
        remove(key)
        
        // Create new entry
        let entry = CacheEntry(key: key, value: value, ttl: effectiveTTL)
        
        // Add to cache
        _entries.append(entry)
        
        // Enforce max cache size
        if let maxSize = maxCacheSize, _entries.count > maxSize {
            // Remove oldest entries (by last accessed time)
            _entries.sort { $0.lastAccessed < $1.lastAccessed }
            let toRemove = _entries.count - maxSize
            _entries.removeFirst(toRemove)
        }
        
        updateStats()
        print("✅ [ObservableCacheManager] Cached value for key: \(key) (total entries: \(_entries.count))")
    }
    
    /**
     * Remove value from cache
     * 
     * - Parameter key: Cache key
     */
    func remove(_ key: Key) {
        _entries.removeAll { $0.key == key }
        updateStats()
    }
    
    /**
     * Remove all expired entries
     * 
     * - Returns: Number of entries removed
     */
    @discardableResult
    func removeExpired() -> Int {
        let beforeCount = _entries.count
        _entries.removeAll { $0.isExpired }
        let removed = beforeCount - _entries.count
        
        if removed > 0 {
            updateStats()
            print("🧹 [ObservableCacheManager] Removed \(removed) expired entries")
        }
        
        return removed
    }
    
    /**
     * Clear all cache entries
     */
    func clear() {
        _entries.removeAll()
        updateStats()
        print("🗑️ [ObservableCacheManager] Cleared all cache entries")
    }
    
    /**
     * Update value in place (for mutable values)
     * 
     * - Parameters:
     *   - key: Cache key
     *   - update: Closure to update the value
     */
    func update(_ key: Key, update: (inout Value) -> Void) {
        guard let entry = findEntry(for: key) else { return }
        
        update(&entry.value)
        entry.touch()
        
        // Force SwiftUI update by reassigning the array
        // This ensures the view sees the change
        let currentEntries = _entries
        _entries = []
        _entries = currentEntries
        
        updateStats()
    }
    
    /**
     * Check if cache contains key
     * 
     * - Parameter key: Cache key
     * - Returns: True if key exists and is not expired
     */
    func contains(_ key: Key) -> Bool {
        guard let entry = findEntry(for: key) else { return false }
        return !entry.isExpired
    }
    
    /**
     * Get all keys in cache
     * 
     * - Returns: Array of all non-expired keys
     */
    func allKeys() -> [Key] {
        // Don't modify cache during read - defer expiration cleanup
        Task { @MainActor in
            self.removeExpired()
        }
        return _entries.filter { !$0.isExpired }.map { $0.key }
    }
    
    /**
     * Get all values in cache
     * 
     * - Returns: Array of all non-expired values
     */
    func allValues() -> [Value] {
        // Don't modify cache during read - defer expiration cleanup
        Task { @MainActor in
            self.removeExpired()
        }
        return _entries.filter { !$0.isExpired }.map { $0.value }
    }
    
    /**
     * Get cache size
     * 
     * - Returns: Number of entries in cache
     */
    var count: Int {
        // Don't modify cache during read - defer expiration cleanup
        Task { @MainActor in
            self.removeExpired()
        }
        return _entries.filter { !$0.isExpired }.count
    }
    
    /**
     * Check if cache is empty
     */
    var isEmpty: Bool {
        // Don't modify cache during read - defer expiration cleanup
        Task { @MainActor in
            self.removeExpired()
        }
        return _entries.allSatisfy { $0.isExpired }
    }
    
    // MARK: - Private Methods
    
    /**
     * Find cache entry for key
     */
    private func findEntry(for key: Key) -> CacheEntry? {
        return _entries.first { $0.key == key }
    }
    
    /**
     * Update cache statistics
     */
    private func updateStats() {
        cacheStats = CacheStats(
            totalEntries: _entries.count,
            expiredEntries: _entries.filter { $0.isExpired }.count,
            oldestEntry: _entries.min(by: { $0.lastAccessed < $1.lastAccessed })?.lastAccessed,
            newestEntry: _entries.max(by: { $0.lastAccessed < $1.lastAccessed })?.lastAccessed
        )
    }
}

// MARK: - Cache Statistics

/**
 * Cache statistics for monitoring
 */
struct CacheStats: Equatable {
    var totalEntries: Int = 0
    var expiredEntries: Int = 0
    var oldestEntry: Date?
    var newestEntry: Date?
}

