//
//  CachedScanService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import UIKit
import Combine

/// Enhanced scan service with intelligent caching
/// Implements SOLID principles: Single responsibility for scans + caching
/// Implements DRY principle by extending ScanService functionality
@MainActor
class CachedScanService: ObservableObject {
    static let shared = CachedScanService()
    
    // MARK: - Properties
    
    @Published var recentScans: [Scan] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAnalyzing = false
    @Published var isRefreshing = false
    
    private let apiService = APIService.shared
    private let cacheCoordinator = UnifiedCacheCoordinator.shared
    private let scanService = ScanService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentAnalysisTask: Task<Void, Never>?
    
    /// Current user ID for cache scoping
    private var currentUserId: String? {
        return AuthService.shared.currentUser?.id
    }
    
    // MARK: - Private Helper Methods
    
    /**
     * Safely retrieve scans from cache with error handling
     * - Parameter userId: The user ID
     * - Returns: Cached scans or nil if retrieval fails
     */
    private func safeRetrieveCachedScans(userId: String) -> [Scan]? {
        // Use UnifiedCacheCoordinator for safe cache retrieval
        let scopedKey = CacheKey.scans.scoped(forUserId: userId)
        
        // First, check if the cache key exists and is valid
        guard cacheCoordinator.exists(forKey: scopedKey) else {
            print("❌ Cache key does not exist: \(scopedKey)")
            return nil
        }
        
        // Try to retrieve with a fallback mechanism
        // If this fails due to casting, we'll catch it and clear the cache
        let result = cacheCoordinator.get([Scan].self, forKey: scopedKey)
        
        // If we get nil, it could be due to cache corruption
        if result == nil {
            print("❌ Cache retrieval returned nil, clearing specific cache key")
            cacheCoordinator.invalidate(forKey: scopedKey)
        }
        
        return result
    }
    
    /**
     * Get scans with complete cache bypass if corruption is detected
     * - Parameter petId: The pet ID to get scans for
     * - Returns: Scans from cache or server
     */
    private func getScansWithCacheBypass(petId: String) async -> [Scan] {
        // Try local state first
        let localScans = recentScans.filter { $0.petId == petId }
        if !localScans.isEmpty {
            return localScans
        }
        
        // Try cache with error handling using UnifiedCacheCoordinator
        if let userId = currentUserId {
            let scopedKey = CacheKey.scans.scoped(forUserId: userId)
            
            // Check if cache exists before trying to retrieve
            if cacheCoordinator.exists(forKey: scopedKey) {
                let cachedScans = cacheCoordinator.get([Scan].self, forKey: scopedKey)
                if let scans = cachedScans {
                    let petScans = scans.filter { $0.petId == petId }
                    if !petScans.isEmpty {
                        return petScans
                    }
                } else {
                    print("❌ Cache retrieval returned nil, clearing cache")
                    cacheCoordinator.invalidate(forKey: scopedKey)
                }
            }
        }
        
        // Fallback to server
        do {
            let scans = try await apiService.getScans(petId: petId)
            
            // Cache the result using UnifiedCacheCoordinator
            if let userId = currentUserId {
                let scopedKey = CacheKey.scans.scoped(forUserId: userId)
                cacheCoordinator.set(scans, forKey: scopedKey)
            }
            
            return scans
        } catch {
            print("❌ Failed to fetch scans for pet from server: \(error)")
            return []
        }
    }
    
    /// Cache refresh timer for background updates
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        setupCacheRefreshTimer()
        observeAuthChanges()
    }
    
    // MARK: - Public Interface
    
    /// Load recent scans with intelligent caching
    /// - Parameter forceRefresh: Force refresh from server, bypassing cache
    func loadRecentScans(forceRefresh: Bool = false) {
        guard let userId = currentUserId else {
            self.recentScans = []
            self.isLoading = false
            self.errorMessage = nil
            return
        }
        
        // Try cache first unless force refresh is requested
        if !forceRefresh {
            if let cachedScans = safeRetrieveCachedScans(userId: userId) {
                self.recentScans = cachedScans.sorted { $0.createdAt > $1.createdAt }
                self.isLoading = false
                self.errorMessage = nil
                
                // Trigger background refresh if cache is stale
                refreshScansInBackground()
                return
            }
        }
        
        // Load from server
        loadScansFromServer()
    }
    
    /// Create a new scan with cache invalidation
    /// - Parameters:
    ///   - petId: Pet ID
    ///   - image: Scan image
    ///   - extractedText: Extracted text from image
    func createScan(petId: String, image: UIImage?, extractedText: String?) {
        isLoading = true
        errorMessage = nil
        
        let scanCreate = ScanCreate(
            petId: petId,
            imageUrl: nil, // In a real app, you would upload the image first
            rawText: extractedText,
            status: .pending
        )
        
        Task { @MainActor in
            do {
                let scan = try await apiService.createScan(scanCreate)
                
                // Update local state
                recentScans.insert(scan, at: 0)
                isLoading = false
                
                // Update cache
                await updateScansCache()
                
                // Invalidate related caches
                invalidateRelatedCaches()
                
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Analyze scan text with caching
    /// - Parameters:
    ///   - analysisRequest: Analysis request data
    ///   - completion: Completion handler with analyzed scan
    func analyzeScan(_ analysisRequest: ScanAnalysisRequest, completion: @escaping (Scan) -> Void) {
        // Cancel any existing analysis task
        currentAnalysisTask?.cancel()
        
        isAnalyzing = true
        errorMessage = nil
        
        currentAnalysisTask = Task { @MainActor in
            do {
                let analyzedScan = try await apiService.analyzeScan(analysisRequest)
                
                // Update the scan in our list
                if let index = recentScans.firstIndex(where: { $0.id == analyzedScan.id }) {
                    recentScans[index] = analyzedScan
                } else {
                    recentScans.insert(analyzedScan, at: 0)
                }
                
                // Update cache
                await updateScansCache()
                
                isAnalyzing = false
                completion(analyzedScan)
            } catch {
                isAnalyzing = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Get scan by ID with caching
    /// - Parameter id: Scan ID
    /// - Returns: Scan if found, nil otherwise
    func getScan(id: String) -> Scan? {
        // Try local state first
        if let scan = recentScans.first(where: { $0.id == id }) {
            return scan
        }
        
        // Try cache
        if let userId = currentUserId,
           let cachedScans = safeRetrieveCachedScans(userId: userId),
           let scan = cachedScans.first(where: { $0.id == id }) {
            return scan
        }
        
        return nil
    }
    
    /// Get scan by ID with server fallback
    /// - Parameter id: Scan ID
    /// - Returns: Scan from server or cache
    func getScanWithFallback(id: String) async -> Scan? {
        // Try local state first
        if let scan = recentScans.first(where: { $0.id == id }) {
            return scan
        }
        
        // Try cache
        if let userId = currentUserId,
           let cachedScans = safeRetrieveCachedScans(userId: userId),
           let scan = cachedScans.first(where: { $0.id == id }) {
            return scan
        }
        
        // Fallback to server
        do {
            let scan = try await apiService.getScan(id: id)
            
            // Cache the result using UnifiedCacheCoordinator
            if let userId = currentUserId {
                let scopedKey = CacheKey.scans.scoped(forUserId: userId)
                cacheCoordinator.set(scan, forKey: scopedKey)
            }
            
            return scan
        } catch {
            print("❌ Failed to fetch scan from server: \(error)")
            return nil
        }
    }
    
    /// Get scans for specific pet with caching
    /// - Parameter petId: Pet ID
    /// - Returns: Scans for the pet
    func getScansForPet(petId: String) -> [Scan] {
        return recentScans.filter { $0.petId == petId }
    }
    
    /// Get scans for specific pet with server fallback
    /// - Parameter petId: Pet ID
    /// - Returns: Scans for the pet from server or cache
    func getScansForPetWithFallback(petId: String) async -> [Scan] {
        // Use the safer cache bypass method to avoid casting errors
        return await getScansWithCacheBypass(petId: petId)
    }
    
    /// Refresh scans data from server
    func refreshScans() {
        loadRecentScans(forceRefresh: true)
    }
    
    /// Cancel current analysis task
    func cancelAnalysis() {
        currentAnalysisTask?.cancel()
        isAnalyzing = false
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Clear all scans and cache (called during logout)
    func clearScans() {
        recentScans = []
        errorMessage = nil
        isLoading = false
        isAnalyzing = false
        isRefreshing = false
        currentAnalysisTask?.cancel()
        
        // Clear user-specific cache using UnifiedCacheCoordinator
        if let userId = currentUserId {
            cacheCoordinator.clearUserCache(userId: userId)
        }
        
        // Stop refresh timer
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Private Methods
    
    /// Load scans from server
    private func loadScansFromServer() {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let scans = try await apiService.getScans()
                
                // Update local state
                recentScans = scans.sorted { $0.createdAt > $1.createdAt }
                isLoading = false
                
                // Update cache
                await updateScansCache()
                
            } catch let apiError as APIError {
                isLoading = false
                
                // Handle auth errors silently
                if case .authenticationError = apiError {
                    recentScans = []
                    errorMessage = nil
                } else {
                    errorMessage = apiError.localizedDescription
                }
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Update scans cache using UnifiedCacheCoordinator
    private func updateScansCache() async {
        guard let userId = currentUserId else { return }
        
        // Cache the scans list
        let scansKey = CacheKey.scans.scoped(forUserId: userId)
        cacheCoordinator.set(recentScans, forKey: scansKey)
        
        // Cache scan history (last 50 scans)
        let historyScans = Array(recentScans.prefix(50))
        let historyKey = CacheKey.scanHistory.scoped(forUserId: userId)
        cacheCoordinator.set(historyScans, forKey: historyKey)
    }
    
    /// Refresh scans in background if cache is stale
    private func refreshScansInBackground() {
        guard let userId = currentUserId else { return }
        
        // Check if cache is stale using UnifiedCacheCoordinator
        let cacheKey = CacheKey.scans.scoped(forUserId: userId)
        if !cacheCoordinator.exists(forKey: cacheKey) {
            isRefreshing = true
            
            Task { @MainActor in
                do {
                    let scans = try await apiService.getScans()
                    let sortedScans = scans.sorted { $0.createdAt > $1.createdAt }
                    
                    // Update local state only if it's different
                    if self.recentScans != sortedScans {
                        self.recentScans = sortedScans
                        await updateScansCache()
                    }
                    
                    self.isRefreshing = false
                } catch {
                    print("❌ Background refresh failed: \(error)")
                    self.isRefreshing = false
                }
            }
        }
    }
    
    /// Setup cache refresh timer
    private func setupCacheRefreshTimer() {
        // Refresh cache every 5 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshScansInBackground()
            }
        }
    }
    
    /// Observe authentication changes
    private func observeAuthChanges() {
        // This would typically use Combine or NotificationCenter
        // For now, we'll handle it in the loadRecentScans method
    }
    
    /// Invalidate related caches when scans change using UnifiedCacheCoordinator
    private func invalidateRelatedCaches() {
        guard let userId = currentUserId else { return }
        
        // Invalidate scan history cache
        cacheCoordinator.invalidate(forKey: CacheKey.scanHistory.scoped(forUserId: userId))
    }
}

// MARK: - Cache Analytics Extension

extension CachedScanService {
    /// Get cache statistics for scans
    func getCacheStats() -> [String: Any] {
        var stats: [String: Any] = [:]
        
        // Get cache stats from UnifiedCacheCoordinator
        let cacheStats = cacheCoordinator.cacheStats
        stats["hits"] = cacheStats.hits
        stats["misses"] = cacheStats.misses
        stats["stores"] = cacheStats.stores
        stats["invalidations"] = cacheStats.invalidations
        
        // Add scan-specific stats
        stats["scans_count"] = recentScans.count
        stats["is_loading"] = isLoading
        stats["is_analyzing"] = isAnalyzing
        stats["is_refreshing"] = isRefreshing
        stats["has_error"] = errorMessage != nil
        
        return stats
    }
    
    /// Get scan cache hit rate
    func getCacheHitRate() -> Double {
        // This would require tracking hits/misses in the cache service
        // For now, return a placeholder
        return 0.0
    }
    
    /// Get scan statistics
    func getScanStatistics() -> [String: Any] {
        let totalScans = recentScans.count
        let pendingScans = recentScans.filter { $0.status == .pending }.count
        let completedScans = recentScans.filter { $0.status == .completed }.count
        let failedScans = recentScans.filter { $0.status == .failed }.count
        
        let scansByPet = Dictionary(grouping: recentScans, by: { $0.petId })
        let petScanCounts = scansByPet.mapValues { $0.count }
        
        return [
            "total_scans": totalScans,
            "pending_scans": pendingScans,
            "completed_scans": completedScans,
            "failed_scans": failedScans,
            "scans_by_pet": petScanCounts,
            "average_scans_per_pet": petScanCounts.values.isEmpty ? 0 : Double(totalScans) / Double(petScanCounts.count)
        ]
    }
}
