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
    
    @Published var nutritionalRequirements: [String: PetNutritionalRequirements] = [:]
    @Published var foodAnalyses: [FoodNutritionalAnalysis] = []
    @Published var feedingRecords: [FeedingRecord] = []
    @Published var dailySummaries: [String: [DailyNutritionSummary]] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService: APIService
    private let cacheService = CacheService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Current user ID for cache scoping
    private var currentUserId: String? {
        authService.currentUser?.id
    }
    
    private init() {
        self.apiService = APIService.shared
        observeAuthChanges()
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
     * - Parameter petId: The pet's ID
     * - Returns: Nutritional requirements from cache or server
     */
    func getNutritionalRequirements(for petId: String) async throws -> PetNutritionalRequirements {
        // Try cache first
        if currentUserId != nil {
            let cacheKey = CacheKey.nutritionRequirements.scoped(forPetId: petId)
            if let cached = cacheService.retrieve(PetNutritionalRequirements.self, forKey: cacheKey) {
                nutritionalRequirements[petId] = cached
                return cached
            }
        }
        
        // Try to get from server, but handle 404/500 errors gracefully
        do {
            let requirements = try await loadNutritionalRequirementsFromServer(for: petId)
            
            // Cache the result
            if currentUserId != nil {
                let cacheKey = CacheKey.nutritionRequirements.scoped(forPetId: petId)
                cacheService.store(requirements, forKey: cacheKey)
            }
            
            nutritionalRequirements[petId] = requirements
            return requirements
        } catch {
            // If server fails (404/500 error), try to calculate requirements locally
            print("⚠️ Server failed to load nutritional requirements for pet \(petId) (endpoint not implemented), calculating locally: \(error)")
            
            // Get the pet to calculate requirements
            guard let pet = CachedPetService.shared.pets.first(where: { $0.id == petId }) else {
                throw error // Re-throw if we can't find the pet
            }
            
            // Calculate requirements locally
            let requirements = PetNutritionalRequirements.calculate(for: pet)
            nutritionalRequirements[petId] = requirements
            
            // Cache the calculated requirements
            if currentUserId != nil {
                let cacheKey = CacheKey.nutritionRequirements.scoped(forPetId: petId)
                cacheService.store(requirements, forKey: cacheKey)
            }
            
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
        nutritionalRequirements[pet.id] = requirements
        
        // Cache the calculated requirements
        if currentUserId != nil {
            let cacheKey = CacheKey.nutritionRequirements.scoped(forPetId: pet.id)
            cacheService.store(requirements, forKey: cacheKey)
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
            if let requirements = nutritionalRequirements[request.petId] {
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
        // Try cache first
        if currentUserId != nil {
            let cacheKey = CacheKey.feedingRecords.scoped(forPetId: petId)
            if let cached = cacheService.retrieve([FoodNutritionalAnalysis].self, forKey: cacheKey) {
                // Update local cache
                for analysis in cached {
                    if !foodAnalyses.contains(where: { $0.id == analysis.id }) {
                        foodAnalyses.append(analysis)
                    }
                }
                return
            }
        }
        
        // Fallback to server
        let analyses: [FoodNutritionalAnalysis] = try await apiService.get(
            endpoint: "/nutrition/analyses/\(petId)",
            responseType: [FoodNutritionalAnalysis].self
        )
        
        // Update local cache
        for analysis in analyses {
            if !foodAnalyses.contains(where: { $0.id == analysis.id }) {
                foodAnalyses.append(analysis)
            }
        }
        
        // Cache the result
        if currentUserId != nil {
            let cacheKey = CacheKey.feedingRecords.scoped(forPetId: petId)
            cacheService.store(analyses, forKey: cacheKey)
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
        
        feedingRecords.append(record)
        
        // Invalidate related caches
        if currentUserId != nil {
            let cacheKey = CacheKey.feedingRecords.scoped(forPetId: request.petId)
            cacheService.invalidate(forKey: cacheKey)
        }
        
        // Update daily summary
        await updateDailySummary(for: request.petId, date: request.feedingTime)
        
        return record
    }
    
    /**
     * Load feeding records for a pet with caching
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to load (default: 30)
     */
    func loadFeedingRecords(for petId: String, days: Int = 30) async throws {
        // Try cache first
        if currentUserId != nil {
            let cacheKey = CacheKey.feedingRecords.scoped(forPetId: petId)
            if let cached = cacheService.retrieve([FeedingRecord].self, forKey: cacheKey) {
                // Update local cache
                for record in cached {
                    if !feedingRecords.contains(where: { $0.id == record.id }) {
                        feedingRecords.append(record)
                    }
                }
                return
            }
        }
        
        // Fallback to server
        let records: [FeedingRecord] = try await apiService.get(
            endpoint: "/nutrition/feeding/\(petId)?days=\(days)",
            responseType: [FeedingRecord].self
        )
        
        // Update local cache
        for record in records {
            if !feedingRecords.contains(where: { $0.id == record.id }) {
                feedingRecords.append(record)
            }
        }
        
        // Cache the result
        if currentUserId != nil {
            let cacheKey = CacheKey.feedingRecords.scoped(forPetId: petId)
            cacheService.store(records, forKey: cacheKey)
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
     */
    func loadDailySummaries(for petId: String, days: Int = 30) async throws {
        // Try cache first
        if currentUserId != nil {
            let cacheKey = CacheKey.dailySummaries.scoped(forPetId: petId)
            if let cached = cacheService.retrieve([DailyNutritionSummary].self, forKey: cacheKey) {
                dailySummaries[petId] = cached
                return
            }
        }
        
        // Fallback to server
        let summaries: [DailyNutritionSummary] = try await apiService.get(
            endpoint: "/nutrition/summaries/\(petId)?days=\(days)",
            responseType: [DailyNutritionSummary].self
        )
        
        dailySummaries[petId] = summaries
        
        // Cache the result
        if currentUserId != nil {
            let cacheKey = CacheKey.dailySummaries.scoped(forPetId: petId)
            cacheService.store(summaries, forKey: cacheKey)
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
        return dailySummaries[petId]?.first { calendar.isDate($0.date, inSameDayAs: date) }
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
                
                if let requirements = nutritionalRequirements[petId] {
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
        
        if dailySummaries[petId] == nil {
            dailySummaries[petId] = []
        }
        
        // Remove existing summary for this date
        dailySummaries[petId]?.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
        
        // Add new summary
        dailySummaries[petId]?.append(summary)
        
        // Sort by date
        dailySummaries[petId]?.sort { $0.date > $1.date }
        
        // Update cache
        if currentUserId != nil {
            let cacheKey = CacheKey.dailySummaries.scoped(forPetId: petId)
            cacheService.store(dailySummaries[petId] ?? [], forKey: cacheKey)
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
            if let requirements = nutritionalRequirements[pet.id] {
                insights.requirements[pet.id] = requirements
            }
            
            if let summaries = dailySummaries[pet.id] {
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
        nutritionalRequirements.removeAll()
        foodAnalyses.removeAll()
        feedingRecords.removeAll()
        dailySummaries.removeAll()
    }
    
    /**
     * Refresh all data for a pet
     * - Parameter petId: The pet's ID
     */
    func refreshPetData(petId: String) async throws {
        // Invalidate caches first
        if currentUserId != nil {
            let cacheKeys = [
                CacheKey.nutritionRequirements.scoped(forPetId: petId),
                CacheKey.feedingRecords.scoped(forPetId: petId),
                CacheKey.dailySummaries.scoped(forPetId: petId)
            ]
            cacheKeys.forEach { cacheService.invalidate(forKey: $0) }
        }
        
        // Reload data
        _ = try await getNutritionalRequirements(for: petId)
        try await loadFoodAnalyses(for: petId)
        try await loadFeedingRecords(for: petId)
        try await loadDailySummaries(for: petId)
    }
    
    /**
     * Check if we have cached nutrition data for a pet
     * - Parameter petId: The pet's ID
     * - Returns: True if we have any cached nutrition data
     */
    func hasCachedNutritionData(for petId: String) -> Bool {
        let hasRequirements = nutritionalRequirements[petId] != nil
        let hasFeedingRecords = !feedingRecords.isEmpty
        let hasDailySummaries = !(dailySummaries[petId] ?? []).isEmpty
        let hasFoodAnalyses = !foodAnalyses.isEmpty
        
        return hasRequirements || hasFeedingRecords || hasDailySummaries || hasFoodAnalyses
    }
}
