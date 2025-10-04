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
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.apiService = APIService.shared
    }
    
    // MARK: - Public API
    
    /**
     * Record a new weight measurement for a pet
     * - Parameter petId: The pet's ID
     * - Parameter weight: Weight in kilograms
     * - Parameter notes: Optional notes about the measurement
     */
    func recordWeight(petId: String, weight: Double, notes: String? = nil) async throws {
        let weightRecord = WeightRecord(
            id: UUID().uuidString,
            petId: petId,
            weightKg: weight,
            recordedAt: Date(),
            notes: notes,
            recordedByUserId: nil
        )
        
        // Add to local storage
        if weightHistory[petId] == nil {
            weightHistory[petId] = []
        }
        weightHistory[petId]?.insert(weightRecord, at: 0)
        currentWeights[petId] = weight
        
        // Send to backend
        try await apiService.recordWeight(weightRecord)
        
        // Generate recommendations
        await generateRecommendations(for: petId)
    }
    
    /**
     * Create a weight goal for a pet
     * - Parameter petId: The pet's ID
     * - Parameter goalType: Type of weight goal
     * - Parameter targetWeight: Target weight in kilograms
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
        let weightGoal = WeightGoal(
            id: UUID().uuidString,
            petId: petId,
            goalType: goalType,
            targetWeightKg: targetWeight,
            currentWeightKg: currentWeights[petId],
            targetDate: targetDate,
            isActive: true,
            notes: notes,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Add to local storage
        weightGoals[petId] = weightGoal
        
        // Send to backend
        try await apiService.createWeightGoal(weightGoal)
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
            if let goal = try await apiService.getActiveWeightGoal(petId: petId) {
                weightGoals[petId] = goal
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

enum TrendDirection {
    case increasing
    case decreasing
    case stable
}

enum TrendStrength {
    case weak
    case moderate
    case strong
}

// MARK: - API Service Extensions

extension APIService {
    func recordWeight(_ weightRecord: WeightRecord) async throws {
        // Implementation would call the backend API
        // For now, simulate API call
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
    }
    
    func createWeightGoal(_ weightGoal: WeightGoal) async throws {
        // Implementation would call the backend API
        // For now, simulate API call
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
    }
    
    func getWeightHistory(petId: String) async throws -> [WeightRecord] {
        // Implementation would call the backend API
        // For now, return mock data
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        return [
            WeightRecord(
                id: "1",
                petId: petId,
                weightKg: 25.5,
                recordedAt: Date().addingTimeInterval(-86400), // 1 day ago
                notes: "Morning weight",
                recordedByUserId: nil
            ),
            WeightRecord(
                id: "2",
                petId: petId,
                weightKg: 25.3,
                recordedAt: Date().addingTimeInterval(-172800), // 2 days ago
                notes: nil,
                recordedByUserId: nil
            ),
            WeightRecord(
                id: "3",
                petId: petId,
                weightKg: 25.7,
                recordedAt: Date().addingTimeInterval(-259200), // 3 days ago
                notes: "After exercise",
                recordedByUserId: nil
            )
        ]
    }
    
    func getActiveWeightGoal(petId: String) async throws -> WeightGoal? {
        // Implementation would call the backend API
        // For now, return mock data
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        return WeightGoal(
            id: "goal1",
            petId: petId,
            goalType: .maintenance,
            targetWeightKg: 25.0,
            currentWeightKg: 25.5,
            targetDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
            isActive: true,
            notes: "Maintain healthy weight",
            createdAt: Date().addingTimeInterval(-604800), // 1 week ago
            updatedAt: Date().addingTimeInterval(-604800)
        )
    }
}
