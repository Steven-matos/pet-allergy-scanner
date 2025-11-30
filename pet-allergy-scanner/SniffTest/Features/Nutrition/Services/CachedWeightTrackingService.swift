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
    
    /// Track active loading tasks to prevent duplicate concurrent requests
    private var activeLoadTasks: [String: Task<Void, Error>] = [:]
    
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
     * - Returns: The ID of the newly created weight record
     */
    func recordWeight(petId: String, weight: Double, notes: String? = nil) async throws -> String {
        print("📝 [recordWeight] Starting - petId: \(petId), weight: \(weight)")
        
        // Convert weight to kg for storage (backend expects kg)
        let weightInKg = unitService.convertToKg(weight)
        print("📝 [recordWeight] Converted to kg: \(weightInKg)")
        
        let weightRecord = WeightRecord(
            id: UUID().uuidString,
            petId: petId,
            weightKg: weightInKg,
            recordedAt: Date(),
            notes: notes,
            recordedByUserId: nil
        )
        
        // Add to local storage FIRST (optimistic UI update)
        if weightHistory[petId] == nil {
            weightHistory[petId] = []
        }
        weightHistory[petId]?.insert(weightRecord, at: 0)
        currentWeights[petId] = weightInKg
        
        // Force SwiftUI to detect the change
        objectWillChange.send()
        
        print("✅ [recordWeight] Added to local storage - now have \(weightHistory[petId]?.count ?? 0) records")
        print("✅ [recordWeight] Updated currentWeights[\(petId)] = \(weightInKg) kg")
        print("🔔 [recordWeight] Sent objectWillChange notification")
        
        // Send to backend
        do {
            try await apiService.recordWeight(weightRecord)
            print("✅ [recordWeight] Sent to backend successfully")
        } catch {
            print("❌ [recordWeight] Failed to send to backend: \(error)")
            throw error
        }
        
        // Invalidate weight history cache to force fresh fetch next time
        if currentUserId != nil {
            let cacheKey = CacheKey.weightRecords.scoped(forPetId: petId)
            cacheService.invalidate(forKey: cacheKey)
            print("💾 [recordWeight] Invalidated cache")
        }
        
        // Update pet's current weight in PetService
        print("🐾 [recordWeight] Updating pet's current weight...")
        await updatePetWeight(petId: petId, weightKg: weightInKg)
        
        // Generate recommendations
        print("💡 [recordWeight] Generating recommendations...")
        await generateRecommendations(for: petId)
        
        print("✅ [recordWeight] Complete!")
        
        // Return the weight record ID for undo functionality
        return weightRecord.id
    }
    
    /**
     * Delete a weight record (for undo functionality)
     * - Parameter recordId: The weight record ID to delete
     */
    func deleteWeightRecord(recordId: String) async throws {
        print("🗑️ [deleteWeightRecord] Deleting record: \(recordId)")
        
        try await apiService.deleteWeightRecord(recordId: recordId)
        
        print("✅ [deleteWeightRecord] Record deleted successfully")
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
            // Get the response from backend to ensure we have the correct ID and data
            let response = try await apiService.createWeightGoal(weightGoal) // Backend now handles upsert
            
            // Update local goal with backend response to ensure consistency
            let backendGoal = WeightGoal(
                id: response.id,
                petId: response.pet_id,
                goalType: WeightGoalType(rawValue: response.goal_type) ?? goalType,
                targetWeightKg: response.targetWeightKg,
                currentWeightKg: response.currentWeightKg,
                targetDate: response.targetDate,
                isActive: response.isActive,
                notes: response.notes,
                createdAt: response.createdAt,
                updatedAt: response.updatedAt
            )
            
            // Update local storage with backend response
            weightGoals[petId] = backendGoal
            print("✅ Successfully saved weight goal to backend: \(backendGoal.id)")
            print("   Target weight: \(backendGoal.targetWeightKg ?? 0) kg, Active: \(backendGoal.isActive)")
            
            // Cache the weight goal with backend data
            if currentUserId != nil {
                let cacheKey = CacheKey.weightGoals.scoped(forPetId: petId)
                cacheService.store(backendGoal, forKey: cacheKey)
            }
        } catch {
            print("❌ Failed to save weight goal to backend: \(error.localizedDescription)")
            // Don't throw error - keep the goal locally even if backend fails
            print("⚠️ Keeping goal locally despite backend failure")
            
            // Still cache the local goal even if backend fails
            if currentUserId != nil {
                let cacheKey = CacheKey.weightGoals.scoped(forPetId: petId)
                cacheService.store(weightGoal, forKey: cacheKey)
            }
        }
    }
    
    /**
     * Load weight data for a pet with caching
     * - Parameter petId: The pet's ID
     * - Parameter forceRefresh: If true, bypass cache and fetch from server
     */
    func loadWeightData(for petId: String, forceRefresh: Bool = false) async throws {
        print("🔄 [loadWeightData] Starting for petId: \(petId), forceRefresh: \(forceRefresh)")
        
        // Check if there's already an active load task for this pet
        if let existingTask = activeLoadTasks[petId] {
            print("⏳ [loadWeightData] Waiting for existing load task to complete for pet: \(petId)")
            do {
                try await existingTask.value
                print("✅ [loadWeightData] Existing task completed, returning")
                return
            } catch {
                print("⚠️ [loadWeightData] Existing task failed: \(error.localizedDescription), starting new load")
                // Continue with new load if previous one failed
            }
        }
        
        // CRITICAL: If forceRefresh is true, always fetch from server
        // This ensures we get the latest data including goals from database
        if !forceRefresh {
            // Only check in-memory data if NOT forcing refresh
            let hasInMemoryHistory = !(weightHistory[petId]?.isEmpty ?? true)
            let hasInMemoryGoal = weightGoals[petId] != nil
            let hasInMemoryData = hasInMemoryHistory || hasInMemoryGoal
            
            print("📊 [loadWeightData] In-memory data check:")
            print("   - History count: \(weightHistory[petId]?.count ?? 0)")
            print("   - Has goal: \(hasInMemoryGoal)")
            print("   - Has in-memory data: \(hasInMemoryData)")
            
            // If we already have data in memory and not forcing refresh, use it
            if hasInMemoryData {
                print("✅ [loadWeightData] Already have data in memory, skipping load")
                return
            }
        } else {
            print("🔄 [loadWeightData] Force refresh requested - fetching from server regardless of cached data")
        }
        
        // Create and track the load task
        let loadTask = Task {
            defer {
                // Remove task from tracking when done
                activeLoadTasks.removeValue(forKey: petId)
            }
            try await performLoadWeightData(for: petId, forceRefresh: forceRefresh)
        }
        
        activeLoadTasks[petId] = loadTask
        
        // Wait for the task to complete
        try await loadTask.value
    }
    
    /// Internal method to perform the actual weight data loading
    private func performLoadWeightData(for petId: String, forceRefresh: Bool) async throws {
        // Try cache first (only if not forcing refresh)
        var hasCachedData = false
        
        if currentUserId != nil && !forceRefresh {
            print("👤 [loadWeightData] Current user ID exists, checking cache...")
            
            // Try weight history cache
            let historyCacheKey = CacheKey.weightRecords.scoped(forPetId: petId)
            if let cachedHistory = cacheService.retrieve([WeightRecord].self, forKey: historyCacheKey) {
                print("💾 [loadWeightData] Found cached history: \(cachedHistory.count) records")
                if !cachedHistory.isEmpty {
                    await MainActor.run {
                        weightHistory[petId] = cachedHistory
                    }
                    hasCachedData = true
                    print("✅ [loadWeightData] Loaded from cache (non-empty)")
                } else {
                    print("⚠️ [loadWeightData] Cached data is empty, will fetch from server")
                }
            } else {
                print("❌ [loadWeightData] No cached history found")
            }
            
            // Try weight goal cache
            let goalCacheKey = CacheKey.weightGoals.scoped(forPetId: petId)
            if let cachedGoal = cacheService.retrieve(WeightGoal.self, forKey: goalCacheKey) {
                print("💾 [loadWeightData] Found cached goal")
                await MainActor.run {
                    weightGoals[petId] = cachedGoal
                }
                hasCachedData = true
            } else {
                print("❌ [loadWeightData] No cached goal found")
            }
            
            // If we have meaningful cached data, use it
            if hasCachedData {
                print("✅ [loadWeightData] Using cached data")
                
                // Update current weight from cached history
                if let latestRecord = weightHistory[petId]?.first {
                    await MainActor.run {
                        currentWeights[petId] = latestRecord.weightKg
                    }
                    print("📊 [loadWeightData] Updated current weight: \(latestRecord.weightKg)kg")
                }
                
                // Generate recommendations
                await generateRecommendations(for: petId)
                
                // Background refresh to ensure data is fresh
                Task {
                    await refreshWeightDataInBackground(for: petId)
                }
                
                return
            }
        } else if forceRefresh {
            print("🔄 [loadWeightData] Force refresh requested, skipping cache")
        } else {
            print("⚠️ [loadWeightData] No current user ID, skipping cache")
        }
        
        // Fallback to server
        isLoading = true
        error = nil
        
        // Load weight history and goals in parallel to avoid cancellation issues
        // Use async let to run both requests concurrently
        print("📡 [CachedWeightTrackingService] Fetching weight data from server for pet: \(petId)")
        
        async let historyTask: [WeightRecord] = {
            do {
                let history = try await apiService.getWeightHistory(petId: petId)
                print("✅ [CachedWeightTrackingService] Received \(history.count) weight records from server")
                return history
            } catch {
                // Check if it's a cancellation error
                if error is CancellationError {
                    print("⚠️ [CachedWeightTrackingService] Weight history request was cancelled")
                    throw error
                }
                // If weight history endpoint doesn't exist (404), initialize with empty array
                print("❌ [CachedWeightTrackingService] Failed to fetch weight history: \(error)")
                print("   Error type: \(type(of: error))")
                print("   Error description: \(error.localizedDescription)")
                return []
            }
        }()
        
        async let goalTask: WeightGoal? = {
            do {
                let goal = try await apiService.getActiveWeightGoal(petId: petId)
                if let goal = goal {
                    print("✅ [loadWeightData] Loaded weight goal from backend: \(goal.id)")
                    print("   Target weight: \(goal.targetWeightKg ?? 0) kg, Active: \(goal.isActive)")
                } else {
                    print("⚠️ [loadWeightData] No weight goal found in backend for pet: \(petId)")
                }
                return goal
            } catch {
                // Check if it's a cancellation error
                if error is CancellationError {
                    print("⚠️ [loadWeightData] Weight goal request was cancelled")
                    throw error
                }
                // If goal loading fails, log the error but don't fail the entire load
                print("❌ [loadWeightData] Failed to load weight goal from backend: \(error.localizedDescription)")
                print("   Error type: \(type(of: error))")
                return nil
            }
        }()
        
        // Wait for both tasks to complete
        do {
            let history = try await historyTask
            
            // IMPORTANT: Store in @Published property so UI updates
            await MainActor.run {
                self.weightHistory[petId] = history
                print("✅ [CachedWeightTrackingService] Stored \(history.count) records in weightHistory dict")
                print("   Dictionary now has keys: \(self.weightHistory.keys)")
            }
            
            // Log each record for debugging
            for (index, record) in history.enumerated() {
                print("   Record \(index + 1): \(record.weightKg)kg at \(record.recordedAt)")
            }
            
            // Cache weight history
            if currentUserId != nil {
                let cacheKey = CacheKey.weightRecords.scoped(forPetId: petId)
                cacheService.store(history, forKey: cacheKey)
                print("💾 [CachedWeightTrackingService] Cached \(history.count) records")
            } else {
                print("⚠️ [CachedWeightTrackingService] No user ID, skipping cache")
            }
        } catch {
            // If history task was cancelled or failed, set empty array
            if error is CancellationError {
                print("⚠️ [CachedWeightTrackingService] Weight history task was cancelled")
            }
            await MainActor.run {
                self.weightHistory[petId] = []
            }
            
            // Cache empty history to prevent future API calls
            if currentUserId != nil {
                let cacheKey = CacheKey.weightRecords.scoped(forPetId: petId)
                let emptyHistory: [WeightRecord] = []
                cacheService.store(emptyHistory, forKey: cacheKey)
                print("💾 [CachedWeightTrackingService] Cached empty array to prevent retries")
            }
        }
        
        // Handle goal task result
        do {
            let goal = try await goalTask
            
            // CRITICAL: Always update the goal from backend response
            // This ensures existing goals in database are loaded
            await MainActor.run {
                weightGoals[petId] = goal  // Set to backend response (can be nil)
                
                if let goal = goal {
                    print("✅ [loadWeightData] Updated goal from backend: \(goal.id)")
                    print("   Target weight: \(goal.targetWeightKg ?? 0) kg, Active: \(goal.isActive)")
                } else {
                    print("⚠️ [loadWeightData] Backend returned nil goal - no goal set for pet")
                }
            }
            
            if let goal = goal {
                // Cache weight goal
                if currentUserId != nil {
                    let cacheKey = CacheKey.weightGoals.scoped(forPetId: petId)
                    cacheService.store(goal, forKey: cacheKey)
                    print("💾 [loadWeightData] Cached weight goal")
                }
            } else {
                // Clear goal cache if backend has no goal
                if currentUserId != nil {
                    let cacheKey = CacheKey.weightGoals.scoped(forPetId: petId)
                    cacheService.invalidate(forKey: cacheKey)
                    print("💾 [loadWeightData] Cleared goal cache")
                }
            }
        } catch {
            // If goal task was cancelled or failed, log but continue
            if error is CancellationError {
                print("⚠️ [loadWeightData] Weight goal task was cancelled")
            } else {
                print("❌ [loadWeightData] Goal fetch failed: \(error.localizedDescription)")
            }
            // Don't clear existing goal if request failed - might be temporary network issue
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
        let records = weightHistory[petId] ?? []
        print("🔍 [weightHistory] Returning \(records.count) records for pet: \(petId)")
        print("   Current weightHistory dict keys: \(weightHistory.keys)")
        return records
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
        print("🐾 [updatePetWeight] Starting - petId: \(petId), weightKg: \(weightKg)")
        
        // CRITICAL FIX: The backend has already updated the pet's weight in the database.
        // We need to:
        // 1. Update our local currentWeights dictionary IMMEDIATELY for instant UI update
        // 2. Refresh the pet object from server for consistency
        
        // STEP 1: Update local currentWeights for instant UI feedback
        await MainActor.run {
            currentWeights[petId] = weightKg
            print("✅ [updatePetWeight] Updated local currentWeights to \(weightKg) kg")
            
            // CRITICAL: Force SwiftUI to detect the change by sending objectWillChange
            // Dictionary mutations don't always trigger @Published updates
            objectWillChange.send()
            print("🔔 [updatePetWeight] Sent objectWillChange notification")
        }
        
        // STEP 2: Force refresh pets from server to get the updated weight
        await MainActor.run {
            print("🔄 [updatePetWeight] Forcing pet data refresh from server...")
            petService.loadPets(forceRefresh: true)
        }
        
        // Wait for pets to reload (with timeout)
        var waitCount = 0
        let maxWait = 50 // Max 5 seconds
        while petService.isLoading && waitCount < maxWait {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            waitCount += 1
        }
        
        if waitCount >= maxWait {
            print("⚠️ [updatePetWeight] Timeout waiting for pets to load after \(Double(maxWait) * 0.1)s")
        }
        
        // Verify the pet was updated and refresh the selected pet if needed
        if let updatedPet = petService.pets.first(where: { $0.id == petId }) {
            print("✅ [updatePetWeight] Pet refreshed from server")
            print("   Pet name: \(updatedPet.name)")
            print("   Pet weight from server: \(updatedPet.weightKg ?? 0) kg")
            print("   Expected weight: \(weightKg) kg")
            
            if let serverWeight = updatedPet.weightKg {
                // Verify the server weight matches (within rounding tolerance)
                let weightDifference = abs(serverWeight - weightKg)
                if weightDifference > 0.1 {
                    print("⚠️ [updatePetWeight] WARNING: Server weight (\(serverWeight) kg) differs from expected (\(weightKg) kg)")
                }
            }
            
            // Update the selected pet in PetSelectionService to trigger UI refresh
            await MainActor.run {
                NutritionPetSelectionService.shared.selectPet(updatedPet)
                print("🔄 [updatePetWeight] Updated selected pet to trigger UI refresh")
            }
        } else {
            print("⚠️ [updatePetWeight] Pet not found after refresh - ID: \(petId)")
            print("   Available pets: \(petService.pets.map { $0.name })")
        }
        
        print("🐾 [updatePetWeight] Complete")
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
    /**
     * Refresh weight data from server (bypassing cache)
     * - Parameter petId: The pet's ID
     */
    func refreshWeightData(petId: String) async throws {
        print("🔄 [refreshWeightData] Force refreshing data for petId: \(petId)")
        
        // Invalidate caches first
        if currentUserId != nil {
            let cacheKeys = [
                CacheKey.weightRecords.scoped(forPetId: petId),
                CacheKey.weightGoals.scoped(forPetId: petId)
            ]
            cacheKeys.forEach { cacheService.invalidate(forKey: $0) }
            print("💾 [refreshWeightData] Invalidated caches")
        }
        
        // Clear in-memory data to force fresh fetch
        await MainActor.run {
            weightHistory[petId] = []
            weightGoals[petId] = nil
            currentWeights[petId] = nil
            print("🗑️ [refreshWeightData] Cleared in-memory data")
        }
        
        // Reload data with force refresh
        try await loadWeightData(for: petId, forceRefresh: true)
        print("✅ [refreshWeightData] Complete")
    }
}
