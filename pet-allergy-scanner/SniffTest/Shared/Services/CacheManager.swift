//
//  CacheManager.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine
import UIKit

/// Central cache manager coordinating all caching operations
/// Implements SOLID principles: Single responsibility for cache coordination
/// Implements DRY principle by centralizing cache management logic
@MainActor
class CacheManager: ObservableObject {
    static let shared = CacheManager()
    
    // MARK: - Properties
    
    @Published var isInitialized = false
    @Published var cacheStats: CacheStatistics?
    @Published var performanceMetrics: CachePerformanceMetrics?
    
    private let cacheService = CacheService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Cache warming strategies
    private let warmingStrategies: [CacheWarmingStrategy] = [
        CacheWarmingStrategy(
            priority: .critical,
            keys: [.currentUser, .userProfile],
            dependencies: [:],
            maxConcurrent: 2
        ),
        CacheWarmingStrategy(
            priority: .high,
            keys: [.pets, .commonAllergens, .safeAlternatives],
            dependencies: [.pets: [.currentUser]],
            maxConcurrent: 3
        ),
        CacheWarmingStrategy(
            priority: .medium,
            keys: [.scans, .scanHistory],
            dependencies: [.scans: [.pets]],
            maxConcurrent: 2
        ),
        CacheWarmingStrategy(
            priority: .medium,
            keys: [.nutritionRequirements, .recentFoods, .feedingRecords],
            dependencies: [.nutritionRequirements: [.pets]],
            maxConcurrent: 2
        )
    ]
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
        initializeCache()
    }
    
    // MARK: - Public Interface
    
    /// Initialize cache system
    func initializeCache() {
        Task {
            await performCacheWarming()
            isInitialized = true
            updateCacheStats()
        }
    }
    
    /// Warm cache with critical data
    func warmCache() async {
        await performCacheWarming()
    }
    
    /// Clear all caches
    func clearAllCaches() {
        cacheService.clearAll()
        updateCacheStats()
    }
    
    /// Clear user-specific caches
    /// - Parameter userId: User ID to clear caches for
    func clearUserCaches(userId: String) {
        cacheService.clearUserCache(userId: userId)
        updateCacheStats()
    }
    
    /// Invalidate caches based on trigger
    /// - Parameter trigger: Invalidation trigger
    func invalidateCaches(trigger: CacheInvalidationTrigger) {
        switch trigger {
        case .userLogout:
            if let userId = AuthService.shared.currentUser?.id {
                clearUserCaches(userId: userId)
            }
        case .userDataChanged:
            invalidateUserDataCaches()
        case .petDataChanged:
            invalidatePetDataCaches()
        case .scanDataChanged:
            invalidateScanDataCaches()
        case .manual:
            // Manual invalidation - clear all
            clearAllCaches()
        case .appBackgrounded:
            // Clear session-only caches
            invalidateSessionCaches()
        }
    }
    
    /// Get comprehensive cache statistics
    func getCacheStatistics() -> CacheStatistics? {
        return cacheStats
    }
    
    /// Get cache performance metrics
    func getPerformanceMetrics() -> CachePerformanceMetrics? {
        return performanceMetrics
    }
    
    /// Check cache health
    func checkCacheHealth() -> CacheHealthCheck {
        var issues: [CacheHealthCheck.CacheHealthIssue] = []
        var recommendations: [String] = []
        
        // Check memory usage
        if let stats = cacheStats {
            if stats.memorySizeMB > 100 {
                issues.append(.highMemoryUsage)
                recommendations.append("Consider reducing memory cache size or implementing more aggressive eviction")
            }
            
            if stats.diskSizeMB > 500 {
                issues.append(.highDiskUsage)
                recommendations.append("Consider implementing cache compression or reducing retention time")
            }
            
            if stats.hitRate < 0.7 {
                issues.append(.lowHitRate)
                recommendations.append("Review cache policies and consider increasing cache duration for frequently accessed data")
            }
        }
        
        let isHealthy = issues.isEmpty
        
        return CacheHealthCheck(
            isHealthy: isHealthy,
            issues: issues,
            recommendations: recommendations,
            lastChecked: Date()
        )
    }
    
    /// Optimize cache performance
    func optimizeCache() {
        // Clear expired entries
        clearExpiredEntries()
        
        // Compress large entries
        compressLargeEntries()
        
        // Update statistics
        updateCacheStats()
    }
    
    /// Preload critical data for app startup
    func preloadCriticalData() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        // Preload user data
        await preloadUserData(userId: userId)
        
        // Preload pets data
        await preloadPetsData(userId: userId)
        
        // Preload reference data
        await preloadReferenceData()
    }
    
    // MARK: - Private Methods
    
    /// Setup observers for cache events
    private func setupObservers() {
        // Observe app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.invalidateCaches(trigger: .appBackgrounded)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.warmCache()
                }
            }
            .store(in: &cancellables)
        
        // Observe memory warnings
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    /// Perform cache warming based on strategies
    private func performCacheWarming() async {
        // Sort strategies by priority
        let sortedStrategies = warmingStrategies.sorted { $0.priority.rawValue < $1.priority.rawValue }
        
        for strategy in sortedStrategies {
            await warmCacheForStrategy(strategy)
        }
    }
    
    /// Warm cache for specific strategy
    private func warmCacheForStrategy(_ strategy: CacheWarmingStrategy) async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        // Process keys in parallel with concurrency limit
        await withTaskGroup(of: Void.self) { group in
            let semaphore = AsyncSemaphore(value: strategy.maxConcurrent)
            
            for key in strategy.keys {
                group.addTask {
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    
                    // Check dependencies first
                    if let dependencies = strategy.dependencies[key] {
                        for dependency in dependencies {
                            await self.ensureCacheExists(for: dependency, userId: userId)
                        }
                    }
                    
                    // Warm the cache
                    await self.warmCacheForKey(key, userId: userId)
                }
            }
        }
    }
    
    /// Ensure cache exists for key
    private func ensureCacheExists(for key: CacheKey, userId: String) async {
        let scopedKey = key.scoped(forUserId: userId)
        
        if !cacheService.exists(forKey: scopedKey) {
            await warmCacheForKey(key, userId: userId)
        }
    }
    
    /// Warm cache for specific key
    private func warmCacheForKey(_ key: CacheKey, userId: String) async {
        switch key {
        case .currentUser:
            await warmCurrentUserCache(userId: userId)
        case .userProfile:
            await warmUserProfileCache(userId: userId)
        case .pets:
            await warmPetsCache(userId: userId)
        case .scans:
            await warmScansCache(userId: userId)
        case .commonAllergens:
            await warmCommonAllergensCache()
        case .safeAlternatives:
            await warmSafeAlternativesCache()
        default:
            break
        }
    }
    
    /// Warm current user cache
    private func warmCurrentUserCache(userId: String) async {
        do {
            let user = try await APIService.shared.getCurrentUser()
            cacheService.storeUserData(user, forKey: .currentUser, userId: userId)
        } catch {
            print("❌ Failed to warm current user cache: \(error)")
        }
    }
    
    /// Warm user profile cache
    private func warmUserProfileCache(userId: String) async {
        do {
            let user = try await APIService.shared.getCurrentUser()
            let userProfile = UserProfile(
                id: user.id,
                email: user.email,
                username: user.username,
                firstName: user.firstName,
                lastName: user.lastName,
                imageUrl: user.imageUrl,
                role: user.role,
                onboarded: user.onboarded,
                createdAt: user.createdAt,
                updatedAt: user.updatedAt
            )
            cacheService.storeUserData(userProfile, forKey: .userProfile, userId: userId)
        } catch {
            print("❌ Failed to warm user profile cache: \(error)")
        }
    }
    
    /// Warm pets cache
    private func warmPetsCache(userId: String) async {
        do {
            let pets = try await APIService.shared.getPets()
            cacheService.storeUserData(pets, forKey: .pets, userId: userId)
        } catch {
            print("❌ Failed to warm pets cache: \(error)")
        }
    }
    
    /// Warm scans cache
    private func warmScansCache(userId: String) async {
        do {
            let scans = try await APIService.shared.getScans()
            cacheService.storeUserData(scans, forKey: .scans, userId: userId)
        } catch {
            print("❌ Failed to warm scans cache: \(error)")
        }
    }
    
    /// Warm common allergens cache
    private func warmCommonAllergensCache() async {
        do {
            let allergens = try await APIService.shared.getCommonAllergens()
            cacheService.store(allergens, forKey: CacheKey.commonAllergens.rawValue)
        } catch {
            print("❌ Failed to warm common allergens cache: \(error)")
        }
    }
    
    /// Warm safe alternatives cache
    private func warmSafeAlternativesCache() async {
        do {
            let alternatives = try await APIService.shared.getSafeAlternatives()
            cacheService.store(alternatives, forKey: CacheKey.safeAlternatives.rawValue)
        } catch {
            print("❌ Failed to warm safe alternatives cache: \(error)")
        }
    }
    
    /// Preload user data
    private func preloadUserData(userId: String) async {
        await warmCurrentUserCache(userId: userId)
        await warmUserProfileCache(userId: userId)
    }
    
    /// Preload pets data
    private func preloadPetsData(userId: String) async {
        await warmPetsCache(userId: userId)
    }
    
    /// Preload reference data
    private func preloadReferenceData() async {
        await warmCommonAllergensCache()
        await warmSafeAlternativesCache()
    }
    
    /// Invalidate user data caches
    private func invalidateUserDataCaches() {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        cacheService.invalidate(forKey: CacheKey.currentUser.scoped(forUserId: userId))
        cacheService.invalidate(forKey: CacheKey.userProfile.scoped(forUserId: userId))
    }
    
    /// Invalidate pet data caches
    private func invalidatePetDataCaches() {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        cacheService.invalidate(forKey: CacheKey.pets.scoped(forUserId: userId))
        cacheService.invalidateMatching(pattern: ".*pet_details.*")
    }
    
    /// Invalidate scan data caches
    private func invalidateScanDataCaches() {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        cacheService.invalidate(forKey: CacheKey.scans.scoped(forUserId: userId))
        cacheService.invalidate(forKey: CacheKey.scanHistory.scoped(forUserId: userId))
    }
    
    /// Invalidate session-only caches
    private func invalidateSessionCaches() {
        // Clear session-only cache entries
        cacheService.invalidateMatching(pattern: ".*session.*")
    }
    
    /// Clear expired entries
    private func clearExpiredEntries() {
        // This would require implementing expiration checking in CacheService
        // For now, we'll rely on the automatic expiration in CacheService
    }
    
    /// Compress large entries
    private func compressLargeEntries() {
        // This would require implementing compression in CacheService
        // For now, we'll rely on the basic compression in CacheService
    }
    
    /// Handle memory warning
    private func handleMemoryWarning() {
        // Clear session-only caches
        invalidateSessionCaches()
        
        // Update statistics
        updateCacheStats()
    }
    
    /// Update cache statistics
    private func updateCacheStats() {
        let stats = cacheService.getCacheStats()
        
        cacheStats = CacheStatistics(
            totalEntries: stats["total_entries"] as? Int ?? 0,
            memoryEntries: stats["memory_entries"] as? Int ?? 0,
            diskEntries: stats["disk_entries"] as? Int ?? 0,
            memorySizeMB: Double(stats["memory_size_mb"] as? String ?? "0") ?? 0,
            diskSizeMB: Double(stats["disk_size_mb"] as? String ?? "0") ?? 0,
            hitRate: 0.0, // Would need to track this in CacheService
            missRate: 0.0, // Would need to track this in CacheService
            lastUpdated: Date()
        )
    }
}

// MARK: - AsyncSemaphore

/// Simple semaphore for controlling concurrency
actor AsyncSemaphore {
    private let value: Int
    private var count: Int
    
    init(value: Int) {
        self.value = value
        self.count = value
    }
    
    func wait() async {
        while count <= 0 {
            await Task.yield()
        }
        count -= 1
    }
    
    func signal() {
        count = min(count + 1, value)
    }
}

// MARK: - Cache Warming Priority Extension

extension CacheWarmingStrategy.CacheWarmingPriority {
    var rawValue: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}
