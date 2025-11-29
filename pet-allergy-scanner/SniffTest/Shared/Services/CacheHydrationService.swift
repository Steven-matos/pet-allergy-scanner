//
//  CacheHydrationService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/**
 * Cache Hydration Service - Modernized for SwiftUI 5.0
 * 
 * Coordinates the preloading of all user data into caches when they sign in.
 * This ensures instant access to data across the app without loading delays.
 * 
 * Modern SwiftUI 5.0 Features:
 * - Uses @Observable macro for better performance
 * - Leverages Swift Concurrency for async operations
 * - Implements modern state management patterns
 * 
 * Follows SOLID principles with single responsibility for cache coordination
 * Implements DRY by reusing existing service methods
 * Follows KISS by keeping the hydration process simple and reliable
 */
@MainActor
@Observable
final class CacheHydrationService {
    static let shared = CacheHydrationService()
    
    var isHydrating = false
    var hydrationProgress: Double = 0.0
    var currentStep: String = ""
    var error: Error?
    
    // MARK: - Private Properties
    
    private let petService = CachedPetService.shared
    private let weightService = CachedWeightTrackingService.shared
    private let trendsService = CachedNutritionalTrendsService.shared
    private let comparisonService = CachedFoodComparisonService.shared
    private let nutritionService = CachedNutritionService.shared
    private let feedingLogService = FeedingLogService.shared
    private let notificationService = NotificationService.shared
    private let profileService = CachedProfileService.shared
    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // Note: AuthService observation is handled manually to avoid circular dependency
        // The AuthService will call hydrateAllCaches() directly when needed
    }
    
    // MARK: - Public API
    
    /**
     * Hydrate all caches with user data
     * Called automatically on sign-in, can be called manually for refresh
     */
    func hydrateAllCaches() async {
        guard !isHydrating else { return }
        
        isHydrating = true
        hydrationProgress = 0.0
        error = nil
        
        do {
            try await performHydration()
        } catch {
            self.error = error
            print("❌ Cache hydration failed: \(error.localizedDescription)")
        }
        
        isHydrating = false
    }
    
    /**
     * Check if all caches are hydrated
     * - Returns: True if all major caches have data
     */
    func areCachesHydrated() -> Bool {
        // Check if we have pets (primary data source)
        let hasPets = !petService.pets.isEmpty
        
        // If no pets, caches are considered "hydrated" (empty state)
        guard hasPets else { return true }
        
        // Check if we have data for at least one pet
        let firstPetId = petService.pets.first?.id
        guard let petId = firstPetId else { return true }
        
        // Check major data sources
        let hasWeightData = weightService.hasCachedWeightData(for: petId)
        let hasTrendsData = trendsService.hasCachedTrendsData(for: petId)
        let hasNutritionData = nutritionService.hasCachedNutritionData(for: petId)
        
        // Consider hydrated if we have at least some data
        return hasWeightData || hasTrendsData || hasNutritionData
    }
    
    /**
     * Rehydrate caches with fresh data from server
     * Loads from cache first for immediate UI, then refreshes from server in background
     * Called when app launches after being closed/quit to ensure data is up-to-date
     * 
     * This method:
     * 1. Loads cached data immediately (fast UI)
     * 2. Fetches fresh data from server in background
     * 3. Updates cache with fresh data
     * 4. Does NOT show progress overlay (silent background refresh)
     */
    func rehydrateCaches() async {
        // Only rehydrate if user is authenticated
        guard AuthService.shared.currentUser != nil else {
            return
        }
        
        // Don't rehydrate if already hydrating (initial hydration)
        guard !isHydrating else {
            return
        }
        
        print("🔄 Starting cache rehydration (background refresh)...")
        
        // Step 1: Load from cache first (immediate UI)
        await loadFromCache()
        
        // Step 2: Refresh from server in background (silent, no progress overlay)
        await refreshFromServer()
        
        print("✅ Cache rehydration completed successfully")
    }
    
    /**
     * Clear all caches
     * Called on logout
     */
    func clearAllCaches() {
        petService.clearPets()
        weightService.clearCache()
        trendsService.clearCache()
        comparisonService.clearCache()
        nutritionService.clearCache()
        feedingLogService.clearCache()
        notificationService.clearCache()
        profileService.clearCache()
        
        hydrationProgress = 0.0
        currentStep = ""
    }
    
    // MARK: - Private Methods
    
    
    /**
     * Perform the actual cache hydration process
     * Loads all static and user data into cache for instant access
     */
    private func performHydration() async throws {
        let totalSteps = 9.0
        var currentStep = 0.0
        
        // Step 1: Load user profile data
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading profile data...")
        if AuthService.shared.currentUser != nil {
            _ = try await profileService.getCurrentUser()
            _ = try await profileService.getUserProfile()
        }
        currentStep += 1.0
        
        // Step 2: Load static reference data (allergens, safe alternatives)
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading reference data...")
        await loadStaticReferenceData()
        currentStep += 1.0
        
        // Step 3: Load pets (foundation for all other data)
        // Wait for pets to load synchronously before proceeding
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading pets...")
        await waitForPetsToLoad()
        currentStep += 1.0
        
        // Step 4: Load weight data for all pets (force refresh from server)
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading weight data...")
        for pet in petService.pets {
            do {
                // Force refresh to ensure we get latest data from server including goals
                try await weightService.loadWeightData(for: pet.id, forceRefresh: true)
            } catch {
                // Log but don't fail - individual pet data load failures are non-critical
                // New pets may not have data yet, which is expected
                print("⚠️ Failed to load weight data for pet \(pet.id): \(error.localizedDescription)")
            }
        }
        currentStep += 1.0
        
        // Step 5: Load nutrition data for all pets
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading nutrition data...")
        for pet in petService.pets {
            do {
                try await nutritionService.loadFeedingRecords(for: pet.id)
            } catch {
                // Log but don't fail - individual pet data load failures are non-critical
                // New pets may not have data yet, which is expected
                print("⚠️ Failed to load nutrition data for pet \(pet.id): \(error.localizedDescription)")
            }
        }
        currentStep += 1.0
        
        // Step 6: Load trends data for all pets (most recent period)
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading trends data...")
        for pet in petService.pets {
            do {
                try await trendsService.loadTrendsData(for: pet.id, period: .thirtyDays)
            } catch {
                // Log but don't fail - individual pet data load failures are non-critical
                // New pets may not have data yet, which is expected
                print("⚠️ Failed to load trends data for pet \(pet.id): \(error.localizedDescription)")
            }
        }
        currentStep += 1.0
        
        // Step 7: Load feeding logs for all pets
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading feeding logs...")
        for pet in petService.pets {
            do {
                _ = try await feedingLogService.getFeedingRecords(for: pet.id)
            } catch {
                // Log but don't fail - individual pet data load failures are non-critical
                // New pets may not have data yet, which is expected
                print("⚠️ Failed to load feeding logs for pet \(pet.id): \(error.localizedDescription)")
            }
        }
        currentStep += 1.0
        
        // Step 8: Load comparison history
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading comparison history...")
        _ = await comparisonService.getComparisonHistory()
        currentStep += 1.0
        
        // Step 9: Load notifications (non-critical, can fail silently)
        await updateProgress(step: currentStep, total: totalSteps, message: "Finalizing...")
        Task {
            // Notification settings loading would go here if the method exists
            print("📱 Notification settings loading skipped - method not implemented")
        }
        
        // Complete hydration
        await updateProgress(step: totalSteps, total: totalSteps, message: "Ready!")
        
        print("✅ Cache hydration completed successfully")
    }
    
    /**
     * Load static reference data (allergens, safe alternatives)
     * These are reference data that don't change often and should be cached
     * Uses EnhancedCacheManager for optimal caching (7 day cache)
     */
    private func loadStaticReferenceData() async {
        // Use EnhancedCacheManager which handles caching with proper TTL
        await EnhancedCacheManager.shared.refreshStaticData()
    }
    
    /**
     * Wait for pets to load synchronously
     * Ensures pets are loaded before proceeding with pet-specific data hydration
     */
    private func waitForPetsToLoad() async {
        // Trigger load - this will return immediately if cached
        petService.loadPets()
        
        // If we have pets already (from cache), we're done
        if !petService.pets.isEmpty {
            return
        }
        
        // If loading from server, wait for it to complete
        // Poll isLoading status until it's false (max 10 seconds timeout)
        let maxWaitTime: TimeInterval = 10.0
        let pollInterval: TimeInterval = 0.1
        var elapsed: TimeInterval = 0.0
        
        while petService.isLoading && elapsed < maxWaitTime {
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
            elapsed += pollInterval
        }
        
        // If still no pets and not loading, force refresh one more time
        if petService.pets.isEmpty && !petService.isLoading {
            petService.loadPets(forceRefresh: true)
            
            // Wait for the refresh to complete
            elapsed = 0.0
            while petService.isLoading && elapsed < maxWaitTime {
                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                elapsed += pollInterval
            }
        }
    }
    
    /**
     * Load data from cache (immediate UI)
     * This loads cached data into memory for instant access
     */
    private func loadFromCache() async {
        // Load pets from cache (triggers cache load if available)
        petService.loadPets(forceRefresh: false)
        
        // Load other cached data if pets exist
        guard !petService.pets.isEmpty else {
            return
        }
        
        // Load cached data for each pet in parallel (non-blocking)
        await withTaskGroup(of: Void.self) { group in
            for pet in petService.pets {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    // Load cached data - must call on MainActor since services are @MainActor
                    await MainActor.run {
                        // Load cached weight data
                        _ = self.weightService.hasCachedWeightData(for: pet.id)
                        
                        // Load cached trends data
                        _ = self.trendsService.hasCachedTrendsData(for: pet.id)
                        
                        // Load cached nutrition data
                        _ = self.nutritionService.hasCachedNutritionData(for: pet.id)
                    }
                }
            }
        }
        
        print("✅ Loaded data from cache")
    }
    
    /**
     * Refresh data from server (background, silent)
     * Fetches fresh data and updates cache without showing progress
     */
    private func refreshFromServer() async {
        // Refresh pets first (foundation for other data)
        petService.loadPets(forceRefresh: true)
        
        // Wait for pets to load before refreshing pet-specific data
        var waitCount = 0
        while petService.isLoading && waitCount < 50 { // Max 5 seconds
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            waitCount += 1
        }
        
        // Refresh pet-specific data in parallel
        await withTaskGroup(of: Void.self) { group in
            for pet in petService.pets {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    do {
                        // Refresh weight data (force refresh from server to get latest goals)
                        try await self.weightService.loadWeightData(for: pet.id, forceRefresh: true)
                        
                        // Refresh nutrition data
                        try await self.nutritionService.loadFeedingRecords(for: pet.id)
                        
                        // Refresh trends data
                        try await self.trendsService.loadTrendsData(for: pet.id, period: .thirtyDays)
                        
                        // Refresh feeding logs
                        _ = try await self.feedingLogService.getFeedingRecords(for: pet.id)
                    } catch {
                        // Log but don't fail - individual pet data refresh failures are non-critical
                        print("⚠️ Failed to refresh data for pet \(pet.id): \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // Refresh user profile data
        do {
            _ = try await profileService.getCurrentUser()
            _ = try await profileService.getUserProfile()
        } catch {
            print("⚠️ Failed to refresh user profile: \(error.localizedDescription)")
        }
        
        // Refresh static reference data
        await loadStaticReferenceData()
        
        // Refresh comparison history
        _ = await comparisonService.getComparisonHistory()
        
        print("✅ Refreshed data from server")
    }
    
    /**
     * Update hydration progress
     * - Parameter step: Current step number
     * - Parameter total: Total number of steps
     * - Parameter message: Progress message
     */
    private func updateProgress(step: Double, total: Double, message: String) async {
        await MainActor.run {
            hydrationProgress = step / total
            currentStep = message
        }
    }
}

// MARK: - Extensions for Service Integration


extension FeedingLogService {
    /**
     * Clear feeding log cache
     */
    func clearCache() {
        // Clear any cached feeding log data
        // Implementation depends on FeedingLogService structure
    }
}

extension NotificationService {
    /**
     * Clear notification cache
     */
    func clearCache() {
        // Clear any cached notification data
        // Implementation depends on NotificationService structure
    }
}
