//
//  CalorieGoalsService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import Combine
import SwiftUI

/**
 * Calorie Goals Service
 * 
 * Handles calorie goal management including:
 * - Setting and retrieving calorie goals
 * - Syncing with backend API
 * - Local caching for offline access
 * 
 * Follows SOLID principles with single responsibility for goal management
 * Implements DRY by reusing common API patterns
 * Follows KISS by keeping the API simple and focused
 */
@MainActor
class CalorieGoalsService: ObservableObject {
    static let shared = CalorieGoalsService()
    
    @Published var petGoals: [String: Double] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService: APIService
    private let userDefaults = UserDefaults.standard
    private let goalsKey = "calorie_goals"
    
    private init() {
        self.apiService = APIService.shared
        loadLocalGoals()
    }
    
    // MARK: - Public API
    
    /**
     * Set calorie goal for a pet
     * - Parameter petId: The pet's ID
     * - Parameter calories: Daily calorie goal
     */
    func setGoal(for petId: String, calories: Double) async throws {
        isLoading = true
        error = nil
        
        do {
            let goalRequest = CalorieGoalRequest(petId: petId, dailyCalories: calories)
            let response = try await apiService.post(
                endpoint: "/nutrition/calorie-goals",
                body: goalRequest,
                responseType: CalorieGoalResponse.self
            )
            
            // Update local cache
            petGoals[petId] = response.dailyCalories
            saveLocalGoals()
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Get calorie goal for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Daily calorie goal or nil if not set
     */
    func getGoal(for petId: String) -> Double? {
        return petGoals[petId]
    }
    
    /**
     * Load calorie goals for all pets
     */
    func loadGoals() async throws {
        isLoading = true
        error = nil
        
        do {
            let response = try await apiService.get(
                endpoint: "/nutrition/calorie-goals",
                responseType: [CalorieGoalResponse].self
            )
            
            // Update local cache
            petGoals = Dictionary(uniqueKeysWithValues: response.map { ($0.petId, $0.dailyCalories) })
            saveLocalGoals()
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Delete calorie goal for a pet
     * - Parameter petId: The pet's ID
     */
    func deleteGoal(for petId: String) async throws {
        isLoading = true
        error = nil
        
        do {
            try await apiService.delete(endpoint: "/nutrition/calorie-goals/\(petId)")
            
            // Remove from local cache
            petGoals.removeValue(forKey: petId)
            saveLocalGoals()
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Update calorie goal for a pet
     * - Parameter petId: The pet's ID
     * - Parameter calories: New daily calorie goal
     */
    func updateGoal(for petId: String, calories: Double) async throws {
        try await setGoal(for: petId, calories: calories)
    }
    
    /**
     * Get goal progress for a pet on a specific date
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to check progress for
     */
    func getGoalProgress(for petId: String, date: Date) async -> GoalProgress? {
        guard let goal = getGoal(for: petId) else { return nil }
        
        do {
            let consumedCalories = try await getConsumedCalories(for: petId, date: date)
            let progress = GoalProgress(
                petId: petId,
                date: date,
                goalCalories: goal,
                consumedCalories: consumedCalories,
                remainingCalories: max(0, goal - consumedCalories),
                progressPercentage: min(100, (consumedCalories / goal) * 100)
            )
            
            return progress
        } catch {
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Get consumed calories for a pet on a specific date
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to check
     */
    private func getConsumedCalories(for petId: String, date: Date) async throws -> Double {
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: date)
        
        let response = try await apiService.get(
            endpoint: "/nutrition/daily-summary/\(petId)?date=\(dateString)",
            responseType: DailyNutritionSummary.self
        )
        
        return response.totalCalories
    }
    
    /**
     * Save goals to local storage
     */
    private func saveLocalGoals() {
        let goalsData = try? JSONEncoder().encode(petGoals)
        userDefaults.set(goalsData, forKey: goalsKey)
    }
    
    /**
     * Load goals from local storage
     */
    private func loadLocalGoals() {
        guard let goalsData = userDefaults.data(forKey: goalsKey),
              let goals = try? JSONDecoder().decode([String: Double].self, from: goalsData) else {
            return
        }
        
        petGoals = goals
    }
}

// MARK: - Data Models

/**
 * Calorie Goal Request
 * Request model for setting calorie goals
 */
struct CalorieGoalRequest: Codable {
    let petId: String
    let dailyCalories: Double
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case dailyCalories = "daily_calories"
    }
}

/**
 * Calorie Goal Response
 * Response model for calorie goals
 */
struct CalorieGoalResponse: Codable {
    let id: String
    let petId: String
    let dailyCalories: Double
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case petId = "pet_id"
        case dailyCalories = "daily_calories"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/**
 * Goal Progress
 * Progress tracking for calorie goals
 */
struct GoalProgress {
    let petId: String
    let date: Date
    let goalCalories: Double
    let consumedCalories: Double
    let remainingCalories: Double
    let progressPercentage: Double
    
    var isGoalMet: Bool {
        return consumedCalories >= goalCalories
    }
    
    var isOverGoal: Bool {
        return consumedCalories > goalCalories
    }
    
    var statusColor: Color {
        if isOverGoal {
            return .red
        } else if isGoalMet {
            return .green
        } else if progressPercentage >= 80 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Extensions

extension CalorieGoalsService {
    /**
     * Get all pets with goals set
     */
    func getPetsWithGoals() -> [String] {
        return Array(petGoals.keys)
    }
    
    /**
     * Check if a pet has a goal set
     * - Parameter petId: The pet's ID
     */
    func hasGoal(for petId: String) -> Bool {
        return petGoals[petId] != nil
    }
    
    /**
     * Get goal status for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Goal status description
     */
    func getGoalStatus(for petId: String) -> String {
        guard let goal = petGoals[petId] else {
            return "No goal set"
        }
        
        return "Goal: \(Int(goal)) kcal/day"
    }
    
    /**
     * Calculate suggested goal based on pet characteristics
     * - Parameter pet: The pet to calculate for
     * - Returns: Suggested daily calorie goal
     */
    func calculateSuggestedGoal(for pet: Pet) -> Double {
        guard let weight = pet.weightKg else {
            // Default based on species and life stage
            return getDefaultGoal(for: pet)
        }
        
        // Basic calculation based on weight and activity level
        let baseCalories = weight * 30 // Base calories per kg
        let activityMultiplier = getActivityMultiplier(for: pet.effectiveActivityLevel)
        let lifeStageMultiplier = getLifeStageMultiplier(for: pet.lifeStage)
        
        return baseCalories * activityMultiplier * lifeStageMultiplier
    }
    
    /**
     * Get default goal for pets without weight data
     * - Parameter pet: The pet to get default for
     */
    private func getDefaultGoal(for pet: Pet) -> Double {
        switch (pet.species, pet.lifeStage) {
        case (.dog, .puppy):
            return 400.0
        case (.dog, .adult):
            return 600.0
        case (.dog, .senior):
            return 500.0
        case (.cat, .puppy):
            return 250.0
        case (.cat, .adult):
            return 275.0
        case (.cat, .senior):
            return 250.0
        default:
            return 300.0
        }
    }
    
    /**
     * Get activity level multiplier
     * - Parameter activityLevel: The pet's activity level
     */
    private func getActivityMultiplier(for activityLevel: PetActivityLevel) -> Double {
        switch activityLevel {
        case .low:
            return 0.8
        case .moderate:
            return 1.0
        case .high:
            return 1.2
        }
    }
    
    /**
     * Get life stage multiplier
     * - Parameter lifeStage: The pet's life stage
     */
    private func getLifeStageMultiplier(for lifeStage: PetLifeStage) -> Double {
        switch lifeStage {
        case .puppy:
            return 1.5
        case .adult:
            return 1.0
        case .senior:
            return 0.9
        case .pregnant:
            return 1.3  // Increased caloric needs during pregnancy
        case .lactating:
            return 1.4  // Increased caloric needs during lactation
        }
    }
}
