//
//  CachedNutritionService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import Combine

/**
 * Cached Nutrition Service
 * 
 * Provides cached access to nutrition data with automatic cache management.
 * Implements cache-first pattern for optimal performance.
 * 
 * Follows SOLID principles: Single responsibility for cached nutrition operations
 * Implements DRY by reusing cache patterns from existing cached services
 * Follows KISS by keeping the caching logic simple and transparent
 */
@MainActor
class CachedNutritionService: ObservableObject {
    static let shared = CachedNutritionService()
    
    // MARK: - Published Properties for SwiftUI Observation
    
    /**
     * In-memory cache for SwiftUI observation (synchronized with UnifiedCacheCoordinator)
     * These are @Published to trigger SwiftUI updates
     */
    @Published private var nutritionalRequirementsCache: [String: PetNutritionalRequirements] = [:]
    @Published private var dailySummariesCache: [String: [DailyNutritionSummary]] = [:]
    @Published var foodAnalyses: [FoodNutritionalAnalysis] = []
    @Published var feedingRecords: [FeedingRecord] = []
    
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Services
    
    private let apiService: APIService
    private let cacheCoordinator = UnifiedCacheCoordinator.shared
    private let cacheLoader = CacheFirstDataLoader.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Current user ID for cache scoping
    private var currentUserId: String? {
        authService.currentUser?.id
    }
    
    private init() {
        self.apiService = APIService.shared
        loadCacheFromDisk()
        observeAuthChanges()
    }
    
    /**
     * Load cache from disk synchronously on init
     */
    private func loadCacheFromDisk() {
        // Load cached data into memory for SwiftUI observation
        // This happens synchronously so views can access data immediately
        if authService.currentUser?.id != nil {
            // Load pets to get pet IDs
            let pets = CachedPetService.shared.pets
            for pet in pets {
                let requirementsKey = CacheKey.nutritionRequirements.scoped(forPetId: pet.id)
                if let cached = cacheCoordinator.get(PetNutritionalRequirements.self, forKey: requirementsKey) {
                    nutritionalRequirementsCache[pet.id] = cached
                }
                
                let summariesKey = CacheKey.dailySummaries.scoped(forPetId: pet.id)
                if let cached = cacheCoordinator.get([DailyNutritionSummary].self, forKey: summariesKey) {
                    dailySummariesCache[pet.id] = cached
                }
                
                let recordsKey = CacheKey.feedingRecords.scoped(forPetId: pet.id)
                if let cached = cacheCoordinator.get([FeedingRecord].self, forKey: recordsKey) {
                    feedingRecords = cached
                }
            }
        }
    }
    
    // MARK: - Computed Properties for Views
    
    /**
     * Get nutritional requirements for a pet (for SwiftUI views)
     */
    func nutritionalRequirements(for petId: String) -> PetNutritionalRequirements? {
        return nutritionalRequirementsCache[petId]
    }
    
    /**
     * Get daily summaries for a pet (for SwiftUI views)
     */
    func dailySummaries(for petId: String) -> [DailyNutritionSummary] {
        return dailySummariesCache[petId] ?? []
    }
    
    // MARK: - Authentication Observation
    
    /**
     * Observe authentication changes to manage user-specific cache
     */
    private func observeAuthChanges() {
        authService.$authState
            .sink { [weak self] authState in
                if !authState.isAuthenticated {
                    // Clear cache on logout
                    self?.clearCache()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Nutritional Requirements
    
    /**
     * Get nutritional requirements with cache-first approach
     * Uses UnifiedCacheCoordinator for all cache operations
     * - Parameter petId: The pet's ID
     * - Returns: Nutritional requirements from cache or server
     */
    func getNutritionalRequirements(for petId: String) async throws -> PetNutritionalRequirements {
        guard currentUserId != nil else {
            throw APIError.authenticationError
        }
        
        let cacheKey = CacheKey.nutritionRequirements.scoped(forPetId: petId)
        
        // Try cache first (synchronous)
        if let cached = cacheCoordinator.get(PetNutritionalRequirements.self, forKey: cacheKey) {
            nutritionalRequirementsCache[petId] = cached
            objectWillChange.send()
            
            // Refresh in background if needed
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                do {
                    let fresh = try await self.loadNutritionalRequirementsFromServer(for: petId)
                    self.cacheCoordinator.set(fresh, forKey: cacheKey)
                    self.nutritionalRequirementsCache[petId] = fresh
                    self.objectWillChange.send()
                } catch {
                    // If 404, handle resource deleted
                    if let apiError = error as? APIError,
                       case .serverError(let statusCode) = apiError,
                       statusCode == 404 {
                        self.cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                    }
                }
            }
            return cached
        }
        
        // Cache miss - try server
        do {
            let requirements = try await loadNutritionalRequirementsFromServer(for: petId)
            cacheCoordinator.set(requirements, forKey: cacheKey)
            nutritionalRequirementsCache[petId] = requirements
            objectWillChange.send()
            return requirements
        } catch {
            // If server fails (404/500 error), try to calculate requirements locally
            print("⚠️ Server failed to load nutritional requirements for pet \(petId), calculating locally: \(error)")
            
            // Handle 404 - resource deleted
            if let apiError = error as? APIError,
               case .serverError(let statusCode) = apiError,
               statusCode == 404 {
                cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                throw CacheError.resourceDeleted
            }
            
            // Get the pet to calculate requirements
            guard let pet = CachedPetService.shared.pets.first(where: { $0.id == petId }) else {
                throw error
            }
            
            // Calculate requirements locally
            let requirements = PetNutritionalRequirements.calculate(for: pet)
            cacheCoordinator.set(requirements, forKey: cacheKey)
            nutritionalRequirementsCache[petId] = requirements
            objectWillChange.send()
            
            return requirements
        }
    }
    
    /**
     * Calculate and cache nutritional requirements for a pet
     * - Parameter pet: The pet to calculate requirements for
     * - Returns: Calculated nutritional requirements
     */
    func calculateNutritionalRequirements(for pet: Pet) async throws -> PetNutritionalRequirements {
        let requirements = PetNutritionalRequirements.calculate(for: pet)
        
        // Cache using UnifiedCacheCoordinator
        if currentUserId != nil {
            let cacheKey = CacheKey.nutritionRequirements.scoped(forPetId: pet.id)
            cacheCoordinator.set(requirements, forKey: cacheKey)
            nutritionalRequirementsCache[pet.id] = requirements
            objectWillChange.send()
        }
        
        // Save to server
        try await saveNutritionalRequirementsToServer(requirements)
        
        return requirements
    }
    
    /**
     * Load nutritional requirements from server
     * - Parameter petId: The pet's ID
     * - Returns: Nutritional requirements from server
     */
    private func loadNutritionalRequirementsFromServer(for petId: String) async throws -> PetNutritionalRequirements {
        return try await apiService.get(
            endpoint: "/nutrition/requirements/\(petId)",
            responseType: PetNutritionalRequirements.self
        )
    }
    
    /**
     * Save nutritional requirements to server
     * - Parameter requirements: The requirements to save
     */
    private func saveNutritionalRequirementsToServer(_ requirements: PetNutritionalRequirements) async throws {
        let _: EmptyResponse = try await apiService.post(
            endpoint: "/nutrition/requirements",
            body: requirements,
            responseType: EmptyResponse.self
        )
    }
    
    // MARK: - Food Analysis
    
    /**
     * Analyze food nutritional content with caching
     * - Parameter request: The analysis request
     * - Returns: Food nutritional analysis
     */
    func analyzeFood(_ request: NutritionAnalysisRequest) async throws -> FoodNutritionalAnalysis {
        isLoading = true
        error = nil
        
        do {
            let analysis: FoodNutritionalAnalysis = try await apiService.post(
                endpoint: "/nutrition/analyze",
                body: request,
                responseType: FoodNutritionalAnalysis.self
            )
            
            foodAnalyses.append(analysis)
            
            // Check compatibility with pet's requirements
            if let requirements = nutritionalRequirementsCache[request.petId] {
                let compatibility = analysis.assessCompatibility(with: requirements)
                print("Food compatibility: \(compatibility.compatibility.rawValue) (\(compatibility.score))")
            }
            
            isLoading = false
            return analysis
            
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    /**
     * Load food analyses for a pet with caching
     * - Parameter petId: The pet's ID
     */
    func loadFoodAnalyses(for petId: String) async throws {
        guard currentUserId != nil else { return }
        
        let cacheKey = CacheKey.feedingRecords.scoped(forPetId: petId)
        
        // Try cache first (synchronous)
        if let cached = cacheCoordinator.get([FoodNutritionalAnalysis].self, forKey: cacheKey) {
            // Update local cache
            for analysis in cached {
                if !foodAnalyses.contains(where: { $0.id == analysis.id }) {
                    foodAnalyses.append(analysis)
                }
            }
            objectWillChange.send()
            return
        }
        
        // Fallback to server
        do {
            let analyses: [FoodNutritionalAnalysis] = try await apiService.get(
                endpoint: "/nutrition/analyses/\(petId)",
                responseType: [FoodNutritionalAnalysis].self
            )
            
            // Update local cache
            await MainActor.run {
                for analysis in analyses {
                    if !self.foodAnalyses.contains(where: { $0.id == analysis.id }) {
                        self.foodAnalyses.append(analysis)
                    }
                }
                self.objectWillChange.send()
            }
            
            // Cache the result
            cacheCoordinator.set(analyses, forKey: cacheKey)
        } catch {
            // Handle 404
            if let apiError = error as? APIError,
               case .serverError(let statusCode) = apiError,
               statusCode == 404 {
                cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
            }
            throw error
        }
    }
    
    /**
     * Get food analysis by ID
     * - Parameter analysisId: The analysis ID
     * - Returns: Food analysis if found
     */
    func getFoodAnalysis(by analysisId: String) -> FoodNutritionalAnalysis? {
        return foodAnalyses.first { $0.id == analysisId }
    }
    
    // MARK: - Feeding Records
    
    /**
     * Record a feeding instance with cache invalidation
     * - Parameter request: The feeding record request
     * - Returns: Created feeding record
     */
    func recordFeeding(_ request: FeedingRecordRequest) async throws -> FeedingRecord {
        let record: FeedingRecord = try await apiService.post(
            endpoint: "/nutrition/feeding",
            body: request,
            responseType: FeedingRecord.self
        )
        
        // Use ObservableCacheManager pattern - arrays need explicit observation
        await MainActor.run {
            self.feedingRecords.append(record)
            objectWillChange.send()
        }
        
        // Invalidate related caches using UnifiedCacheCoordinator
        if currentUserId != nil {
            let cacheKey = CacheKey.feedingRecords.scoped(forPetId: request.petId)
            cacheCoordinator.invalidate(forKey: cacheKey)
            
            // Also invalidate daily summaries cache
            let dailySummariesKey = CacheKey.dailySummaries.scoped(forPetId: request.petId)
            cacheCoordinator.invalidate(forKey: dailySummariesKey)
        }
        
        // Invalidate trends cache so trends update with new feeding data
        // Auto-reload trends after a brief delay to ensure data is saved
        let trendsService = CachedNutritionalTrendsService.shared
        trendsService.invalidateTrendsCache(for: request.petId, autoReload: true)
        
        // Update daily summary
        await updateDailySummary(for: request.petId, date: request.feedingTime)
        
        // Force refresh feeding records to ensure UI updates
        try await loadFeedingRecords(for: request.petId, days: 30, forceRefresh: true)
        
        // Force refresh daily summaries to ensure UI updates
        try await loadDailySummaries(for: request.petId, days: 30)
        
        return record
    }
    
    /**
     * Load feeding records for a pet with caching
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to load (default: 30)
     * - Parameter forceRefresh: If true, bypasses cache and fetches fresh data from server
     */
    func loadFeedingRecords(for petId: String, days: Int = 30, forceRefresh: Bool = false) async throws {
        guard currentUserId != nil else { return }
        
        let cacheKey = CacheKey.feedingRecords.scoped(forPetId: petId)
        
        // Invalidate cache if force refresh is requested
        if forceRefresh {
            cacheCoordinator.invalidate(forKey: cacheKey)
            // Also clear in-memory cache for this pet
            feedingRecords.removeAll { $0.petId == petId }
        }
        
        // Try cache first (unless force refresh) - synchronous for immediate UI
        if !forceRefresh {
            if let cached = cacheCoordinator.get([FeedingRecord].self, forKey: cacheKey) {
                // Update local cache
                await MainActor.run {
                    self.feedingRecords.removeAll { $0.petId == petId }
                    self.feedingRecords.append(contentsOf: cached)
                    self.objectWillChange.send()
                }
                
                // Refresh in background
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    do {
                        // Server endpoint doesn't support days parameter - returns all records
                        let allFresh = try await self.apiService.get(
                            endpoint: "/nutrition/feeding/\(petId)",
                            responseType: [FeedingRecord].self
                        )
                        
                        // Filter by days client-side
                        let fresh: [FeedingRecord]
                        if days > 0 {
                            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                            fresh = allFresh.filter { $0.feedingTime >= cutoffDate }
                        } else {
                            fresh = allFresh
                        }
                        self.cacheCoordinator.set(fresh, forKey: cacheKey)
                        self.feedingRecords.removeAll { $0.petId == petId }
                        self.feedingRecords.append(contentsOf: fresh)
                        self.objectWillChange.send()
                    } catch {
                        // Handle 404
                        if let apiError = error as? APIError,
                           case .serverError(let statusCode) = apiError,
                           statusCode == 404 {
                            self.cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                        }
                    }
                }
                return
            }
        }
        
        // Cache miss or force refresh - fetch from server
        // Note: Server endpoint doesn't support days parameter - it returns all records
        // We filter client-side based on the days parameter
        do {
            let allRecords: [FeedingRecord] = try await apiService.get(
                endpoint: "/nutrition/feeding/\(petId)",
                responseType: [FeedingRecord].self
            )
            
            // Filter records by days client-side
            let records: [FeedingRecord]
            if days > 0 {
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                records = allRecords.filter { $0.feedingTime >= cutoffDate }
            } else {
                records = allRecords
            }
            
            // Replace all records for this pet (not append) to ensure consistency
            await MainActor.run {
                self.feedingRecords.removeAll { $0.petId == petId }
                self.feedingRecords.append(contentsOf: records)
                self.objectWillChange.send()
            }
            
            // Cache the result
            cacheCoordinator.set(records, forKey: cacheKey)
        } catch {
            // Handle 404
            if let apiError = error as? APIError,
               case .serverError(let statusCode) = apiError,
               statusCode == 404 {
                cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
            }
            throw error
        }
    }
    
    /**
     * Get feeding records for a specific date
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to get records for
     * - Returns: Feeding records for the date
     */
    func getFeedingRecords(for petId: String, on date: Date) -> [FeedingRecord] {
        let calendar = Calendar.current
        return feedingRecords.filter { record in
            record.petId == petId && calendar.isDate(record.feedingTime, inSameDayAs: date)
        }
    }
    
    // MARK: - Daily Summaries
    
    /**
     * Load daily summaries for a pet with caching
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to load (default: 30)
     * - Parameter forceRefresh: If true, bypasses cache and fetches fresh data from server
     */
    func loadDailySummaries(for petId: String, days: Int = 30, forceRefresh: Bool = false) async throws {
        guard currentUserId != nil else { return }
        
        let cacheKey = CacheKey.dailySummaries.scoped(forPetId: petId)
        
        // Invalidate cache if force refresh is requested
        if forceRefresh {
            cacheCoordinator.invalidate(forKey: cacheKey)
        }
        
        // Try cache first (unless force refresh) - synchronous for immediate UI
        if !forceRefresh {
            if let cached = cacheCoordinator.get([DailyNutritionSummary].self, forKey: cacheKey) {
                dailySummariesCache[petId] = cached
                objectWillChange.send()
                
                // Refresh in background
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    do {
                        let fresh = try await self.apiService.get(
                            endpoint: "/nutrition/summaries/\(petId)?days=\(days)",
                            responseType: [DailyNutritionSummary].self
                        )
                        self.cacheCoordinator.set(fresh, forKey: cacheKey)
                        self.dailySummariesCache[petId] = fresh
                        self.objectWillChange.send()
                    } catch {
                        // Handle 404
                        if let apiError = error as? APIError,
                           case .serverError(let statusCode) = apiError,
                           statusCode == 404 {
                            self.cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                        }
                    }
                }
                return
            }
        }
        
        // Cache miss or force refresh - fetch from server
        do {
            let summaries: [DailyNutritionSummary] = try await apiService.get(
                endpoint: "/nutrition/summaries/\(petId)?days=\(days)",
                responseType: [DailyNutritionSummary].self
            )
            
            dailySummariesCache[petId] = summaries
            cacheCoordinator.set(summaries, forKey: cacheKey)
            objectWillChange.send()
        } catch {
            // Handle 404
            if let apiError = error as? APIError,
               case .serverError(let statusCode) = apiError,
               statusCode == 404 {
                cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
            }
            throw error
        }
    }
    
    /**
     * Get daily summary for a specific date
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to get summary for
     * - Returns: Daily summary if available
     */
    func getDailySummary(for petId: String, on date: Date) -> DailyNutritionSummary? {
        let calendar = Calendar.current
        return dailySummariesCache[petId]?.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    /**
     * Update daily nutrition summary for a pet
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to update
     */
    private func updateDailySummary(for petId: String, date: Date) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let dayRecords = getFeedingRecords(for: petId, on: date)
        
        var totalCalories = 0.0
        var totalProtein = 0.0
        var totalFat = 0.0
        var totalFiber = 0.0
        var compatibilityScores: [Double] = []
        var recommendations: [String] = []
        
        for record in dayRecords {
            if let analysis = getFoodAnalysis(by: record.foodAnalysisId) {
                totalCalories += record.calculateCaloriesConsumed(from: analysis)
                totalProtein += (analysis.proteinPercentage / 100.0) * record.amountGrams
                totalFat += (analysis.fatPercentage / 100.0) * record.amountGrams
                totalFiber += (analysis.fiberPercentage / 100.0) * record.amountGrams
                
                if let requirements = nutritionalRequirementsCache[petId] {
                    let compatibility = analysis.assessCompatibility(with: requirements)
                    compatibilityScores.append(compatibility.score)
                    recommendations.append(contentsOf: compatibility.recommendations)
                }
            }
        }
        
        let averageCompatibility = compatibilityScores.isEmpty ? 0.0 : compatibilityScores.reduce(0, +) / Double(compatibilityScores.count)
        
        let summary = DailyNutritionSummary(
            petId: petId,
            date: startOfDay,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalFat: totalFat,
            totalFiber: totalFiber,
            feedingCount: dayRecords.count,
            averageCompatibility: averageCompatibility,
            recommendations: Array(Set(recommendations)) // Remove duplicates
        )
        
        // Update in-memory cache and UnifiedCacheCoordinator
        await MainActor.run {
            var currentSummaries = self.dailySummariesCache[petId] ?? []
            
            // Remove existing summary for this date
            currentSummaries.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
            
            // Add new summary
            currentSummaries.append(summary)
            
            // Sort by date
            currentSummaries.sort { $0.date > $1.date }
            
            // Update in-memory cache
            self.dailySummariesCache[petId] = currentSummaries
            
            // Update persistent cache using UnifiedCacheCoordinator
            if self.currentUserId != nil {
                let cacheKey = CacheKey.dailySummaries.scoped(forPetId: petId)
                self.cacheCoordinator.set(currentSummaries, forKey: cacheKey)
            }
        }
        
        // Trigger SwiftUI update
        await MainActor.run {
            objectWillChange.send()
        }
    }
    
    // MARK: - Premium Features
    
    /**
     * Check if user can access multiple pet nutrition features
     * - Parameter user: The user account
     * - Returns: Whether premium features are available
     */
    func canAccessMultiplePetFeatures(user: User) -> Bool {
        return user.role == .premium
    }
    
    /**
     * Get nutrition insights for multiple pets
     * - Parameter pets: Array of pets to analyze
     * - Returns: Comparative nutrition insights
     */
    func getMultiPetInsights(for pets: [Pet]) async throws -> MultiPetNutritionInsights {
        guard !pets.isEmpty else {
            throw NutritionError.noPetsProvided
        }
        
        var insights = MultiPetNutritionInsights(pets: pets, generatedAt: Date())
        
        for pet in pets {
            if let requirements = nutritionalRequirementsCache[pet.id] {
                insights.requirements[pet.id] = requirements
            }
            
            if let summaries = dailySummariesCache[pet.id] {
                insights.recentSummaries[pet.id] = Array(summaries.prefix(7)) // Last 7 days
            }
        }
        
        // Generate comparative insights
        insights.comparativeInsights = generateComparativeInsights(insights)
        
        return insights
    }
    
    /**
     * Generate comparative insights across multiple pets
     * - Parameter insights: The multi-pet insights object
     * - Returns: Array of comparative insights
     */
    private func generateComparativeInsights(_ insights: MultiPetNutritionInsights) -> [ComparativeInsight] {
        var comparativeInsights: [ComparativeInsight] = []
        
        // Compare calorie requirements
        let calorieRequirements = insights.requirements.values.map { $0.dailyCalories }
        if let maxCalories = calorieRequirements.max(),
           let minCalories = calorieRequirements.min(),
           maxCalories > minCalories * 1.5 {
            comparativeInsights.append(ComparativeInsight(
                type: .calorieRange,
                title: "Calorie Requirements Vary Significantly",
                description: "Your pets have very different calorie needs. Consider feeding schedules accordingly.",
                severity: .medium
            ))
        }
        
        // Compare recent nutrition trends
        let recentSummaries = insights.recentSummaries.values.flatMap { $0 }
        let averageCompatibility = recentSummaries.map { $0.averageCompatibility }.reduce(0, +) / Double(max(recentSummaries.count, 1))
        
        if averageCompatibility < 70 {
            comparativeInsights.append(ComparativeInsight(
                type: .nutritionQuality,
                title: "Nutrition Quality Could Improve",
                description: "Consider reviewing your pets' current food choices for better nutritional balance.",
                severity: .high
            ))
        }
        
        return comparativeInsights
    }
    
    // MARK: - Data Management
    
    /**
     * Clear all cached data
     */
    func clearCache() {
        nutritionalRequirementsCache.removeAll()
        dailySummariesCache.removeAll()
        foodAnalyses.removeAll()
        feedingRecords.removeAll()
    }
    
    /**
     * Refresh all data for a pet
     * - Parameter petId: The pet's ID
     */
    func refreshPetData(petId: String) async throws {
        // Invalidate caches first using UnifiedCacheCoordinator
        if currentUserId != nil {
            let cacheKeys = [
                CacheKey.nutritionRequirements.scoped(forPetId: petId),
                CacheKey.feedingRecords.scoped(forPetId: petId),
                CacheKey.dailySummaries.scoped(forPetId: petId)
            ]
            cacheKeys.forEach { cacheCoordinator.invalidate(forKey: $0) }
        }
        
        // Reload data
        _ = try await getNutritionalRequirements(for: petId)
        try await loadFoodAnalyses(for: petId)
        try await loadFeedingRecords(for: petId, forceRefresh: true)
        try await loadDailySummaries(for: petId, forceRefresh: true)
    }
    
    /**
     * Check if we have cached nutrition data for a pet
     * - Parameter petId: The pet's ID
     * - Returns: True if we have any cached nutrition data
     */
    func hasCachedNutritionData(for petId: String) -> Bool {
        // Check in-memory cache first
        let hasRequirements = nutritionalRequirementsCache[petId] != nil
        let hasFeedingRecords = !feedingRecords.filter { $0.petId == petId }.isEmpty
        let hasDailySummaries = !(dailySummariesCache[petId] ?? []).isEmpty
        let hasFoodAnalyses = !foodAnalyses.isEmpty
        
        // Also check UnifiedCacheCoordinator
        if currentUserId != nil {
            let requirementsKey = CacheKey.nutritionRequirements.scoped(forPetId: petId)
            let summariesKey = CacheKey.dailySummaries.scoped(forPetId: petId)
            let recordsKey = CacheKey.feedingRecords.scoped(forPetId: petId)
            
            let hasCachedRequirements = cacheCoordinator.exists(forKey: requirementsKey)
            let hasCachedSummaries = cacheCoordinator.exists(forKey: summariesKey)
            let hasCachedRecords = cacheCoordinator.exists(forKey: recordsKey)
            
            return hasRequirements || hasCachedRequirements ||
                   hasFeedingRecords || hasCachedRecords ||
                   hasDailySummaries || hasCachedSummaries ||
                   hasFoodAnalyses
        }
        
        return hasRequirements || hasFeedingRecords || hasDailySummaries || hasFoodAnalyses
    }
}
