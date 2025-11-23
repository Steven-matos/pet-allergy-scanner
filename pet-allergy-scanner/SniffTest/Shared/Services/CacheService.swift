//
//  CacheService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine
import UIKit

/// Cache policy defining how data should be cached and when it expires
enum CachePolicy: Sendable {
    /// Cache indefinitely until manually invalidated
    case permanent
    /// Cache for a specific duration
    case timeBased(TimeInterval)
    /// Cache until app is terminated (memory only)
    case session
    /// Cache with custom validation logic
    case custom(validator: @Sendable () -> Bool)
}

/// Cache entry containing data, metadata, and expiration info
struct CacheEntry<T: Codable>: Codable {
    let data: T
    let timestamp: Date
    let policy: CachePolicyType
    let key: String
    
    /// Check if this cache entry is still valid
    var isValid: Bool {
        switch policy {
        case .permanent:
            return true
        case .timeBased(let duration):
            return Date().timeIntervalSince(timestamp) < duration
        case .session:
            return true // Session cache is valid until app termination
        case .custom:
            return true // Custom validation not supported in serializable type
        }
    }
    
    /// Cache policy type for serialization
    enum CachePolicyType: Codable {
        case permanent
        case timeBased(TimeInterval)
        case session
        case custom
    }
}

/// Cache key constants for type safety
enum CacheKey: String, CaseIterable {
    // User data
    case currentUser = "current_user"
    case userProfile = "user_profile"
    
    // Pet data
    case pets = "pets"
    case petDetails = "pet_details"
    
    // Scan data
    case scans = "scans"
    case scanHistory = "scan_history"
    
    // Reference data
    case commonAllergens = "common_allergens"
    case safeAlternatives = "safe_alternatives"
    
    // System data
    case healthStatus = "health_status"
    case systemMetrics = "system_metrics"
    
    // Nutrition data
    case nutritionRequirements = "nutrition_requirements"
    case foodDatabase = "food_database"
    case recentFoods = "recent_foods"
    case feedingRecords = "feeding_records"
    case dailySummaries = "daily_summaries"
    case weightRecords = "weight_records"
    case weightGoals = "weight_goals"
    case nutritionalTrends = "nutritional_trends"
    
    /// Generate a scoped key for user-specific data
    func scoped(forUserId userId: String) -> String {
        return "\(rawValue)_user_\(userId)"
    }
    
    /// Generate a scoped key for pet-specific data
    func scoped(forPetId petId: String) -> String {
        return "\(rawValue)_pet_\(petId)"
    }
}

/// Comprehensive caching service with memory and disk persistence
/// Implements SOLID principles: Single responsibility for caching, Open for extension
@MainActor
class CacheService: ObservableObject {
    static let shared = CacheService()
    
    // MARK: - Properties
    
    /// In-memory cache for fast access
    private var memoryCache: [String: Any] = [:]
    
    /// Cache policies for different data types
    /// Updated with 2025 best practices: longer cache for static data, shorter for dynamic
    private let cachePolicies: [String: CachePolicy] = [
        // User data - 30 minutes (refreshed on sign-in)
        CacheKey.currentUser.rawValue: .timeBased(1800), // 30 minutes
        CacheKey.userProfile.rawValue: .timeBased(1800), // 30 minutes
        
        // Pet data - 30 minutes (refreshed on app launch)
        CacheKey.pets.rawValue: .timeBased(1800), // 30 minutes
        CacheKey.petDetails.rawValue: .timeBased(1800), // 30 minutes
        
        // Dynamic data - 15 minutes (scans, feeding logs)
        CacheKey.scans.rawValue: .timeBased(900), // 15 minutes
        CacheKey.scanHistory.rawValue: .timeBased(900), // 15 minutes
        CacheKey.feedingRecords.rawValue: .timeBased(900), // 15 minutes
        CacheKey.dailySummaries.rawValue: .timeBased(900), // 15 minutes
        
        // Static reference data - 7 days (rarely changes)
        CacheKey.commonAllergens.rawValue: .timeBased(604800), // 7 days
        CacheKey.safeAlternatives.rawValue: .timeBased(604800), // 7 days
        CacheKey.foodDatabase.rawValue: .timeBased(604800), // 7 days
        
        // System data - short cache
        CacheKey.healthStatus.rawValue: .timeBased(300), // 5 minutes
        CacheKey.systemMetrics.rawValue: .timeBased(600), // 10 minutes
        
        // Nutrition data policies
        CacheKey.nutritionRequirements.rawValue: .timeBased(3600), // 1 hour
        CacheKey.recentFoods.rawValue: .timeBased(1800), // 30 minutes
        CacheKey.weightRecords.rawValue: .timeBased(3600), // 1 hour
        CacheKey.weightGoals.rawValue: .timeBased(7200), // 2 hours
        CacheKey.nutritionalTrends.rawValue: .timeBased(7200) // 2 hours
    ]
    
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
    
    // MARK: - Initialization
    
    private init() {
        setupCacheDirectory()
        loadPersistentCache()
        setupMemoryWarningObserver()
    }
    
    // MARK: - Public Interface
    
    /// Store data in cache with automatic policy application
    /// - Parameters:
    ///   - data: The data to cache
    ///   - key: The cache key
    ///   - policy: Optional custom policy (uses default if nil)
    func store<T: Codable>(_ data: T, forKey key: String, policy: CachePolicy? = nil) {
        let cachePolicy = policy ?? cachePolicies[key] ?? .timeBased(1800) // Default 30 minutes
        
        do {
            let encodedData = try JSONEncoder().encode(data)
            let entry = CacheEntry<Data>(
                data: encodedData,
                timestamp: Date(),
                policy: cachePolicy.toSerializableType(),
                key: key
            )
            
            // Store in memory cache
            storeInMemory(entry as CacheEntry<Data>, forKey: key)
            
            // Store in disk cache for persistent data
            if shouldPersistToDisk(policy: cachePolicy) {
                storeOnDisk(entry as CacheEntry<Data>, forKey: key)
            }
        } catch {
            // Failed to encode data for caching
        }
    }
    
    /// Retrieve data from cache
    /// - Parameter key: The cache key
    /// - Returns: Cached data if valid, nil otherwise
    func retrieve<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        // Try memory cache first with safe casting
        if let cachedValue = memoryCache[key] {
            // Use a more defensive approach to avoid casting errors
            if let memoryEntry = cachedValue as? CacheEntry<T>,
               memoryEntry.isValid {
                return memoryEntry.data
            } else {
                // Clear the corrupted memory cache entry
                memoryCache.removeValue(forKey: key)
            }
        }
        
        // Try disk cache with error handling
        if let diskEntry = loadFromDisk(type, forKey: key),
           diskEntry.isValid {
            // Restore to memory cache
            storeInMemory(diskEntry, forKey: key)
            return diskEntry.data
        }
        
        return nil
    }
    
    /// Check if data exists in cache and is valid
    /// - Parameter key: The cache key
    /// - Returns: True if valid data exists
    func exists(forKey key: String) -> Bool {
        // Check memory cache
        if let memoryEntry = memoryCache[key] as? CacheEntry<Data>,
           memoryEntry.isValid {
            return true
        }
        
        // Check disk cache
        if let diskEntry = loadFromDisk(Data.self, forKey: key),
           diskEntry.isValid {
            return true
        }
        
        return false
    }
    
    /// Invalidate cache entry
    /// - Parameter key: The cache key to invalidate
    func invalidate(forKey key: String) {
        memoryCache.removeValue(forKey: key)
        removeFromDisk(forKey: key)
    }
    
    /// Invalidate all cache entries matching a pattern
    /// - Parameter pattern: Regex pattern to match keys
    func invalidateMatching(pattern: String) {
        let regex = try? NSRegularExpression(pattern: pattern)
        
        // Invalidate memory cache
        let memoryKeys = memoryCache.keys.filter { key in
            regex?.firstMatch(in: key, range: NSRange(key.startIndex..., in: key)) != nil
        }
        memoryKeys.forEach { memoryCache.removeValue(forKey: $0) }
        
        // Invalidate disk cache
        invalidateDiskMatching(pattern: pattern)
    }
    
    /// Clear all cache data
    func clearAll() {
        memoryCache.removeAll()
        currentMemoryCacheSize = 0
        clearDiskCache()
    }
    
    /// Clear cache for a specific key (both memory and disk)
    func clearCache(forKey key: String) {
        memoryCache.removeValue(forKey: key)
        removeFromDisk(forKey: key)
    }
    
    /// Clear cache for a specific user (useful during logout)
    /// - Parameter userId: The user ID to clear cache for
    func clearUserCache(userId: String) {
        let userKeys = CacheKey.allCases.map { $0.scoped(forUserId: userId) }
        userKeys.forEach { invalidate(forKey: $0) }
    }
    
    /// Get cache statistics
    /// - Returns: Dictionary with cache statistics
    func getCacheStats() -> [String: Any] {
        let memoryCount = memoryCache.count
        let memorySizeMB = Double(currentMemoryCacheSize) / (1024 * 1024)
        
        let diskCount = getDiskCacheCount()
        let diskSizeMB = getDiskCacheSize()
        
        return [
            "memory_entries": memoryCount,
            "memory_size_mb": String(format: "%.2f", memorySizeMB),
            "disk_entries": diskCount,
            "disk_size_mb": String(format: "%.2f", diskSizeMB),
            "total_entries": memoryCount + diskCount
        ]
    }
    
    // MARK: - Private Methods
    
    /// Setup cache directory
    private func setupCacheDirectory() {
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            // Failed to create cache directory
        }
    }
    
    /// Load persistent cache from disk on startup
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
                } else {
                    // Remove invalid cache file
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            // Failed to load persistent cache
        }
    }
    
    /// Store data in memory cache with size management
    private func storeInMemory<T: Codable>(_ entry: CacheEntry<T>, forKey key: String) {
        // Estimate size (rough approximation)
        let estimatedSize = estimateSize(of: entry)
        
        // Check if we need to evict old entries
        while currentMemoryCacheSize + estimatedSize > memoryCacheLimit * 1024 * 1024 {
            evictOldestMemoryEntry()
        }
        
        memoryCache[key] = entry
        currentMemoryCacheSize += estimatedSize
    }
    
    /// Store data on disk
    private func storeOnDisk<T: Codable>(_ entry: CacheEntry<T>, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(entry)
            let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
            try data.write(to: fileURL)
        } catch {
            // Failed to store cache on disk
        }
    }
    
    /// Load data from disk
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
    
    /// Remove data from disk
    private func removeFromDisk(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).cache")
        try? fileManager.removeItem(at: fileURL)
    }
    
    /// Clear all disk cache
    private func clearDiskCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
            // Failed to clear disk cache
        }
    }
    
    /// Invalidate disk cache matching pattern
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
            // Failed to invalidate disk cache
        }
    }
    
    /// Get disk cache entry count
    private func getDiskCacheCount() -> Int {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            return files.filter { $0.pathExtension == "cache" }.count
        } catch {
            return 0
        }
    }
    
    /// Get disk cache size in MB
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
    
    /// Evict oldest memory entry (LRU strategy)
    private func evictOldestMemoryEntry() {
        guard let oldestKey = memoryCache.keys.first else { return }
        
        if let entry = memoryCache[oldestKey] as? CacheEntry<Data> {
            currentMemoryCacheSize -= estimateSize(of: entry)
        }
        
        memoryCache.removeValue(forKey: oldestKey)
    }
    
    /// Estimate size of cache entry
    private func estimateSize<T: Codable>(of entry: CacheEntry<T>) -> Int {
        // Rough estimation - in production, you might want more accurate sizing
        do {
            let data = try JSONEncoder().encode(entry)
            return data.count
        } catch {
            return 1024 // Default 1KB estimate
        }
    }
    
    /// Check if data should be persisted to disk
    private func shouldPersistToDisk(policy: CachePolicy) -> Bool {
        switch policy {
        case .permanent, .timeBased:
            return true
        case .session, .custom:
            return false
        }
    }
    
    /// Setup memory warning observer
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
    
    /// Handle memory warning by clearing session cache
    private func handleMemoryWarning() {
        // Clear session-only cache entries
        let sessionKeys = memoryCache.keys.filter { key in
            if case .session = cachePolicies[key] { true } else { false }
        }
        
        sessionKeys.forEach { key in
            memoryCache.removeValue(forKey: key)
        }
        
    }
}

// MARK: - CachePolicy Extension

extension CachePolicy {
    /// Convert to serializable type for disk storage
    func toSerializableType() -> CacheEntry<Data>.CachePolicyType {
        switch self {
        case .permanent:
            return .permanent
        case .timeBased(let duration):
            return .timeBased(duration)
        case .session:
            return .session
        case .custom:
            return .custom
        }
    }
}

// MARK: - Convenience Extensions

extension CacheService {
    /// Store user data with automatic scoping
    func storeUserData<T: Codable>(_ data: T, forKey key: CacheKey, userId: String) {
        let scopedKey = key.scoped(forUserId: userId)
        store(data, forKey: scopedKey)
    }
    
    /// Retrieve user data with automatic scoping
    func retrieveUserData<T: Codable>(_ type: T.Type, forKey key: CacheKey, userId: String) -> T? {
        let scopedKey = key.scoped(forUserId: userId)
        return retrieve(type, forKey: scopedKey)
    }
    
    /// Store pet data with automatic scoping
    func storePetData<T: Codable>(_ data: T, forKey key: CacheKey, petId: String) {
        let scopedKey = key.scoped(forPetId: petId)
        store(data, forKey: scopedKey)
    }
    
    /// Retrieve pet data with automatic scoping
    func retrievePetData<T: Codable>(_ type: T.Type, forKey key: CacheKey, petId: String) -> T? {
        let scopedKey = key.scoped(forPetId: petId)
        return retrieve(type, forKey: scopedKey)
    }
}
