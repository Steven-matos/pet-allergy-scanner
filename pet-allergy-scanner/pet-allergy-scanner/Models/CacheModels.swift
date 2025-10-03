//
//  CacheModels.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Cache configuration for different data types
struct CacheConfig {
    let key: CacheKey
    let policy: CachePolicy
    let shouldPersist: Bool
    let maxAge: TimeInterval
    let refreshThreshold: TimeInterval
    
    /// Default configurations for common data types
    static let configurations: [CacheKey: CacheConfig] = [
        .currentUser: CacheConfig(
            key: .currentUser,
            policy: .timeBased(3600), // 1 hour
            shouldPersist: true,
            maxAge: 3600,
            refreshThreshold: 300 // Refresh 5 minutes before expiry
        ),
        .userProfile: CacheConfig(
            key: .userProfile,
            policy: .timeBased(1800), // 30 minutes
            shouldPersist: true,
            maxAge: 1800,
            refreshThreshold: 180 // Refresh 3 minutes before expiry
        ),
        .pets: CacheConfig(
            key: .pets,
            policy: .timeBased(1800), // 30 minutes
            shouldPersist: true,
            maxAge: 1800,
            refreshThreshold: 180
        ),
        .petDetails: CacheConfig(
            key: .petDetails,
            policy: .timeBased(3600), // 1 hour
            shouldPersist: true,
            maxAge: 3600,
            refreshThreshold: 300
        ),
        .scans: CacheConfig(
            key: .scans,
            policy: .timeBased(900), // 15 minutes
            shouldPersist: true,
            maxAge: 900,
            refreshThreshold: 60
        ),
        .scanHistory: CacheConfig(
            key: .scanHistory,
            policy: .timeBased(1800), // 30 minutes
            shouldPersist: true,
            maxAge: 1800,
            refreshThreshold: 180
        ),
        .commonAllergens: CacheConfig(
            key: .commonAllergens,
            policy: .timeBased(86400), // 24 hours
            shouldPersist: true,
            maxAge: 86400,
            refreshThreshold: 3600 // Refresh 1 hour before expiry
        ),
        .safeAlternatives: CacheConfig(
            key: .safeAlternatives,
            policy: .timeBased(86400), // 24 hours
            shouldPersist: true,
            maxAge: 86400,
            refreshThreshold: 3600
        ),
        .mfaStatus: CacheConfig(
            key: .mfaStatus,
            policy: .timeBased(1800), // 30 minutes
            shouldPersist: false,
            maxAge: 1800,
            refreshThreshold: 180
        ),
        .healthStatus: CacheConfig(
            key: .healthStatus,
            policy: .timeBased(300), // 5 minutes
            shouldPersist: false,
            maxAge: 300,
            refreshThreshold: 60
        ),
        .systemMetrics: CacheConfig(
            key: .systemMetrics,
            policy: .timeBased(600), // 10 minutes
            shouldPersist: false,
            maxAge: 600,
            refreshThreshold: 120
        )
    ]
}

/// Cache refresh strategy
enum CacheRefreshStrategy {
    /// Refresh data in background when cache is about to expire
    case background
    /// Refresh data only when explicitly requested
    case onDemand
    /// Refresh data immediately when cache expires
    case immediate
    /// Never refresh automatically
    case manual
}

/// Cache invalidation trigger
enum CacheInvalidationTrigger {
    /// User logged out
    case userLogout
    /// User data updated
    case userDataChanged
    /// Pet data updated
    case petDataChanged
    /// Scan data updated
    case scanDataChanged
    /// Manual invalidation
    case manual
    /// App backgrounded
    case appBackgrounded
}

/// Cache statistics model
struct CacheStatistics: Codable {
    let totalEntries: Int
    let memoryEntries: Int
    let diskEntries: Int
    let memorySizeMB: Double
    let diskSizeMB: Double
    let hitRate: Double
    let missRate: Double
    let lastUpdated: Date
    
    /// Calculate cache efficiency
    var efficiency: Double {
        return hitRate / (hitRate + missRate) * 100
    }
}

/// Cache performance metrics
struct CachePerformanceMetrics: Codable {
    var averageRetrievalTime: TimeInterval
    var averageStorageTime: TimeInterval
    var totalHits: Int
    var totalMisses: Int
    var totalStores: Int
    var totalInvalidations: Int
    var memoryEvictions: Int
    var diskCleanups: Int
    
    /// Calculate hit rate percentage
    var hitRatePercentage: Double {
        let total = totalHits + totalMisses
        return total > 0 ? (Double(totalHits) / Double(total)) * 100 : 0
    }
    
    /// Calculate miss rate percentage
    var missRatePercentage: Double {
        let total = totalHits + totalMisses
        return total > 0 ? (Double(totalMisses) / Double(total)) * 100 : 0
    }
}

/// Cache entry metadata for analytics
struct CacheEntryMetadata: Codable {
    let key: String
    let dataType: String
    let size: Int
    let createdAt: Date
    let lastAccessed: Date
    let accessCount: Int
    let isPersistent: Bool
    let policy: String
    
    /// Calculate entry age
    var age: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }
    
    /// Calculate time since last access
    var timeSinceLastAccess: TimeInterval {
        return Date().timeIntervalSince(lastAccessed)
    }
}

/// Cache configuration for specific user context
struct UserCacheConfig {
    let userId: String
    let enabledKeys: Set<CacheKey>
    let customPolicies: [CacheKey: CachePolicy]
    let refreshStrategy: CacheRefreshStrategy
    let maxMemorySize: Int // in MB
    let maxDiskSize: Int // in MB
    
    /// Default configuration for new users
    static func `default`(for userId: String) -> UserCacheConfig {
        return UserCacheConfig(
            userId: userId,
            enabledKeys: Set(CacheKey.allCases),
            customPolicies: [:],
            refreshStrategy: .background,
            maxMemorySize: 50,
            maxDiskSize: 200
        )
    }
}

/// Cache warming strategy for app startup
struct CacheWarmingStrategy {
    let priority: CacheWarmingPriority
    let keys: [CacheKey]
    let dependencies: [CacheKey: [CacheKey]]
    let maxConcurrent: Int
    
    enum CacheWarmingPriority {
        case critical    // Load immediately on app start
        case high        // Load after critical data
        case medium      // Load in background
        case low         // Load when idle
    }
}

/// Cache synchronization status
enum CacheSyncStatus: String, Codable, CaseIterable {
    case synced = "synced"
    case pending = "pending"
    case failed = "failed"
    case neverSynced = "neverSynced"
}

/// Cache entry with sync information
struct SyncableCacheEntry<T: Codable>: Codable {
    let data: T
    let syncStatus: CacheSyncStatus
    let lastSyncAttempt: Date?
    let syncError: String?
    let retryCount: Int
    let maxRetries: Int
    
    /// Check if entry should be retried
    var shouldRetry: Bool {
        return syncStatus == .failed && retryCount < maxRetries
    }
    
    /// Check if entry is ready for sync
    var isReadyForSync: Bool {
        return syncStatus == .pending || shouldRetry
    }
}

/// Cache preloading configuration
struct CachePreloadConfig {
    let keys: [CacheKey]
    let conditions: [CacheKey: () -> Bool]
    let priority: CacheWarmingStrategy.CacheWarmingPriority
    let maxAge: TimeInterval
    
    /// Check if preload should occur
    func shouldPreload(for key: CacheKey) -> Bool {
        guard let condition = conditions[key] else { return true }
        return condition()
    }
}

/// Cache compression settings
struct CacheCompressionSettings {
    let enabled: Bool
    let algorithm: CompressionAlgorithm
    let threshold: Int // Minimum size to compress (in bytes)
    let level: CompressionLevel
    
    enum CompressionAlgorithm: String, CaseIterable {
        case lzfse = "lzfse"
        case lz4 = "lz4"
        case zlib = "zlib"
        
        var displayName: String {
            switch self {
            case .lzfse: return "LZFSE (Apple)"
            case .lz4: return "LZ4 (Fast)"
            case .zlib: return "Zlib (Standard)"
            }
        }
    }
    
    enum CompressionLevel: Int, CaseIterable {
        case fastest = 1
        case fast = 3
        case balanced = 6
        case best = 9
        
        var displayName: String {
            switch self {
            case .fastest: return "Fastest"
            case .fast: return "Fast"
            case .balanced: return "Balanced"
            case .best: return "Best"
            }
        }
    }
}

/// Cache analytics event
struct CacheAnalyticsEvent: Codable {
    let eventType: CacheEventType
    let key: String
    let timestamp: Date
    let duration: TimeInterval?
    let success: Bool
    let errorMessage: String?
    let metadata: [String: String]
    
    enum CacheEventType: String, Codable {
        case store = "store"
        case retrieve = "retrieve"
        case invalidate = "invalidate"
        case evict = "evict"
        case refresh = "refresh"
        case sync = "sync"
        case compress = "compress"
        case decompress = "decompress"
    }
}

/// Cache health check result
struct CacheHealthCheck: Codable {
    let isHealthy: Bool
    let issues: [CacheHealthIssue]
    let recommendations: [String]
    let lastChecked: Date
    
    enum CacheHealthIssue: String, Codable {
        case highMemoryUsage = "high_memory_usage"
        case highDiskUsage = "high_disk_usage"
        case lowHitRate = "low_hit_rate"
        case slowRetrieval = "slow_retrieval"
        case corruptedEntries = "corrupted_entries"
        case excessiveEvictions = "excessive_evictions"
    }
}
