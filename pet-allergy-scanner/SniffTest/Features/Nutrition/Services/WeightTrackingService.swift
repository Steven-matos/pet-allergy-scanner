//
//  WeightTrackingService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/**
 * Weight Tracking Service
 * 
 * Handles all weight tracking operations including:
 * - Weight recording and history management
 * - Goal setting and progress tracking
 * - Trend analysis and recommendations
 * - Data synchronization with backend
 * 
 * Follows SOLID principles with single responsibility for weight tracking
 * Implements DRY by reusing common data processing methods
 * Follows KISS by keeping the API simple and intuitive
 */
@MainActor
class WeightTrackingService: ObservableObject {
    static let shared = WeightTrackingService()
    
    @Published var weightHistory: [String: [WeightRecord]] = [:]
    @Published var weightGoals: [String: WeightGoal] = [:]
    @Published var currentWeights: [String: Double] = [:]
    @Published var recommendations: [String: [String]] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService: APIService
    private let unitService = WeightUnitPreferenceService.shared
    private let petService = PetService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.apiService = APIService.shared
    }
    
    // MARK: - Public API
    
    /**
     * Record a new weight measurement for a pet
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
        
        // Update pet's current weight in PetService
        await updatePetWeight(petId: petId, weightKg: weightInKg)
        
        // Generate recommendations
        await generateRecommendations(for: petId)
    }
    
    /**
     * Create or update a weight goal for a pet (one goal per pet)
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
    }
    
    /**
     * Create a weight goal for a pet (deprecated - use upsertWeightGoal instead)
     * - Parameter petId: The pet's ID
     * - Parameter goalType: Type of weight goal
     * - Parameter targetWeight: Target weight in the user's selected unit
     * - Parameter targetDate: Target date for achieving the goal
     * - Parameter notes: Optional notes about the goal
     */
    func createWeightGoal(
        petId: String,
        goalType: WeightGoalType,
        targetWeight: Double,
        targetDate: Date,
        notes: String? = nil
    ) async throws {
        // Delegate to upsert method for consistency
        try await upsertWeightGoal(
            petId: petId,
            goalType: goalType,
            targetWeight: targetWeight,
            targetDate: targetDate,
            notes: notes
        )
    }
    
    /**
     * Update an existing weight goal for a pet (deprecated - use upsertWeightGoal instead)
     * - Parameter petId: The pet's ID
     * - Parameter goalType: Type of weight goal
     * - Parameter targetWeight: Target weight in the user's selected unit
     * - Parameter targetDate: Target date for achieving the goal
     * - Parameter notes: Optional notes about the goal
     */
    func updateWeightGoal(
        petId: String,
        goalType: WeightGoalType,
        targetWeight: Double,
        targetDate: Date,
        notes: String? = nil
    ) async throws {
        // Delegate to upsert method for consistency
        try await upsertWeightGoal(
            petId: petId,
            goalType: goalType,
            targetWeight: targetWeight,
            targetDate: targetDate,
            notes: notes
        )
    }
    
    /**
     * Load weight data for a pet
     * - Parameter petId: The pet's ID
     */
    func loadWeightData(for petId: String) async throws {
        isLoading = true
        error = nil
        
        do {
            // Load weight history
            let history = try await apiService.getWeightHistory(petId: petId)
            weightHistory[petId] = history
            
            // Load weight goals
            do {
                if let goal = try await apiService.getActiveWeightGoal(petId: petId) {
                    print("✅ Loaded weight goal from backend: \(goal.id)")
                    weightGoals[petId] = goal
                } else {
                    print("⚠️ No weight goal found in backend for pet: \(petId)")
                    // Clear local goal if no goal exists in backend
                    weightGoals[petId] = nil
                }
            } catch {
                // If goal loading fails, keep local goal but log the error
                print("❌ Failed to load weight goal from backend: \(error.localizedDescription)")
            }
            
            // Update current weight
            if let latestRecord = history.first {
                currentWeights[petId] = latestRecord.weightKg
            }
            
            // Generate recommendations
            await generateRecommendations(for: petId)
            
        } catch {
            self.error = error
            throw error
        }
        
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
}

// MARK: - Data Models

struct WeightRecord: Identifiable, Codable {
    let id: String
    let petId: String
    let weightKg: Double
    let recordedAt: Date
    let notes: String?
    let recordedByUserId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, petId, weightKg, recordedAt, notes, recordedByUserId
    }
}

struct WeightGoal: Identifiable, Codable {
    let id: String
    let petId: String
    let goalType: WeightGoalType
    let targetWeightKg: Double?
    let currentWeightKg: Double?
    let targetDate: Date?
    let isActive: Bool
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, petId, goalType, targetWeightKg, currentWeightKg, targetDate, isActive, notes, createdAt, updatedAt
    }
}

enum WeightGoalType: String, CaseIterable, Codable {
    case weightLoss = "weight_loss"
    case weightGain = "weight_gain"
    case maintenance = "maintenance"
    case healthImprovement = "health_improvement"
}

struct WeightTrendAnalysis {
    let trendDirection: TrendDirection
    let weightChangeKg: Double
    let averageDailyChange: Double
    let trendStrength: TrendStrength
    let daysAnalyzed: Int
    let confidenceLevel: Double
}


enum TrendStrength {
    case weak
    case moderate
    case strong
}

// MARK: - API Request/Response Models

struct WeightRecordCreate: Codable {
    let pet_id: String
    let weight_kg: Double
    let recorded_at: Date
    let notes: String?
    let recorded_by_user_id: String?
    
    enum CodingKeys: String, CodingKey {
        case pet_id
        case weight_kg
        case recorded_at
        case notes
        case recorded_by_user_id
    }
}

struct WeightRecordResponse: Codable {
    let id: String
    let pet_id: String
    let weight_kg: Double
    let recorded_at: Date
    let notes: String?
    let recorded_by_user_id: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case pet_id
        case weight_kg
        case recorded_at
        case notes
        case recorded_by_user_id
    }
}

struct WeightGoalCreate: Codable {
    let pet_id: String
    let goal_type: String
    let targetWeightKg: Double?
    let currentWeightKg: Double?
    let targetDate: Date?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case pet_id
        case goal_type
        case targetWeightKg
        case currentWeightKg
        case targetDate
        case notes
    }
}

struct WeightGoalUpdate: Codable {
    let goal_type: String
    let targetWeightKg: Double?
    let targetDate: Date?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case goal_type
        case targetWeightKg
        case targetDate
        case notes
    }
}

struct WeightGoalResponse: Codable {
    let id: String
    let pet_id: String
    let goal_type: String
    let targetWeightKg: Double?
    let currentWeightKg: Double?
    let targetDate: Date?
    let isActive: Bool
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case pet_id
        case goal_type
        case targetWeightKg
        case currentWeightKg
        case targetDate
        case isActive
        case notes
        case createdAt
        case updatedAt
    }
}

// MARK: - API Service Extensions

extension APIService {
    /**
     * Record a new weight measurement for a pet
     * - Parameter weightRecord: Weight record data
     */
    func recordWeight(_ weightRecord: WeightRecord) async throws {
        let requestBody = WeightRecordCreate(
            pet_id: weightRecord.petId,
            weight_kg: weightRecord.weightKg,
            recorded_at: weightRecord.recordedAt,
            notes: weightRecord.notes,
            recorded_by_user_id: weightRecord.recordedByUserId
        )
        
        let _: WeightRecordResponse = try await post(
            endpoint: "/advanced-nutrition/weight/record",
            body: requestBody,
            responseType: WeightRecordResponse.self
        )
    }
    
    /**
     * Create a new weight goal for a pet
     * - Parameter weightGoal: Weight goal data
     */
    func createWeightGoal(_ weightGoal: WeightGoal) async throws {
        let requestBody = WeightGoalCreate(
            pet_id: weightGoal.petId,
            goal_type: weightGoal.goalType.rawValue,
            targetWeightKg: weightGoal.targetWeightKg,
            currentWeightKg: weightGoal.currentWeightKg,
            targetDate: weightGoal.targetDate,
            notes: weightGoal.notes
        )
        
        let _: WeightGoalResponse = try await post(
            endpoint: "/advanced-nutrition/weight/goals",
            body: requestBody,
            responseType: WeightGoalResponse.self
        )
    }
    
    /**
     * Update an existing weight goal for a pet
     * - Parameter weightGoal: Updated weight goal data
     */
    func updateWeightGoal(_ weightGoal: WeightGoal) async throws {
        let requestBody = WeightGoalUpdate(
            goal_type: weightGoal.goalType.rawValue,
            targetWeightKg: weightGoal.targetWeightKg,
            targetDate: weightGoal.targetDate,
            notes: weightGoal.notes
        )
        
        let _: WeightGoalResponse = try await post(
            endpoint: "/advanced-nutrition/weight/goals/\(weightGoal.id)",
            body: requestBody,
            responseType: WeightGoalResponse.self
        )
    }
    
    /**
     * Get weight history for a pet
     * - Parameter petId: Pet ID
     * - Returns: Array of weight records
     */
    func getWeightHistory(petId: String) async throws -> [WeightRecord] {
        let response: [WeightRecordResponse] = try await get(
            endpoint: "/advanced-nutrition/weight/history/\(petId)",
            responseType: [WeightRecordResponse].self
        )
        
        return response.map { response in
            WeightRecord(
                id: response.id,
                petId: response.pet_id,
                weightKg: response.weight_kg,
                recordedAt: response.recorded_at,
                notes: response.notes,
                recordedByUserId: response.recorded_by_user_id
            )
        }
    }
    
    /**
     * Get active weight goal for a pet
     * - Parameter petId: Pet ID
     * - Returns: Active weight goal or nil
     */
    func getActiveWeightGoal(petId: String) async throws -> WeightGoal? {
        let response: WeightGoalResponse? = try await get(
            endpoint: "/advanced-nutrition/weight/goals/\(petId)/active",
            responseType: WeightGoalResponse?.self
        )
        
        guard let response = response else { return nil }
        
        return WeightGoal(
            id: response.id,
            petId: response.pet_id,
            goalType: WeightGoalType(rawValue: response.goal_type) ?? .maintenance,
            targetWeightKg: response.targetWeightKg,
            currentWeightKg: response.currentWeightKg,
            targetDate: response.targetDate,
            isActive: response.isActive,
            notes: response.notes,
            createdAt: response.createdAt,
            updatedAt: response.updatedAt
        )
    }
}
