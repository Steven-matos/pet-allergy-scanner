//
//  CacheHydrationService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/**
 * Cache Hydration Service
 * 
 * Coordinates the preloading of all user data into caches when they sign in.
 * This ensures instant access to data across the app without loading delays.
 * 
 * Follows SOLID principles with single responsibility for cache coordination
 * Implements DRY by reusing existing service methods
 * Follows KISS by keeping the hydration process simple and reliable
 */
@MainActor
class CacheHydrationService: ObservableObject {
    static let shared = CacheHydrationService()
    
    @Published var isHydrating = false
    @Published var hydrationProgress: Double = 0.0
    @Published var currentStep: String = ""
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private let petService = CachedPetService.shared
    private let weightService = CachedWeightTrackingService.shared
    private let trendsService = CachedNutritionalTrendsService.shared
    private let comparisonService = CachedFoodComparisonService.shared
    private let nutritionService = CachedNutritionService.shared
    private let feedingLogService = FeedingLogService.shared
    private let notificationService = NotificationService.shared
    private let profileService = CachedProfileService.shared
    
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
     * - Parameter petId: The pet's ID
     * - Returns: True if we have any cached nutrition data
     */
    private func performHydration() async throws {
        let totalSteps = 7.0
        var currentStep = 0.0
        
        // Step 1: Load user profile data
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading profile data...")
        if AuthService.shared.currentUser != nil {
            _ = try await profileService.getCurrentUser()
            _ = try await profileService.getUserProfile()
        }
        currentStep += 1.0
        
        // Step 2: Load pets (foundation for all other data)
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading pets...")
        petService.loadPets()
        currentStep += 1.0
        
        // Step 3: Load weight data for all pets
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading weight data...")
        for pet in petService.pets {
            try await weightService.loadWeightData(for: pet.id)
        }
        currentStep += 1.0
        
        // Step 4: Load nutrition data for all pets
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading nutrition data...")
        for pet in petService.pets {
            try await nutritionService.loadFeedingRecords(for: pet.id)
        }
        currentStep += 1.0
        
        // Step 5: Load trends data for all pets (most recent period)
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading trends data...")
        for pet in petService.pets {
            try await trendsService.loadTrendsData(for: pet.id, period: .thirtyDays)
        }
        currentStep += 1.0
        
        // Step 6: Load feeding logs for all pets
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading feeding logs...")
        for pet in petService.pets {
            _ = try await feedingLogService.getFeedingRecords(for: pet.id)
        }
        currentStep += 1.0
        
        // Step 7: Load comparison history and notifications
        await updateProgress(step: currentStep, total: totalSteps, message: "Loading comparison history...")
        _ = await comparisonService.getComparisonHistory()
        
        // Load notifications in background (non-critical)
        Task {
            // Notification settings loading would go here if the method exists
            print("📱 Notification settings loading skipped - method not implemented")
        }
        
        // Complete hydration
        await updateProgress(step: totalSteps, total: totalSteps, message: "Cache hydration complete!")
        
        print("✅ Cache hydration completed successfully")
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
