//
//  FoodComparisonService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/**
 * Food Comparison Service
 * 
 * Handles all food comparison operations including:
 * - Side-by-side food comparison
 * - Nutritional value analysis
 * - Cost per nutritional value analysis
 * - Recommendation generation
 * - Comparison history management
 * 
 * Follows SOLID principles with single responsibility for food comparison
 * Implements DRY by reusing common analysis methods
 * Follows KISS by keeping the API simple and focused
 */
@MainActor
class FoodComparisonService: ObservableObject {
    static let shared = FoodComparisonService()
    
    @Published var recentComparisons: [SavedComparison] = []
    @Published var currentComparison: FoodComparisonResults?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.apiService = APIService.shared
        loadRecentComparisons()
    }
    
    // MARK: - Public API
    
    /**
     * Compare multiple foods
     * - Parameter foodIds: Array of food IDs to compare
     * - Parameter comparisonName: Name for the comparison
     * - Returns: Comparison results
     */
    func compareFoods(foodIds: [String], comparisonName: String) async throws -> FoodComparisonResults {
        guard foodIds.count >= 2 else {
            throw ComparisonError.insufficientFoods
        }
        
        guard foodIds.count <= 10 else {
            throw ComparisonError.tooManyFoods
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load food details
            let foods = try await loadFoodDetails(foodIds: foodIds)
            
            // Generate comparison metrics
            let metrics = generateComparisonMetrics(foods: foods)
            
            // Generate recommendations
            let recommendations = generateRecommendations(metrics: metrics, foods: foods)
            
            // Determine best options
            let bestOptions = determineBestOptions(metrics: metrics, foods: foods)
            
            // Create comparison results
            let results = FoodComparisonResults(
                id: UUID().uuidString,
                comparisonName: comparisonName,
                foods: foods,
                bestOverall: bestOptions.overall,
                bestValue: bestOptions.value,
                bestNutrition: bestOptions.nutrition,
                costPerCalorie: metrics.costPerCalorie,
                nutritionalDensity: metrics.nutritionalDensity,
                compatibilityScores: metrics.compatibilityScores,
                recommendations: recommendations
            )
            
            // Save to recent comparisons
            await saveComparison(results)
            
            currentComparison = results
            isLoading = false
            
            return results
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    /**
     * Load a saved comparison
     * - Parameter comparisonId: ID of the comparison to load
     * - Returns: Comparison results
     */
    func loadComparison(comparisonId: String) async throws -> FoodComparisonResults {
        // Implementation would load from backend
        // For now, return mock data
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // This would load from the backend API
        throw ComparisonError.notImplemented
    }
    
    /**
     * Delete a saved comparison
     * - Parameter comparisonId: ID of the comparison to delete
     */
    func deleteComparison(comparisonId: String) async throws {
        // Remove from local storage
        recentComparisons.removeAll { $0.id == comparisonId }
        
        // Delete from backend
        try await apiService.deleteComparison(comparisonId: comparisonId)
    }
    
    /**
     * Get comparison history
     * - Returns: Array of saved comparisons
     */
    func getComparisonHistory() -> [SavedComparison] {
        return recentComparisons
    }
    
    // MARK: - Private Methods
    
    private func loadFoodDetails(foodIds: [String]) async throws -> [FoodAnalysis] {
        // Implementation would call the backend API
        // For now, return mock data
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        return foodIds.enumerated().map { index, foodId in
            FoodAnalysis(
                id: foodId,
                petId: "mock-pet-id",
                foodName: "Sample Food \(index + 1)",
                brand: "Brand \(index + 1)",
                caloriesPer100g: 300.0 + Double.random(in: -100...100),
                proteinPercentage: 20.0 + Double.random(in: -10...10),
                fatPercentage: 10.0 + Double.random(in: -5...5),
                fiberPercentage: 4.0 + Double.random(in: -2...2),
                moisturePercentage: 10.0 + Double.random(in: -5...5),
                ingredients: ["Chicken", "Rice", "Vegetables"],
                allergens: index % 2 == 0 ? ["Chicken"] : [],
                analyzedAt: Date().addingTimeInterval(-Double.random(in: 0...86400))
            )
        }
    }
    
    private func generateComparisonMetrics(foods: [FoodAnalysis]) -> ComparisonMetrics {
        var costPerCalorie: [String: Double] = [:]
        var nutritionalDensity: [String: Double] = [:]
        var compatibilityScores: [String: Double] = [:]
        
        for (index, food) in foods.enumerated() {
            // Mock cost per calorie calculation
            costPerCalorie[food.id] = 0.01 + (Double(index) * 0.005)
            
            // Mock nutritional density calculation
            let essentialNutrients = food.proteinPercentage + food.fatPercentage
            nutritionalDensity[food.id] = essentialNutrients > 0 ? food.caloriesPer100g / essentialNutrients : 0
            
            // Mock compatibility score
            compatibilityScores[food.id] = 70.0 + (Double(index) * 5.0) + Double.random(in: -10...10)
        }
        
        return ComparisonMetrics(
            costPerCalorie: costPerCalorie,
            nutritionalDensity: nutritionalDensity,
            compatibilityScores: compatibilityScores
        )
    }
    
    private func generateRecommendations(metrics: ComparisonMetrics, foods: [FoodAnalysis]) -> [String] {
        var recommendations: [String] = []
        
        // Protein analysis
        let proteinValues = foods.map { $0.proteinPercentage }
        if let maxProtein = proteinValues.max(), let minProtein = proteinValues.min() {
            if maxProtein - minProtein > 10 {
                recommendations.append("Protein content varies significantly (\(String(format: "%.1f", minProtein))% - \(String(format: "%.1f", maxProtein))%)")
            }
        }
        
        // Calorie analysis
        let calorieValues = foods.map { $0.caloriesPer100g }
        if let maxCalories = calorieValues.max(), let minCalories = calorieValues.min() {
            if maxCalories - minCalories > 100 {
                recommendations.append("Calorie content varies significantly (\(String(format: "%.0f", minCalories)) - \(String(format: "%.0f", maxCalories)) kcal/100g)")
            }
        }
        
        // Cost analysis
        let costValues = Array(metrics.costPerCalorie.values)
        if let maxCost = costValues.max(), let minCost = costValues.min() {
            if maxCost / minCost > 2 {
                recommendations.append("Significant cost variation - consider value for money")
            }
        }
        
        // Compatibility analysis
        let compatibilityValues = Array(metrics.compatibilityScores.values)
        if let maxCompatibility = compatibilityValues.max(), let minCompatibility = compatibilityValues.min() {
            if maxCompatibility - minCompatibility > 30 {
                recommendations.append("Nutritional compatibility varies significantly")
            }
        }
        
        return recommendations
    }
    
    private func determineBestOptions(metrics: ComparisonMetrics, foods: [FoodAnalysis]) -> BestOptions {
        // Best overall (highest composite score)
        let overallScores = foods.map { food in
            let calorieScore = min(100, max(0, 100 - abs(food.caloriesPer100g - 350) / 3.5))
            let proteinScore = min(100, food.proteinPercentage * 2)
            let fatScore = min(100, food.fatPercentage * 4)
            let fiberScore = min(100, food.fiberPercentage * 10)
            let costScore = min(100, max(0, 100 - (metrics.costPerCalorie[food.id] ?? 0) * 1000))
            let compatibilityScore = metrics.compatibilityScores[food.id] ?? 0
            
            return (food, calorieScore * 0.25 + proteinScore * 0.25 + fatScore * 0.20 + fiberScore * 0.15 + costScore * 0.15 + compatibilityScore * 0.15)
        }
        
        let bestOverall = overallScores.max { $0.1 < $1.1 }?.0.foodName ?? "Unknown"
        
        // Best value (lowest cost per calorie)
        let bestValue = foods.min { 
            (metrics.costPerCalorie[$0.id] ?? Double.infinity) < (metrics.costPerCalorie[$1.id] ?? Double.infinity) 
        }?.foodName ?? "Unknown"
        
        // Best nutrition (highest nutritional density)
        let bestNutrition = foods.max { 
            (metrics.nutritionalDensity[$0.id] ?? 0) < (metrics.nutritionalDensity[$1.id] ?? 0) 
        }?.foodName ?? "Unknown"
        
        return BestOptions(
            overall: bestOverall,
            value: bestValue,
            nutrition: bestNutrition
        )
    }
    
    private func saveComparison(_ results: FoodComparisonResults) async {
        let savedComparison = SavedComparison(
            id: results.id,
            name: results.comparisonName,
            foodCount: results.foods.count,
            createdAt: Date()
        )
        
        recentComparisons.insert(savedComparison, at: 0)
        
        // Keep only last 20 comparisons
        if recentComparisons.count > 20 {
            recentComparisons = Array(recentComparisons.prefix(20))
        }
        
        // Save to backend
        try? await apiService.saveComparison(savedComparison)
    }
    
    private func loadRecentComparisons() {
        // Load from local storage or backend
        // For now, use mock data
        recentComparisons = [
            SavedComparison(
                id: "1",
                name: "Premium Food Comparison",
                foodCount: 3,
                createdAt: Date().addingTimeInterval(-86400)
            ),
            SavedComparison(
                id: "2",
                name: "Budget Options",
                foodCount: 4,
                createdAt: Date().addingTimeInterval(-172800)
            ),
            SavedComparison(
                id: "3",
                name: "Grain-Free Analysis",
                foodCount: 2,
                createdAt: Date().addingTimeInterval(-259200)
            )
        ]
    }
}

// MARK: - Data Models

struct FoodComparisonResults {
    let id: String
    let comparisonName: String
    let foods: [FoodAnalysis]
    let bestOverall: String
    let bestValue: String
    let bestNutrition: String
    let costPerCalorie: [String: Double]
    let nutritionalDensity: [String: Double]
    let compatibilityScores: [String: Double]
    let recommendations: [String]
}

struct ComparisonMetrics {
    let costPerCalorie: [String: Double]
    let nutritionalDensity: [String: Double]
    let compatibilityScores: [String: Double]
}

struct BestOptions {
    let overall: String
    let value: String
    let nutrition: String
}

struct FoodAnalysis: Identifiable {
    let id: String
    let petId: String
    let foodName: String
    let brand: String?
    let caloriesPer100g: Double
    let proteinPercentage: Double
    let fatPercentage: Double
    let fiberPercentage: Double
    let moisturePercentage: Double
    let ingredients: [String]
    let allergens: [String]
    let analyzedAt: Date
}

// MARK: - Errors

enum ComparisonError: Error, LocalizedError {
    case insufficientFoods
    case tooManyFoods
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .insufficientFoods:
            return "At least 2 foods are required for comparison"
        case .tooManyFoods:
            return "Maximum 10 foods allowed for comparison"
        case .notImplemented:
            return "Feature not yet implemented"
        }
    }
}

// MARK: - API Service Extensions

extension APIService {
    func saveComparison(_ comparison: SavedComparison) async throws {
        // Implementation would call the backend API
        // For now, simulate API call
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
    }
    
    func deleteComparison(comparisonId: String) async throws {
        // Implementation would call the backend API
        // For now, simulate API call
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
    }
}
