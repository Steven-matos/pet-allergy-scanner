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
     * - Parameter pet: Optional pet to check for allergies/sensitivities
     * - Returns: Comparison results
     */
    func compareFoods(foodIds: [String], comparisonName: String, pet: Pet? = nil) async throws -> FoodComparisonResults {
        guard foodIds.count >= 2 else {
            throw ComparisonError.insufficientFoods
        }
        
        guard foodIds.count <= 3 else {
            throw ComparisonError.tooManyFoods
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load food details
            var foods = try await loadFoodDetails(foodIds: foodIds)
            
            // Check for pet allergies if pet is provided
            if let pet = pet {
                foods = checkPetAllergies(foods: foods, pet: pet)
            }
            
            // Generate comparison metrics
            let metrics = generateComparisonMetrics(foods: foods)
            
            // Generate recommendations
            let recommendations = generateRecommendations(metrics: metrics, foods: foods, pet: pet)
            
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
                recommendations: recommendations,
                petAllergiesChecked: pet != nil,
                petName: pet?.name
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
     * Load a saved comparison from backend
     * - Parameter comparisonId: ID of the comparison to load
     * - Returns: Comparison results
     */
    func loadComparison(comparisonId: String) async throws -> FoodComparisonResults {
        isLoading = true
        error = nil
        
        do {
            // Fetch comparison from backend
            struct ComparisonResponse: Codable {
                let id: String
                let comparisonName: String
                let foodIds: [String]
                let comparisonData: ComparisonData
                
                struct ComparisonData: Codable {
                    let foods: [FoodData]
                    
                    struct FoodData: Codable {
                        let id: String
                        let name: String
                        let brand: String?
                        let caloriesPer100g: Double
                        let proteinPercentage: Double
                        let fatPercentage: Double
                        let fiberPercentage: Double
                        let moisturePercentage: Double
                        let ingredients: [String]
                        let allergens: [String]
                        
                        enum CodingKeys: String, CodingKey {
                            case id, name, brand, ingredients, allergens
                            case caloriesPer100g = "calories_per_100g"
                            case proteinPercentage = "protein_percentage"
                            case fatPercentage = "fat_percentage"
                            case fiberPercentage = "fiber_percentage"
                            case moisturePercentage = "moisture_percentage"
                        }
                    }
                }
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case comparisonName = "comparison_name"
                    case foodIds = "food_ids"
                    case comparisonData = "comparison_data"
                }
            }
            
            let response = try await apiService.get(
                endpoint: "/advanced-nutrition/comparisons/\(comparisonId)",
                responseType: ComparisonResponse.self
            )
            
            // Convert to FoodAnalysis objects
            let foods = response.comparisonData.foods.map { food in
                FoodAnalysis(
                    id: food.id,
                    petId: "",
                    foodName: food.name,
                    brand: food.brand,
                    caloriesPer100g: food.caloriesPer100g,
                    proteinPercentage: food.proteinPercentage,
                    fatPercentage: food.fatPercentage,
                    fiberPercentage: food.fiberPercentage,
                    moisturePercentage: food.moisturePercentage,
                    ingredients: food.ingredients,
                    allergens: food.allergens,
                    analyzedAt: Date()
                )
            }
            
            // Generate metrics and recommendations
            let metrics = generateComparisonMetrics(foods: foods)
            let recommendations = generateRecommendations(metrics: metrics, foods: foods, pet: nil)
            let bestOptions = determineBestOptions(metrics: metrics, foods: foods)
            
            let results = FoodComparisonResults(
                id: response.id,
                comparisonName: response.comparisonName,
                foods: foods,
                bestOverall: bestOptions.overall,
                bestValue: bestOptions.value,
                bestNutrition: bestOptions.nutrition,
                costPerCalorie: metrics.costPerCalorie,
                nutritionalDensity: metrics.nutritionalDensity,
                compatibilityScores: metrics.compatibilityScores,
                recommendations: recommendations,
                petAllergiesChecked: false,
                petName: nil
            )
            
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
     * Delete a saved comparison
     * - Parameter comparisonId: ID of the comparison to delete
     */
    func deleteComparison(comparisonId: String) async throws {
        do {
            // Delete from backend
            try await apiService.delete(
                endpoint: "/advanced-nutrition/comparisons/\(comparisonId)"
            )
            
            // Remove from local storage
            recentComparisons.removeAll { $0.id == comparisonId }
            
        } catch {
            throw error
        }
    }
    
    /**
     * Get comparison history
     * - Returns: Array of saved comparisons
     */
    func getComparisonHistory() -> [SavedComparison] {
        return recentComparisons
    }
    
    // MARK: - Private Methods
    
    /**
     * Load food details from backend
     * - Parameter foodIds: Array of food IDs to load
     * - Returns: Array of food analysis objects
     */
    private func loadFoodDetails(foodIds: [String]) async throws -> [FoodAnalysis] {
        var foodAnalyses: [FoodAnalysis] = []
        
        // Load each food item
        for foodId in foodIds {
            do {
                let foodItem = try await apiService.get(
                    endpoint: "/foods/\(foodId)",
                    responseType: FoodItem.self
                )
                
                // Convert FoodItem to FoodAnalysis
                let analysis = FoodAnalysis(
                    id: foodItem.id,
                    petId: "", // Not pet-specific for comparison
                    foodName: foodItem.name,
                    brand: foodItem.brand,
                    caloriesPer100g: foodItem.nutritionalInfo?.caloriesPer100g ?? 0,
                    proteinPercentage: foodItem.nutritionalInfo?.proteinPercentage ?? 0,
                    fatPercentage: foodItem.nutritionalInfo?.fatPercentage ?? 0,
                    fiberPercentage: foodItem.nutritionalInfo?.fiberPercentage ?? 0,
                    moisturePercentage: foodItem.nutritionalInfo?.moisturePercentage ?? 0,
                    ingredients: foodItem.nutritionalInfo?.ingredients ?? [],
                    allergens: foodItem.nutritionalInfo?.allergens ?? [],
                    analyzedAt: foodItem.updatedAt
                )
                
                foodAnalyses.append(analysis)
            } catch {
                throw ComparisonError.foodNotFound(foodId)
            }
        }
        
        return foodAnalyses
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
    
    /**
     * Check foods against pet's known allergies and sensitivities
     * Updates each food with allergy warnings
     */
    private func checkPetAllergies(foods: [FoodAnalysis], pet: Pet) -> [FoodAnalysis] {
        return foods.map { food in
            var updatedFood = food
            var matchedAllergens: [String] = []
            
            // Check each ingredient against pet's known sensitivities
            let petSensitivities = Set(pet.knownSensitivities.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
            
            for ingredient in food.ingredients {
                let normalizedIngredient = ingredient.lowercased().trimmingCharacters(in: .whitespaces)
                
                // Check for exact matches
                if petSensitivities.contains(normalizedIngredient) {
                    matchedAllergens.append(ingredient)
                    continue
                }
                
                // Check for partial matches (e.g., "chicken meal" matches "chicken")
                for sensitivity in petSensitivities {
                    if normalizedIngredient.contains(sensitivity) || sensitivity.contains(normalizedIngredient) {
                        matchedAllergens.append(ingredient)
                        break
                    }
                }
            }
            
            updatedFood.petAllergyWarnings = matchedAllergens
            updatedFood.hasPetAllergyWarning = !matchedAllergens.isEmpty
            
            return updatedFood
        }
    }
    
    private func generateRecommendations(metrics: ComparisonMetrics, foods: [FoodAnalysis], pet: Pet?) -> [String] {
        var recommendations: [String] = []
        
        // Pet allergy warnings (MOST IMPORTANT - show first)
        if let pet = pet {
            let foodsWithAllergens = foods.filter { $0.hasPetAllergyWarning }
            if !foodsWithAllergens.isEmpty {
                recommendations.append("⚠️ WARNING: \(foodsWithAllergens.count) food(s) contain ingredients that \(pet.name) is sensitive to")
                
                // List specific foods with allergens
                for food in foodsWithAllergens {
                    if let allergens = food.petAllergyWarnings, !allergens.isEmpty {
                        recommendations.append("• \(food.foodName): Contains \(allergens.joined(separator: ", "))")
                    }
                }
            } else {
                recommendations.append("✓ All foods are safe for \(pet.name)'s known sensitivities")
            }
        }
        
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
        
        return recommendations
    }
    
    private func determineBestOptions(metrics: ComparisonMetrics, foods: [FoodAnalysis]) -> BestOptions {
        // CRITICAL: Filter out foods with pet sensitivities first!
        // Never recommend a food that clashes with pet's known sensitivities
        let safeFoods = foods.filter { !$0.hasPetAllergyWarning }
        
        // If all foods have sensitivities, return warning message
        guard !safeFoods.isEmpty else {
            return BestOptions(
                overall: "⚠️ All foods contain pet sensitivities",
                value: "⚠️ All foods contain pet sensitivities",
                nutrition: "⚠️ All foods contain pet sensitivities"
            )
        }
        
        // Best overall (highest composite score) - only from safe foods
        let overallScores = safeFoods.map { food in
            let calorieScore = min(100, max(0, 100 - abs(food.caloriesPer100g - 350) / 3.5))
            let proteinScore = min(100, food.proteinPercentage * 2)
            let fatScore = min(100, food.fatPercentage * 4)
            let fiberScore = min(100, food.fiberPercentage * 10)
            let costScore = min(100, max(0, 100 - (metrics.costPerCalorie[food.id] ?? 0) * 1000))
            let compatibilityScore = metrics.compatibilityScores[food.id] ?? 0
            
            return (food, calorieScore * 0.25 + proteinScore * 0.25 + fatScore * 0.20 + fiberScore * 0.15 + costScore * 0.15 + compatibilityScore * 0.15)
        }
        
        let bestOverall = overallScores.max { $0.1 < $1.1 }?.0.foodName ?? "Unknown"
        
        // Best value (lowest cost per calorie) - only from safe foods
        let bestValue = safeFoods.min { 
            (metrics.costPerCalorie[$0.id] ?? Double.infinity) < (metrics.costPerCalorie[$1.id] ?? Double.infinity) 
        }?.foodName ?? "Unknown"
        
        // Best nutrition (highest protein) - only from safe foods
        let bestNutrition = safeFoods.max { 
            $0.proteinPercentage < $1.proteinPercentage
        }?.foodName ?? "Unknown"
        
        return BestOptions(
            overall: bestOverall,
            value: bestValue,
            nutrition: bestNutrition
        )
    }
    
    /**
     * Save comparison to backend
     * - Parameter results: Comparison results to save
     */
    private func saveComparison(_ results: FoodComparisonResults) async {
        do {
            // Create comparison request
            struct ComparisonRequest: Codable {
                let comparisonName: String
                let foodIds: [String]
                
                enum CodingKeys: String, CodingKey {
                    case comparisonName = "comparison_name"
                    case foodIds = "food_ids"
                }
            }
            
            struct ComparisonResponse: Codable {
                let id: String
                let comparisonName: String
                let createdAt: String
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case comparisonName = "comparison_name"
                    case createdAt = "created_at"
                }
            }
            
            let request = ComparisonRequest(
                comparisonName: results.comparisonName,
                foodIds: results.foods.map { $0.id }
            )
            
            let response = try await apiService.post(
                endpoint: "/advanced-nutrition/comparisons",
                body: request,
                responseType: ComparisonResponse.self
            )
            
            // Add to recent comparisons
            let savedComparison = SavedComparison(
                id: response.id,
                name: response.comparisonName,
                foodCount: results.foods.count,
                createdAt: Date()
            )
            
            recentComparisons.insert(savedComparison, at: 0)
            
            // Keep only last 20 comparisons
            if recentComparisons.count > 20 {
                recentComparisons = Array(recentComparisons.prefix(20))
            }
            
        } catch {
            print("Failed to save comparison to backend: \(error)")
            // Still add to local cache even if backend save fails
            let savedComparison = SavedComparison(
                id: results.id,
                name: results.comparisonName,
                foodCount: results.foods.count,
                createdAt: Date()
            )
            
            recentComparisons.insert(savedComparison, at: 0)
            if recentComparisons.count > 20 {
                recentComparisons = Array(recentComparisons.prefix(20))
            }
        }
    }
    
    /**
     * Load recent comparisons from backend
     */
    private func loadRecentComparisons() {
        Task {
            do {
                struct ComparisonListItem: Codable {
                    let id: String
                    let comparisonName: String
                    let foodIds: [String]
                    let createdAt: String
                    
                    enum CodingKeys: String, CodingKey {
                        case id
                        case comparisonName = "comparison_name"
                        case foodIds = "food_ids"
                        case createdAt = "created_at"
                    }
                }
                
                let response = try await apiService.get(
                    endpoint: "/advanced-nutrition/comparisons?limit=20",
                    responseType: [ComparisonListItem].self
                )
                
                let comparisons = response.compactMap { item -> SavedComparison? in
                    // Parse ISO8601 date
                    let formatter = ISO8601DateFormatter()
                    guard let date = formatter.date(from: item.createdAt) else {
                        return nil
                    }
                    
                    return SavedComparison(
                        id: item.id,
                        name: item.comparisonName,
                        foodCount: item.foodIds.count,
                        createdAt: date
                    )
                }
                
                await MainActor.run {
                    recentComparisons = comparisons
                }
                
            } catch {
                print("Failed to load recent comparisons: \(error)")
                // Use empty array if load fails
                await MainActor.run {
                    recentComparisons = []
                }
            }
        }
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
    let petAllergiesChecked: Bool
    let petName: String?
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
    var hasPetAllergyWarning: Bool = false
    var petAllergyWarnings: [String]? = nil
}

// MARK: - Errors

enum ComparisonError: Error, LocalizedError {
    case insufficientFoods
    case tooManyFoods
    case foodNotFound(String)
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .insufficientFoods:
            return "At least 2 foods are required for comparison"
        case .tooManyFoods:
            return "Maximum 3 foods allowed for comparison"
        case .foodNotFound(let foodId):
            return "Food with ID \(foodId) not found"
        case .notImplemented:
            return "Feature not yet implemented"
        }
    }
}

// MARK: - API Service Extensions
// Removed placeholder methods - now using real API endpoints
