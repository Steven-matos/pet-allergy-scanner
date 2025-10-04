//
//  CacheAnalyticsService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/// Cache analytics service for monitoring and optimization
/// Implements SOLID principles: Single responsibility for cache analytics
/// Implements DRY principle by centralizing analytics logic
@MainActor
class CacheAnalyticsService: ObservableObject {
    static let shared = CacheAnalyticsService()
    
    // MARK: - Properties
    
    @Published var isEnabled = true
    @Published var analyticsData: CacheAnalyticsData = CacheAnalyticsData()
    
    private let cacheService = CacheService.shared
    private let cacheManager = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Analytics event storage
    private var events: [CacheAnalyticsEvent] = []
    private let maxEvents = 1000
    
    /// Performance metrics
    private var performanceMetrics = CachePerformanceMetrics(
        averageRetrievalTime: 0,
        averageStorageTime: 0,
        totalHits: 0,
        totalMisses: 0,
        totalStores: 0,
        totalInvalidations: 0,
        memoryEvictions: 0,
        diskCleanups: 0
    )
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
        loadAnalyticsData()
    }
    
    // MARK: - Public Interface
    
    /// Track cache event
    /// - Parameter event: Analytics event
    func trackEvent(_ event: CacheAnalyticsEvent) {
        guard isEnabled else { return }
        
        // Add event to storage
        events.append(event)
        
        // Maintain max events limit
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        
        // Update performance metrics
        updatePerformanceMetrics(for: event)
        
        // Update analytics data
        updateAnalyticsData()
    }
    
    /// Get cache statistics
    /// - Returns: Current cache statistics
    func getCacheStatistics() -> CacheStatistics? {
        return cacheManager.getCacheStatistics()
    }
    
    /// Get performance metrics
    /// - Returns: Current performance metrics
    func getPerformanceMetrics() -> CachePerformanceMetrics {
        return performanceMetrics
    }
    
    /// Get analytics data
    /// - Returns: Current analytics data
    func getAnalyticsData() -> CacheAnalyticsData {
        return analyticsData
    }
    
    /// Get cache health check
    /// - Returns: Cache health check result
    func getCacheHealthCheck() -> CacheHealthCheck {
        return cacheManager.checkCacheHealth()
    }
    
    /// Get cache recommendations
    /// - Returns: List of recommendations
    func getCacheRecommendations() -> [CacheRecommendation] {
        var recommendations: [CacheRecommendation] = []
        
        // Check hit rate
        if performanceMetrics.hitRatePercentage < 70 {
            recommendations.append(CacheRecommendation(
                type: .lowHitRate,
                priority: .high,
                title: "Low Cache Hit Rate",
                description: "Cache hit rate is \(String(format: "%.1f", performanceMetrics.hitRatePercentage))%. Consider reviewing cache policies.",
                action: "Review cache policies and increase cache duration for frequently accessed data"
            ))
        }
        
        // Check memory usage
        if let stats = analyticsData.cacheStats, stats.memorySizeMB > 100 {
            recommendations.append(CacheRecommendation(
                type: .highMemoryUsage,
                priority: .medium,
                title: "High Memory Usage",
                description: "Memory cache usage is \(String(format: "%.1f", stats.memorySizeMB))MB. Consider reducing cache size.",
                action: "Reduce memory cache size or implement more aggressive eviction"
            ))
        }
        
        // Check disk usage
        if let stats = analyticsData.cacheStats, stats.diskSizeMB > 500 {
            recommendations.append(CacheRecommendation(
                type: .highDiskUsage,
                priority: .medium,
                title: "High Disk Usage",
                description: "Disk cache usage is \(String(format: "%.1f", stats.diskSizeMB))MB. Consider implementing compression.",
                action: "Enable cache compression or reduce retention time"
            ))
        }
        
        // Check retrieval time
        if performanceMetrics.averageRetrievalTime > 0.1 {
            recommendations.append(CacheRecommendation(
                type: .slowRetrieval,
                priority: .high,
                title: "Slow Cache Retrieval",
                description: "Average retrieval time is \(String(format: "%.3f", performanceMetrics.averageRetrievalTime))s. Consider optimizing cache structure.",
                action: "Review cache implementation and consider using faster data structures"
            ))
        }
        
        return recommendations
    }
    
    /// Export analytics data
    /// - Returns: Exported analytics data as JSON
    func exportAnalyticsData() -> Data? {
        let exportData = CacheAnalyticsExport(
            analyticsData: analyticsData,
            performanceMetrics: performanceMetrics,
            events: events,
            exportDate: Date()
        )
        
        do {
            return try JSONEncoder().encode(exportData)
        } catch {
            print("❌ Failed to export analytics data: \(error)")
            return nil
        }
    }
    
    /// Clear analytics data
    func clearAnalyticsData() {
        events.removeAll()
        performanceMetrics = CachePerformanceMetrics(
            averageRetrievalTime: 0,
            averageStorageTime: 0,
            totalHits: 0,
            totalMisses: 0,
            totalStores: 0,
            totalInvalidations: 0,
            memoryEvictions: 0,
            diskCleanups: 0
        )
        analyticsData = CacheAnalyticsData()
    }
    
    /// Enable/disable analytics
    /// - Parameter enabled: Whether to enable analytics
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    // MARK: - Private Methods
    
    /// Setup observers for cache events
    private func setupObservers() {
        // Observe cache service changes
        cacheService.objectWillChange
            .sink { [weak self] _ in
                self?.updateAnalyticsData()
            }
            .store(in: &cancellables)
        
        // Observe cache manager changes
        cacheManager.objectWillChange
            .sink { [weak self] _ in
                self?.updateAnalyticsData()
            }
            .store(in: &cancellables)
    }
    
    /// Load analytics data from storage
    private func loadAnalyticsData() {
        // Load from UserDefaults or other persistent storage
        if let data = UserDefaults.standard.data(forKey: "cache_analytics_data"),
           let loadedData = try? JSONDecoder().decode(CacheAnalyticsData.self, from: data) {
            analyticsData = loadedData
        }
    }
    
    /// Save analytics data to storage
    private func saveAnalyticsData() {
        do {
            let data = try JSONEncoder().encode(analyticsData)
            UserDefaults.standard.set(data, forKey: "cache_analytics_data")
        } catch {
            print("❌ Failed to save analytics data: \(error)")
        }
    }
    
    /// Update performance metrics based on event
    private func updatePerformanceMetrics(for event: CacheAnalyticsEvent) {
        switch event.eventType {
        case .retrieve:
            if event.success {
                performanceMetrics.totalHits += 1
            } else {
                performanceMetrics.totalMisses += 1
            }
            
            if let duration = event.duration {
                let totalRetrievals = performanceMetrics.totalHits + performanceMetrics.totalMisses
                performanceMetrics.averageRetrievalTime = 
                    (performanceMetrics.averageRetrievalTime * Double(totalRetrievals - 1) + duration) / Double(totalRetrievals)
            }
            
        case .store:
            performanceMetrics.totalStores += 1
            
            if let duration = event.duration {
                performanceMetrics.averageStorageTime = 
                    (performanceMetrics.averageStorageTime * Double(performanceMetrics.totalStores - 1) + duration) / Double(performanceMetrics.totalStores)
            }
            
        case .invalidate:
            performanceMetrics.totalInvalidations += 1
            
        case .evict:
            performanceMetrics.memoryEvictions += 1
            
        case .refresh:
            // Handle refresh events
            break
            
        case .sync:
            // Handle sync events
            break
            
        case .compress, .decompress:
            // Handle compression events
            break
        }
    }
    
    /// Update analytics data
    private func updateAnalyticsData() {
        analyticsData.cacheStats = cacheManager.getCacheStatistics()
        analyticsData.performanceMetrics = performanceMetrics
        analyticsData.lastUpdated = Date()
        
        // Save to storage
        saveAnalyticsData()
    }
}

// MARK: - Cache Analytics Data Models

/// Cache analytics data container
struct CacheAnalyticsData: Codable {
    var cacheStats: CacheStatistics?
    var performanceMetrics: CachePerformanceMetrics?
    var lastUpdated: Date = Date()
    var totalEvents: Int = 0
    var errorCount: Int = 0
    var successRate: Double = 0.0
}

/// Cache analytics export data
struct CacheAnalyticsExport: Codable {
    let analyticsData: CacheAnalyticsData
    let performanceMetrics: CachePerformanceMetrics
    let events: [CacheAnalyticsEvent]
    let exportDate: Date
}

/// Cache recommendation
struct CacheRecommendation: Identifiable {
    let id = UUID()
    let type: CacheRecommendationType
    let priority: CacheRecommendationPriority
    let title: String
    let description: String
    let action: String
    
    enum CacheRecommendationType {
        case lowHitRate
        case highMemoryUsage
        case highDiskUsage
        case slowRetrieval
        case excessiveEvictions
        case corruptedEntries
    }
    
    enum CacheRecommendationPriority {
        case low
        case medium
        case high
        case critical
    }
}

// MARK: - Cache Analytics Extensions

extension CacheAnalyticsService {
    /// Get cache efficiency score (0-100)
    func getCacheEfficiencyScore() -> Double {
        guard let stats = analyticsData.cacheStats else { return 0 }
        
        let hitRateScore = min(performanceMetrics.hitRatePercentage, 100)
        let memoryScore = max(0, 100 - (stats.memorySizeMB / 100) * 100)
        let diskScore = max(0, 100 - (stats.diskSizeMB / 500) * 100)
        let speedScore = max(0, 100 - (performanceMetrics.averageRetrievalTime * 1000))
        
        return (hitRateScore + memoryScore + diskScore + speedScore) / 4
    }
    
    /// Get cache usage trends
    func getCacheUsageTrends() -> CacheUsageTrends {
        let recentEvents = events.suffix(100)
        let hits = recentEvents.filter { $0.eventType == .retrieve && $0.success }.count
        let misses = recentEvents.filter { $0.eventType == .retrieve && !$0.success }.count
        let stores = recentEvents.filter { $0.eventType == .store }.count
        let invalidations = recentEvents.filter { $0.eventType == .invalidate }.count
        
        return CacheUsageTrends(
            hitRate: hits + misses > 0 ? Double(hits) / Double(hits + misses) : 0,
            storeRate: Double(stores) / Double(recentEvents.count),
            invalidationRate: Double(invalidations) / Double(recentEvents.count),
            totalEvents: recentEvents.count
        )
    }
}

/// Cache usage trends
struct CacheUsageTrends {
    let hitRate: Double
    let storeRate: Double
    let invalidationRate: Double
    let totalEvents: Int
}
