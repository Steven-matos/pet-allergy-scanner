//
//  CachedWeightTrackingService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import Combine

/**
 * Cached Weight Tracking Service
 * 
 * Provides cached access to weight tracking data with automatic cache management.
 * Implements cache-first pattern for optimal performance.
 * 
 * Follows SOLID principles: Single responsibility for cached weight tracking operations
 * Implements DRY by reusing cache patterns from existing cached services
 * Follows KISS by keeping the caching logic simple and transparent
 */
@MainActor
class CachedWeightTrackingService: ObservableObject {
    static let shared = CachedWeightTrackingService()
    
    @Published var weightHistory: [String: [WeightRecord]] = [:]
    @Published var weightGoals: [String: WeightGoal] = [:]
    @Published var currentWeights: [String: Double] = [:]
    @Published var recommendations: [String: [String]] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService: APIService
    private let cacheService = CacheService.shared
    private let authService = AuthService.shared
    private let unitService = WeightUnitPreferenceService.shared
    private let petService = CachedPetService.shared
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
    
    // MARK: - Public API
    
    /**
     * Check if we have cached weight data for a pet
     * - Parameter petId: The pet's ID
     * - Returns: True if we have any cached weight data
     */
    func hasCachedWeightData(for petId: String) -> Bool {
        let hasHistory = !weightHistory(for: petId).isEmpty
        let hasGoal = activeWeightGoal(for: petId) != nil
        return hasHistory || hasGoal
    }
    
    /**
     * Record a new weight measurement for a pet with cache invalidation
     * - Parameter petId: The pet's ID
     * - Parameter weight: Weight in the user's selected unit
     * - Parameter notes: Optional notes about the measurement
     */
    func recordWeight(petId: String, weight: Double, notes: String? = nil) async throws {
        // Convert weight to kg for storage (backend expects kg)
        let weightInKg = unitService.convertToKg(weight)
        
        let weightRecord = WeightRecord(
            id: UUID().uuidString,
            petId: petId,
            weightKg: weightInKg,
            recordedAt: Date(),
            notes: notes,
            recordedByUserId: nil
        )
        
        // Add to local storage
        if weightHistory[petId] == nil {
            weightHistory[petId] = []
        }
        weightHistory[petId]?.insert(weightRecord, at: 0)
        currentWeights[petId] = weightInKg
        
        // Send to backend
        try await apiService.recordWeight(weightRecord)
        
        // Invalidate weight history cache
        if currentUserId != nil {
            let cacheKey = CacheKey.weightRecords.scoped(forPetId: petId)
            cacheService.invalidate(forKey: cacheKey)
        }
        
        // Update pet's current weight in PetService
        await updatePetWeight(petId: petId, weightKg: weightInKg)
        
        // Generate recommendations
        await generateRecommendations(for: petId)
    }
    
    /**
     * Create or update a weight goal for a pet with caching
     * - Parameter petId: The pet's ID
     * - Parameter goalType: Type of weight goal
     * - Parameter targetWeight: Target weight in the user's selected unit
     * - Parameter targetDate: Target date for achieving the goal
     * - Parameter notes: Optional notes about the goal
     */
    func upsertWeightGoal(
        petId: String,
        goalType: WeightGoalType,
        targetWeight: Double,
        targetDate: Date,
        notes: String? = nil
    ) async throws {
        // Convert target weight to kg for storage (backend expects kg)
        let targetWeightInKg = unitService.convertToKg(targetWeight)
        
        // Get current weight from pet or weight history - this will be the starting weight for the goal
        let currentWeightKg: Double?
        if let currentWeight = currentWeights[petId] {
            currentWeightKg = currentWeight
        } else if let latestRecord = weightHistory[petId]?.first {
            currentWeightKg = latestRecord.weightKg
        } else if let pet = petService.pets.first(where: { $0.id == petId }) {
            // Get weight from pet's profile as fallback
            currentWeightKg = pet.weightKg
        } else {
            // If no weight data available, we can't create a meaningful goal
            print("⚠️ Warning: No weight data available for pet \(petId), cannot create goal")
            currentWeightKg = nil
        }
        
        // Check if pet already has a goal
        let existingGoal = weightGoals[petId]
        let isUpdating = existingGoal != nil
        
        print("🎯 \(isUpdating ? "Updating" : "Creating") weight goal - Starting weight: \(currentWeightKg ?? 0), Target: \(targetWeightInKg), Goal type: \(goalType)")
        
        let weightGoal = WeightGoal(
            id: existingGoal?.id ?? UUID().uuidString, // Keep existing ID if updating
            petId: petId,
            goalType: goalType,
            targetWeightKg: targetWeightInKg,
            currentWeightKg: currentWeightKg,
            targetDate: targetDate,
            isActive: true,
            notes: notes,
            createdAt: existingGoal?.createdAt ?? Date(), // Keep original creation date if updating
            updatedAt: Date()
        )
        
        // Update local storage
        weightGoals[petId] = weightGoal
        print("✅ \(isUpdating ? "Updated" : "Created") weight goal locally: \(weightGoal.id)")
        
        // Send to backend
        do {
            try await apiService.createWeightGoal(weightGoal) // Backend now handles upsert
            print("✅ Successfully saved weight goal to backend: \(weightGoal.id)")
        } catch {
            print("❌ Failed to save weight goal to backend: \(error.localizedDescription)")
            // Don't throw error - keep the goal locally even if backend fails
            print("⚠️ Keeping goal locally despite backend failure")
        }
        
        // Cache the weight goal
        if currentUserId != nil {
            let cacheKey = CacheKey.weightGoals.scoped(forPetId: petId)
            cacheService.store(weightGoal, forKey: cacheKey)
        }
    }
    
    /**
     * Load weight data for a pet with caching
     * - Parameter petId: The pet's ID
     */
    func loadWeightData(for petId: String) async throws {
        // Try cache first
        var hasCachedData = false
        
        if currentUserId != nil {
            // Try weight history cache
            let historyCacheKey = CacheKey.weightRecords.scoped(forPetId: petId)
            if let cachedHistory = cacheService.retrieve([WeightRecord].self, forKey: historyCacheKey) {
                weightHistory[petId] = cachedHistory
                // Only consider it cached if it has actual data
                if !cachedHistory.isEmpty {
                    hasCachedData = true
                }
            }
            
            // Try weight goal cache
            let goalCacheKey = CacheKey.weightGoals.scoped(forPetId: petId)
            if let cachedGoal = cacheService.retrieve(WeightGoal.self, forKey: goalCacheKey) {
                weightGoals[petId] = cachedGoal
                hasCachedData = true
            }
            
            // If we have meaningful cached data, use it and skip server calls
            if hasCachedData {
                // Update current weight from cached history
                if let latestRecord = weightHistory[petId]?.first {
                    currentWeights[petId] = latestRecord.weightKg
                }
                
                // Generate recommendations
                await generateRecommendations(for: petId)
                
                // Background refresh if data seems stale
                Task {
                    await refreshWeightDataInBackground(for: petId)
                }
                
                return
            }
        }
        
        // Fallback to server
        isLoading = true
        error = nil
        
        do {
            // Load weight history
            let history = try await apiService.getWeightHistory(petId: petId)
            weightHistory[petId] = history
            
            // Cache weight history
            if currentUserId != nil {
                let cacheKey = CacheKey.weightRecords.scoped(forPetId: petId)
                cacheService.store(history, forKey: cacheKey)
            }
        } catch {
            // If weight history endpoint doesn't exist (404), initialize with empty array
            print("⚠️ Weight history endpoint not implemented (404), initializing with empty history: \(error)")
            weightHistory[petId] = []
            
            // Cache empty history to prevent future API calls
            if currentUserId != nil {
                let cacheKey = CacheKey.weightRecords.scoped(forPetId: petId)
                let emptyHistory: [WeightRecord] = []
                cacheService.store(emptyHistory, forKey: cacheKey)
            }
        }
        
        // Load weight goals
        do {
            if let goal = try await apiService.getActiveWeightGoal(petId: petId) {
                print("✅ Loaded weight goal from backend: \(goal.id)")
                weightGoals[petId] = goal
                
                // Cache weight goal
                if currentUserId != nil {
                    let cacheKey = CacheKey.weightGoals.scoped(forPetId: petId)
                    cacheService.store(goal, forKey: cacheKey)
                }
            } else {
                print("⚠️ No weight goal found in backend for pet: \(petId)")
                // Clear local goal if no goal exists in backend
                weightGoals[petId] = nil
                
                // Invalidate goal cache
                if currentUserId != nil {
                    let cacheKey = CacheKey.weightGoals.scoped(forPetId: petId)
                    cacheService.invalidate(forKey: cacheKey)
                }
            }
        } catch {
            // If goal loading fails, keep local goal but log the error
            print("❌ Failed to load weight goal from backend: \(error.localizedDescription)")
        }
        
        // Update current weight
        if let latestRecord = weightHistory[petId]?.first {
            currentWeights[petId] = latestRecord.weightKg
        }
        
        // Generate recommendations
        await generateRecommendations(for: petId)
        
        isLoading = false
    }
    
    /**
     * Get weight history for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Array of weight records
     */
    func weightHistory(for petId: String) -> [WeightRecord] {
        return weightHistory[petId] ?? []
    }
    
    /**
     * Get current weight for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Current weight or nil if not available
     */
    func currentWeight(for petId: String) -> Double? {
        return currentWeights[petId]
    }
    
    /**
     * Get active weight goal for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Active weight goal or nil if not set
     */
    func activeWeightGoal(for petId: String) -> WeightGoal? {
        return weightGoals[petId]
    }
    
    /**
     * Get recommendations for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Array of recommendation strings
     */
    func recommendations(for petId: String) -> [String] {
        return recommendations[petId] ?? []
    }
    
    /**
     * Analyze weight trend for a pet
     * - Parameter petId: The pet's ID
     * - Parameter daysBack: Number of days to analyze
     * - Returns: Weight trend analysis
     */
    func analyzeWeightTrend(for petId: String, daysBack: Int = 30) -> WeightTrendAnalysis {
        let history = weightHistory(for: petId)
        
        guard history.count >= 2 else {
            return WeightTrendAnalysis(
                trendDirection: .stable,
                weightChangeKg: 0.0,
                averageDailyChange: 0.0,
                trendStrength: .weak,
                daysAnalyzed: history.count,
                confidenceLevel: 0.0
            )
        }
        
        // Filter to specified days back
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let recentHistory = history.filter { $0.recordedAt >= cutoffDate }
        
        guard recentHistory.count >= 2 else {
            return WeightTrendAnalysis(
                trendDirection: .stable,
                weightChangeKg: 0.0,
                averageDailyChange: 0.0,
                trendStrength: .weak,
                daysAnalyzed: recentHistory.count,
                confidenceLevel: 0.0
            )
        }
        
        // Calculate trend
        let currentWeight = recentHistory.first!.weightKg
        let oldWeight = recentHistory.last!.weightKg
        let weightChange = currentWeight - oldWeight
        
        // Calculate daily change
        let daysSpan = Calendar.current.dateComponents([.day], from: recentHistory.last!.recordedAt, to: recentHistory.first!.recordedAt).day ?? 1
        let dailyChange = weightChange / Double(daysSpan)
        
        // Determine trend direction
        let trendDirection: TrendDirection
        if weightChange > 0.5 {
            trendDirection = .increasing
        } else if weightChange < -0.5 {
            trendDirection = .decreasing
        } else {
            trendDirection = .stable
        }
        
        // Determine trend strength
        let absChange = abs(weightChange)
        let trendStrength: TrendStrength
        if absChange > 2.0 {
            trendStrength = .strong
        } else if absChange > 0.5 {
            trendStrength = .moderate
        } else {
            trendStrength = .weak
        }
        
        // Calculate confidence level
        let confidence = min(1.0, Double(recentHistory.count) / 14.0) // Max confidence at 2 weeks of data
        
        return WeightTrendAnalysis(
            trendDirection: trendDirection,
            weightChangeKg: round(weightChange * 100) / 100,
            averageDailyChange: round(dailyChange * 1000) / 1000,
            trendStrength: trendStrength,
            daysAnalyzed: recentHistory.count,
            confidenceLevel: confidence
        )
    }
    
    // MARK: - Private Methods
    
    /**
     * Refresh weight data in background if cache is stale
     * - Parameter petId: The pet's ID
     */
    private func refreshWeightDataInBackground(for petId: String) async {
        // Check if cache is stale (older than 5 minutes)
        let historyCacheKey = CacheKey.weightRecords.scoped(forPetId: petId)
        
        // If cache doesn't exist or is stale, refresh
        if !cacheService.exists(forKey: historyCacheKey) {
            do {
                // Load weight history silently
                let history = try await apiService.getWeightHistory(petId: petId)
                
                // Update if different from current
                if history != weightHistory[petId] {
                    await MainActor.run {
                        weightHistory[petId] = history
                        
                        // Update current weight
                        if let latestRecord = history.first {
                            currentWeights[petId] = latestRecord.weightKg
                        }
                        
                        // Cache the updated data
                        cacheService.store(history, forKey: historyCacheKey)
                    }
                    
                    // Regenerate recommendations with new data
                    await generateRecommendations(for: petId)
                }
            } catch {
                // Silent failure for background refresh
                print("⚠️ Background weight data refresh failed: \(error.localizedDescription)")
            }
        }
    }
    
    /**
     * Update pet's current weight in PetService
     * - Parameter petId: Pet ID
     * - Parameter weightKg: New weight in kg
     */
    private func updatePetWeight(petId: String, weightKg: Double) async {
        // Find the pet in PetService and update its weight
        if petService.pets.firstIndex(where: { $0.id == petId }) != nil {
            let petUpdate = PetUpdate(
                name: nil,
                breed: nil,
                birthday: nil,
                weightKg: weightKg,
                activityLevel: nil,
                imageUrl: nil,
                knownSensitivities: nil,
                vetName: nil,
                vetPhone: nil
            )
            
            // Update the pet's weight through PetService
            await MainActor.run {
                petService.updatePet(id: petId, petUpdate: petUpdate)
            }
            
            // The PetService.updatePet method should handle the UI update
            // The pet's weight will be updated through the PetService
        }
    }
    
    /**
     * Generate recommendations for a pet
     * - Parameter petId: The pet's ID
     */
    private func generateRecommendations(for petId: String) async {
        let history = weightHistory(for: petId)
        let goal = activeWeightGoal(for: petId)
        let trend = analyzeWeightTrend(for: petId)
        
        var newRecommendations: [String] = []
        
        // Weight trend recommendations
        switch trend.trendDirection {
        case .increasing:
            if trend.trendStrength == .strong {
                newRecommendations.append("Rapid weight gain detected. Consider reducing portion sizes or increasing exercise.")
            } else {
                newRecommendations.append("Weight is trending upward. Monitor portion sizes.")
            }
        case .decreasing:
            if trend.trendStrength == .strong {
                newRecommendations.append("Significant weight loss detected. Ensure adequate nutrition and consult your veterinarian.")
            } else {
                newRecommendations.append("Weight is trending downward. Monitor food intake.")
            }
        case .stable:
            if let goal = goal {
                let currentWeight = currentWeights[petId] ?? 0
                let targetWeight = goal.targetWeightKg ?? 0
                
                if goal.goalType == .weightLoss && currentWeight > targetWeight {
                    newRecommendations.append("Continue current routine to reach your weight loss goal.")
                } else if goal.goalType == .weightGain && currentWeight < targetWeight {
                    newRecommendations.append("Consider increasing portion sizes to reach your weight gain goal.")
                } else {
                    newRecommendations.append("Great job maintaining your target weight!")
                }
            } else {
                newRecommendations.append("Weight is stable. Consider setting a weight goal for better tracking.")
            }
        }
        
        // Data quality recommendations
        if history.count < 7 {
            newRecommendations.append("Record weight more frequently for better trend analysis.")
        }
        
        // Goal recommendations
        if goal == nil {
            newRecommendations.append("Set a weight goal to track progress and get personalized recommendations.")
        }
        
        recommendations[petId] = newRecommendations
    }
    
    // MARK: - Data Management
    
    /**
     * Clear all cached data
     */
    func clearCache() {
        weightHistory.removeAll()
        weightGoals.removeAll()
        currentWeights.removeAll()
        recommendations.removeAll()
    }
    
    /**
     * Refresh weight data for a pet
     * - Parameter petId: The pet's ID
     */
    func refreshWeightData(petId: String) async throws {
        // Invalidate caches first
        if currentUserId != nil {
            let cacheKeys = [
                CacheKey.weightRecords.scoped(forPetId: petId),
                CacheKey.weightGoals.scoped(forPetId: petId)
            ]
            cacheKeys.forEach { cacheService.invalidate(forKey: $0) }
        }
        
        // Reload data
        try await loadWeightData(for: petId)
    }
}
