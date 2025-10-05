//
//  CacheConfiguration.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Cache configuration manager
/// Implements SOLID principles: Single responsibility for cache configuration
/// Implements KISS principle with simple configuration management
@MainActor
class CacheConfiguration: @unchecked Sendable {
    static let shared = CacheConfiguration()
    
    // MARK: - Configuration Properties
    
    /// Maximum memory cache size in MB
    let maxMemoryCacheSize: Int = 50
    
    /// Maximum disk cache size in MB
    let maxDiskCacheSize: Int = 200
    
    /// Cache compression settings
    let compressionSettings = CacheCompressionSettings(
        enabled: true,
        algorithm: .lzfse,
        threshold: 1024, // 1KB
        level: .balanced
    )
    
    /// Cache refresh intervals (in seconds)
    let refreshIntervals: [CacheKey: TimeInterval] = [
        .currentUser: 3600,        // 1 hour
        .userProfile: 1800,        // 30 minutes
        .pets: 1800,               // 30 minutes
        .petDetails: 3600,         // 1 hour
        .scans: 900,               // 15 minutes
        .scanHistory: 1800,        // 30 minutes
        .commonAllergens: 86400,   // 24 hours
        .safeAlternatives: 86400,  // 24 hours
        .mfaStatus: 1800,          // 30 minutes
        .healthStatus: 300,        // 5 minutes
        .systemMetrics: 600        // 10 minutes
    ]
    
    /// Cache policies for different data types
    let cachePolicies: [CacheKey: CachePolicy] = [
        .currentUser: .timeBased(3600),
        .userProfile: .timeBased(1800),
        .pets: .timeBased(1800),
        .petDetails: .timeBased(3600),
        .scans: .timeBased(900),
        .scanHistory: .timeBased(1800),
        .commonAllergens: .timeBased(86400),
        .safeAlternatives: .timeBased(86400),
        .mfaStatus: .timeBased(1800),
        .healthStatus: .timeBased(300),
        .systemMetrics: .timeBased(600)
    ]
    
    /// Cache warming configuration
    let warmingConfig = CachePreloadConfig(
        keys: [.currentUser, .userProfile, .pets, .commonAllergens, .safeAlternatives],
        conditions: [
            .currentUser: { true }, // Always preload current user data
            .userProfile: { true }, // Always preload user profile data
            .pets: { true }, // Always preload pets data
            .commonAllergens: { true },
            .safeAlternatives: { true }
        ],
        priority: .high,
        maxAge: 3600
    )
    
    /// Cache invalidation rules
    let invalidationRules: [CacheInvalidationTrigger: [CacheKey]] = [
        .userLogout: [.currentUser, .userProfile, .pets, .scans, .scanHistory, .mfaStatus],
        .userDataChanged: [.currentUser, .userProfile],
        .petDataChanged: [.pets, .petDetails, .scans, .scanHistory],
        .scanDataChanged: [.scans, .scanHistory],
        .appBackgrounded: [.healthStatus, .systemMetrics],
        .manual: CacheKey.allCases
    ]
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get cache policy for key
    /// - Parameter key: Cache key
    /// - Returns: Cache policy
    func getPolicy(for key: CacheKey) -> CachePolicy {
        return cachePolicies[key] ?? .timeBased(1800) // Default 30 minutes
    }
    
    /// Get refresh interval for key
    /// - Parameter key: Cache key
    /// - Returns: Refresh interval in seconds
    func getRefreshInterval(for key: CacheKey) -> TimeInterval {
        return refreshIntervals[key] ?? 1800 // Default 30 minutes
    }
    
    /// Get invalidation keys for trigger
    /// - Parameter trigger: Invalidation trigger
    /// - Returns: Keys to invalidate
    func getInvalidationKeys(for trigger: CacheInvalidationTrigger) -> [CacheKey] {
        return invalidationRules[trigger] ?? []
    }
    
    /// Check if key should be preloaded
    /// - Parameter key: Cache key
    /// - Returns: True if should be preloaded
    func shouldPreload(key: CacheKey) -> Bool {
        return warmingConfig.keys.contains(key) && warmingConfig.shouldPreload(for: key)
    }
    
    /// Get cache configuration for user
    /// - Parameter userId: User ID
    /// - Returns: User-specific cache configuration
    func getUserCacheConfig(userId: String) -> UserCacheConfig {
        return UserCacheConfig(
            userId: userId,
            enabledKeys: Set(CacheKey.allCases),
            customPolicies: [:],
            refreshStrategy: .background,
            maxMemorySize: maxMemoryCacheSize,
            maxDiskSize: maxDiskCacheSize
        )
    }
    
    /// Get cache health thresholds
    /// - Returns: Health thresholds
    func getHealthThresholds() -> CacheHealthThresholds {
        return CacheHealthThresholds(
            maxMemoryUsageMB: 100,
            maxDiskUsageMB: 500,
            minHitRate: 0.7,
            maxRetrievalTime: 0.1,
            maxEvictionRate: 0.1
        )
    }
}

// MARK: - Cache Health Thresholds

/// Cache health thresholds for monitoring
struct CacheHealthThresholds {
    let maxMemoryUsageMB: Double
    let maxDiskUsageMB: Double
    let minHitRate: Double
    let maxRetrievalTime: TimeInterval
    let maxEvictionRate: Double
}

// MARK: - Cache Configuration Extensions

extension CacheConfiguration {
    /// Get cache configuration for development
    static var development: CacheConfiguration {
        let config = CacheConfiguration()
        // Override settings for development
        return config
    }
    
    /// Get cache configuration for production
    static var production: CacheConfiguration {
        let config = CacheConfiguration()
        // Override settings for production
        return config
    }
    
    /// Get cache configuration for testing
    static var testing: CacheConfiguration {
        let config = CacheConfiguration()
        // Override settings for testing
        return config
    }
}

// MARK: - Cache Configuration Validation

extension CacheConfiguration {
    /// Validate cache configuration
    /// - Returns: Validation result
    func validate() -> CacheConfigurationValidation {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Validate memory cache size
        if maxMemoryCacheSize <= 0 {
            errors.append("Memory cache size must be positive")
        } else if maxMemoryCacheSize > 500 {
            warnings.append("Memory cache size is very large (\(maxMemoryCacheSize)MB)")
        }
        
        // Validate disk cache size
        if maxDiskCacheSize <= 0 {
            errors.append("Disk cache size must be positive")
        } else if maxDiskCacheSize > 2000 {
            warnings.append("Disk cache size is very large (\(maxDiskCacheSize)MB)")
        }
        
        // Validate refresh intervals
        for (key, interval) in refreshIntervals {
            if interval <= 0 {
                errors.append("Refresh interval for \(key.rawValue) must be positive")
            } else if interval > 86400 {
                warnings.append("Refresh interval for \(key.rawValue) is very long (\(interval) seconds)")
            }
        }
        
        // Validate cache policies
        for (key, policy) in cachePolicies {
            if case .timeBased(let duration) = policy, duration <= 0 {
                errors.append("Time-based policy for \(key.rawValue) must have positive duration")
            }
        }
        
        let isValid = errors.isEmpty
        
        return CacheConfigurationValidation(
            isValid: isValid,
            errors: errors,
            warnings: warnings
        )
    }
}

// MARK: - Cache Configuration Validation Result

/// Cache configuration validation result
struct CacheConfigurationValidation {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    
    /// Get validation summary
    var summary: String {
        if isValid {
            return "Cache configuration is valid"
        } else {
            return "Cache configuration has \(errors.count) error(s) and \(warnings.count) warning(s)"
        }
    }
}
