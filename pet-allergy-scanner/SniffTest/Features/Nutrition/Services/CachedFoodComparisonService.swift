//
//  CachedFoodComparisonService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/25/25.
//

import Foundation
import Combine

/**
 * Cached Food Comparison Service
 * 
 * Provides intelligent caching for food comparison operations.
 * Caches comparison results and food details to reduce API calls.
 * 
 * Features:
 * - Cache-first loading for saved comparisons
 * - Cached food details to avoid repeated lookups
 * - Automatic cache invalidation
 * - User-scoped caching
 * 
 * Follows SOLID principles: Single responsibility for cached food comparison
 * Implements DRY by reusing cache patterns
 * Follows KISS by keeping the caching logic simple and transparent
 */
@MainActor
class CachedFoodComparisonService: ObservableObject {
    static let shared = CachedFoodComparisonService()
    
    // MARK: - Published Properties
    
    @Published var recentComparisons: [SavedComparison] = []
    @Published var currentComparison: FoodComparisonResults?
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private let apiService: APIService
    private let cacheCoordinator = UnifiedCacheCoordinator.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Cache for food details to avoid repeated API calls
    private var foodDetailsCache: [String: FoodAnalysis] = [:]
    
    /// Current user ID for cache scoping
    private var currentUserId: String? {
        authService.currentUser?.id
    }
    
    // MARK: - Initialization
    
    private init() {
        self.apiService = APIService.shared
        observeAuthChanges()
        loadRecentComparisons()
    }
    
    // MARK: - Public API
    
    /**
     * Compare multiple foods with caching
     * - Parameter foodIds: Array of food IDs to compare
     * - Parameter comparisonName: Name for the comparison
     * - Parameter pet: Optional pet to check for allergies/sensitivities
     * - Parameter forceRefresh: Force refresh food details from server
     * - Returns: Comparison results
     */
    func compareFoods(
        foodIds: [String],
        comparisonName: String,
        pet: Pet? = nil,
        forceRefresh: Bool = false
    ) async throws -> FoodComparisonResults {
        guard foodIds.count >= 2 else {
            throw ComparisonError.insufficientFoods
        }
        
        guard foodIds.count <= 3 else {
            throw ComparisonError.tooManyFoods
        }
        
        isLoading = true
        error = nil
        
        do {
            // Load food details with caching
            var foods = try await loadFoodDetailsWithCache(foodIds: foodIds, forceRefresh: forceRefresh)
            
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
            
            // Save to recent comparisons and cache
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
     * Load a saved comparison with caching
     * - Parameter comparisonId: ID of the comparison to load
     * - Parameter forceRefresh: Force refresh from server
     * - Returns: Comparison results
     */
    func loadComparison(comparisonId: String, forceRefresh: Bool = false) async throws -> FoodComparisonResults {
        guard let userId = currentUserId else {
            throw ComparisonError.notImplemented
        }
        
        // Try cache first unless force refresh is requested (synchronous for immediate UI)
        if !forceRefresh {
            let cacheKey = "food_comparison_\(userId)_\(comparisonId)"
            if let cachedComparison = cacheCoordinator.get(FoodComparisonResults.self, forKey: cacheKey) {
                currentComparison = cachedComparison
                return cachedComparison
            }
        }
        
        // Load from server
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
            
            // Convert to FoodAnalysis objects and cache them
            let foods = response.comparisonData.foods.map { food in
                let analysis = FoodAnalysis(
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
                
                // Cache food details
                foodDetailsCache[food.id] = analysis
                
                return analysis
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
            
            // Cache the comparison using UnifiedCacheCoordinator
            let cacheKey = "food_comparison_\(userId)_\(comparisonId)"
            cacheCoordinator.set(results, forKey: cacheKey) // Uses default policy (30 minutes)
            
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
        guard let userId = currentUserId else { return }
        
        do {
            // Delete from backend
            try await apiService.delete(
                endpoint: "/advanced-nutrition/comparisons/\(comparisonId)"
            )
            
            // Remove from local storage
            recentComparisons.removeAll { $0.id == comparisonId }
            
            // Invalidate cache using UnifiedCacheCoordinator
            let cacheKey = "food_comparison_\(userId)_\(comparisonId)"
            cacheCoordinator.invalidate(forKey: cacheKey)
            
        } catch {
            throw error
        }
    }
    
    /**
     * Get comparison history with caching
     * - Parameter forceRefresh: Force refresh from server
     * - Returns: Array of saved comparisons
     */
    func getComparisonHistory(forceRefresh: Bool = false) async -> [SavedComparison] {
        if !forceRefresh && !recentComparisons.isEmpty {
            return recentComparisons
        }
        
        loadRecentComparisons()
        return recentComparisons
    }
    
    /**
     * Clear all cached data
     * Call this on logout
     */
    func clearCache() {
        recentComparisons = []
        currentComparison = nil
        foodDetailsCache = [:]
        error = nil
        isLoading = false
        
        // Clear user-specific cache using UnifiedCacheCoordinator
        if let userId = currentUserId {
            cacheCoordinator.clearUserCache(userId: userId)
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Load food details with caching
     * - Parameter foodIds: Array of food IDs to load
     * - Parameter forceRefresh: Force refresh from server
     * - Returns: Array of food analysis objects
     */
    private func loadFoodDetailsWithCache(foodIds: [String], forceRefresh: Bool) async throws -> [FoodAnalysis] {
        var foodAnalyses: [FoodAnalysis] = []
        
        for foodId in foodIds {
            // Check cache first unless force refresh
            if !forceRefresh, let cachedFood = foodDetailsCache[foodId] {
                foodAnalyses.append(cachedFood)
                continue
            }
            
            // Load from server
            do {
                let foodItem = try await apiService.get(
                    endpoint: "/foods/\(foodId)",
                    responseType: FoodItem.self
                )
                
                // Convert FoodItem to FoodAnalysis
                let analysis = FoodAnalysis(
                    id: foodItem.id,
                    petId: "",
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
                
                // Cache the food details
                foodDetailsCache[foodId] = analysis
                foodAnalyses.append(analysis)
                
            } catch {
                throw ComparisonError.foodNotFound(foodId)
            }
        }
        
        return foodAnalyses
    }
    
    /**
     * Generate comparison metrics
     * - Parameter foods: Array of food analyses
     * - Returns: Comparison metrics
     */
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
     * - Parameters:
     *   - foods: Array of food analyses
     *   - pet: Pet to check against
     * - Returns: Updated food analyses with allergy warnings
     */
    private func checkPetAllergies(foods: [FoodAnalysis], pet: Pet) -> [FoodAnalysis] {
        return foods.map { food in
            var updatedFood = food
            var matchedAllergens: [String] = []
            
            let petSensitivities = Set(pet.knownSensitivities.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
            
            for ingredient in food.ingredients {
                let normalizedIngredient = ingredient.lowercased().trimmingCharacters(in: .whitespaces)
                
                if petSensitivities.contains(normalizedIngredient) {
                    matchedAllergens.append(ingredient)
                    continue
                }
                
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
    
    /**
     * Generate recommendations based on comparison metrics
     * - Parameters:
     *   - metrics: Comparison metrics
     *   - foods: Array of food analyses
     *   - pet: Optional pet for allergy checks
     * - Returns: Array of recommendations
     */
    private func generateRecommendations(metrics: ComparisonMetrics, foods: [FoodAnalysis], pet: Pet?) -> [String] {
        var recommendations: [String] = []
        
        // Pet allergy warnings
        if let pet = pet {
            let foodsWithAllergens = foods.filter { $0.hasPetAllergyWarning }
            if !foodsWithAllergens.isEmpty {
                recommendations.append("⚠️ WARNING: \(foodsWithAllergens.count) food(s) contain ingredients that \(pet.name) is sensitive to")
                
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
    
    /**
     * Determine best food options from comparison
     * - Parameters:
     *   - metrics: Comparison metrics
     *   - foods: Array of food analyses
     * - Returns: Best options for different criteria
     */
    private func determineBestOptions(metrics: ComparisonMetrics, foods: [FoodAnalysis]) -> BestOptions {
        let safeFoods = foods.filter { !$0.hasPetAllergyWarning }
        
        guard !safeFoods.isEmpty else {
            return BestOptions(
                overall: "⚠️ All foods contain pet sensitivities",
                value: "⚠️ All foods contain pet sensitivities",
                nutrition: "⚠️ All foods contain pet sensitivities"
            )
        }
        
        // Best overall
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
        
        // Best value
        let bestValue = safeFoods.min {
            (metrics.costPerCalorie[$0.id] ?? Double.infinity) < (metrics.costPerCalorie[$1.id] ?? Double.infinity)
        }?.foodName ?? "Unknown"
        
        // Best nutrition
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
     * Save comparison to backend and cache
     * - Parameter results: Comparison results to save
     */
    private func saveComparison(_ results: FoodComparisonResults) async {
        guard let userId = currentUserId else { return }
        
        do {
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
            
            // Cache the comparison using UnifiedCacheCoordinator
            let cacheKey = "food_comparison_\(userId)_\(response.id)"
            cacheCoordinator.set(results, forKey: cacheKey) // Uses default policy
            
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
     * Load recent comparisons from backend with caching
     */
    private func loadRecentComparisons() {
        guard let userId = currentUserId else { return }
        
        // Check cache first (synchronous for immediate UI)
        let cacheKey = "recent_comparisons_\(userId)"
        if let cachedComparisons = cacheCoordinator.get([SavedComparison].self, forKey: cacheKey) {
            recentComparisons = cachedComparisons
        }
        
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
                    // Cache the recent comparisons using UnifiedCacheCoordinator
                    cacheCoordinator.set(comparisons, forKey: cacheKey) // Uses default policy
                }
                
            } catch {
                print("Failed to load recent comparisons: \(error)")
                await MainActor.run {
                    if recentComparisons.isEmpty {
                        recentComparisons = []
                    }
                }
            }
        }
    }
    
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
}

// Models imported from FoodComparisonModels.swift

