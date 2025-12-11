//
//  NutritionModels.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/**
 * Nutrition Data Models
 * 
 * Comprehensive models for pet nutrition tracking, including:
 * - Nutritional requirements based on pet characteristics
 * - Food analysis and recommendations
 * - Feeding history and tracking
 * - Dietary restrictions and sensitivities
 */

// MARK: - Core Nutrition Models

/**
 * Pet Nutritional Requirements
 * Calculated based on pet's age, weight, activity level, and life stage
 */
struct PetNutritionalRequirements: Codable {
    let petId: String
    let dailyCalories: Double
    let proteinPercentage: Double
    let fatPercentage: Double
    let fiberPercentage: Double
    let moisturePercentage: Double
    let lifeStage: PetLifeStage
    let activityLevel: PetActivityLevel
    let calculatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case dailyCalories = "daily_calories"
        case proteinPercentage = "protein_percentage"
        case fatPercentage = "fat_percentage"
        case fiberPercentage = "fiber_percentage"
        case moisturePercentage = "moisture_percentage"
        case lifeStage = "life_stage"
        case activityLevel = "activity_level"
        case calculatedAt = "calculated_at"
    }
    
    /**
     * Calculate nutritional requirements based on pet characteristics
     * Uses veterinary-approved formulas with species-specific multipliers
     * 
     * - Parameters:
     *   - pet: The pet to calculate requirements for
     *   - weightGoal: Optional weight goal for weight management calculations
     * - Returns: Calculated nutritional requirements
     */
    static func calculate(for pet: Pet, weightGoal: WeightGoal? = nil) -> PetNutritionalRequirements {
        // Determine which weight to use for RER calculation
        let weightForCalculation = determineCalculationWeight(for: pet, weightGoal: weightGoal)
        
        // Calculate RER (Resting Energy Requirement)
        let rer = calculateRER(weightKg: weightForCalculation)
        
        // Get appropriate multiplier based on species, life stage, and weight goal
        let multiplier = getCalorieMultiplier(
            for: pet.species,
            lifeStage: pet.lifeStage,
            activityLevel: pet.effectiveActivityLevel,
            weightGoal: weightGoal
        )
        
        // Calculate daily calories: MER = RER × multiplier
        var dailyCalories = rer * multiplier
        
        // Ensure minimum calories (server requires daily_calories > 0)
        // Use 200 as safe minimum for any pet
        dailyCalories = max(dailyCalories, 200.0)
        
        return PetNutritionalRequirements(
            petId: pet.id,
            dailyCalories: dailyCalories,
            proteinPercentage: getProteinPercentage(for: pet.lifeStage, species: pet.species),
            fatPercentage: getFatPercentage(for: pet.lifeStage, species: pet.species),
            fiberPercentage: getFiberPercentage(for: pet.lifeStage),
            moisturePercentage: 10.0, // Standard recommendation
            lifeStage: pet.lifeStage,
            activityLevel: pet.effectiveActivityLevel,
            calculatedAt: Date()
        )
    }
    
    /**
     * Determine which weight to use for calorie calculations
     * Priority: Weight goal target → Current weight → Default weight
     * 
     * - Parameters:
     *   - pet: The pet
     *   - weightGoal: Optional weight goal
     * - Returns: Weight in kg to use for RER calculation
     */
    private static func determineCalculationWeight(for pet: Pet, weightGoal: WeightGoal?) -> Double {
        // If there's an active weight goal with target weight, use it for calculations
        if let goal = weightGoal, let targetWeight = goal.targetWeightKg, targetWeight > 0 {
            return targetWeight
        }
        
        // Otherwise use current weight if available
        if let weightKg = pet.weightKg, weightKg > 0 {
            return weightKg
        }
        
        // Fallback to default weight based on species and life stage
        return getDefaultWeight(for: pet)
    }
    
    /**
     * Calculate RER (Resting Energy Requirement) using veterinary formula
     * RER = 70 × (body weight in kg)^0.75
     * 
     * This is the gold standard formula used by veterinarians worldwide.
     * 
     * - Parameter weightKg: Weight in kilograms
     * - Returns: Resting Energy Requirement in kcal/day
     */
    private static func calculateRER(weightKg: Double) -> Double {
        let rer = 70.0 * pow(weightKg, 0.75)
        // Ensure minimum RER (server requires > 0, use 100 as safe minimum)
        return max(rer, 100.0)
    }
    
    /**
     * Get species-specific calorie multiplier (MER factor)
     * Based on veterinary nutrition guidelines for dogs and cats
     * 
     * - Parameters:
     *   - species: Pet species (dog or cat)
     *   - lifeStage: Current life stage
     *   - activityLevel: Activity level
     *   - weightGoal: Optional weight goal for weight management
     * - Returns: Multiplier for RER to get daily calories (MER)
     */
    private static func getCalorieMultiplier(
        for species: PetSpecies,
        lifeStage: PetLifeStage,
        activityLevel: PetActivityLevel,
        weightGoal: WeightGoal?
    ) -> Double {
        // If there's a weight goal, use weight management multipliers
        if let goal = weightGoal {
            return getWeightManagementMultiplier(for: species, goalType: goal.goalType)
        }
        
        // Otherwise use standard maintenance multipliers
        switch species {
        case .dog:
            return getDogMaintenanceMultiplier(lifeStage: lifeStage, activityLevel: activityLevel)
        case .cat:
            return getCatMaintenanceMultiplier(lifeStage: lifeStage, activityLevel: activityLevel)
        }
    }
    
    /**
     * Dog-specific maintenance multipliers
     * Based on veterinary nutrition guidelines
     * 
     * Dogs generally need more calories than cats of similar weight
     */
    private static func getDogMaintenanceMultiplier(
        lifeStage: PetLifeStage,
        activityLevel: PetActivityLevel
    ) -> Double {
        switch lifeStage {
        case .puppy:
            // Puppies: 2.0-3.0 × RER (higher for younger puppies)
            return 2.5
            
        case .adult:
            switch activityLevel {
            case .low:
                // Neutered/indoor adult: ~1.6 × RER
                return 1.6
            case .moderate:
                // Active adult: ~1.8 × RER
                return 1.8
            case .high:
                // Very active/intact adult: ~2.0 × RER
                return 2.0
            }
            
        case .senior:
            // Senior dogs: ~1.4 × RER (less active, slower metabolism)
            return 1.4
            
        case .pregnant:
            // Pregnant: ~1.5-2.0 × RER
            return 1.7
            
        case .lactating:
            // Lactating: ~2.0-4.0 × RER depending on litter size
            return 3.0
        }
    }
    
    /**
     * Cat-specific maintenance multipliers
     * Based on veterinary nutrition guidelines
     * 
     * Cats generally need fewer calories than dogs of similar weight
     */
    private static func getCatMaintenanceMultiplier(
        lifeStage: PetLifeStage,
        activityLevel: PetActivityLevel
    ) -> Double {
        switch lifeStage {
        case .puppy: // .puppy is used for kittens too
            // Kittens: 2.0-2.5 × RER
            return 2.25
            
        case .adult:
            switch activityLevel {
            case .low:
                // Indoor/neutered adult cat: ~1.0-1.2 × RER
                return 1.0
            case .moderate:
                // Moderately active neutered cat: ~1.2 × RER
                return 1.2
            case .high:
                // Very active/intact cat: ~1.4 × RER
                return 1.4
            }
            
        case .senior:
            // Senior cats: ~1.1 × RER (less active)
            return 1.1
            
        case .pregnant:
            // Pregnant: ~1.6 × RER
            return 1.6
            
        case .lactating:
            // Lactating: ~2.0-2.5 × RER depending on litter size
            return 2.0
        }
    }
    
    /**
     * Weight management multipliers (for dogs and cats with weight goals)
     * 
     * - Parameters:
     *   - species: Pet species
     *   - goalType: Type of weight goal (loss, gain, maintenance)
     * - Returns: Multiplier for RER when using ideal/target weight
     */
    private static func getWeightManagementMultiplier(
        for species: PetSpecies,
        goalType: WeightGoalType
    ) -> Double {
        switch goalType {
        case .weightLoss:
            // Weight loss: 0.8 × RER (cats) or 1.0 × RER (dogs)
            // Using IDEAL weight for RER calculation
            return species == .cat ? 0.8 : 1.0
            
        case .weightGain:
            // Weight gain: 1.8 × RER
            // Using IDEAL weight for RER calculation
            return 1.8
            
        case .maintenance, .healthImprovement:
            // Maintenance at goal weight: use standard neutered adult multiplier
            return species == .cat ? 1.2 : 1.6
        }
    }
    
    /**
     * Get protein percentage based on life stage and species
     * Cats are obligate carnivores and need more protein than dogs
     */
    private static func getProteinPercentage(for lifeStage: PetLifeStage, species: PetSpecies) -> Double {
        switch species {
        case .cat:
            // Cats need 26-40% protein (higher than dogs)
            switch lifeStage {
            case .puppy: // Kittens
                return 35.0
            case .adult:
                return 30.0
            case .senior:
                return 32.0 // Senior cats benefit from higher protein
            case .pregnant:
                return 38.0
            case .lactating:
                return 40.0
            }
        case .dog:
            // Dogs need 18-29% protein
            switch lifeStage {
            case .puppy:
                return 28.0
            case .adult:
                return 25.0
            case .senior:
                return 23.0
            case .pregnant:
                return 29.0
            case .lactating:
                return 30.0
            }
        }
    }
    
    /**
     * Get fat percentage based on life stage and species
     * Varies by species and life stage
     */
    private static func getFatPercentage(for lifeStage: PetLifeStage, species: PetSpecies) -> Double {
        switch species {
        case .cat:
            // Cats need 9-15% fat (minimum)
            switch lifeStage {
            case .puppy: // Kittens
                return 15.0
            case .adult:
                return 12.0
            case .senior:
                return 10.0 // Lower fat for less active seniors
            case .pregnant:
                return 15.0
            case .lactating:
                return 18.0
            }
        case .dog:
            // Dogs need 5-15% fat (minimum)
            switch lifeStage {
            case .puppy:
                return 12.0
            case .adult:
                return 10.0
            case .senior:
                return 8.0
            case .pregnant:
                return 12.0
            case .lactating:
                return 15.0
            }
        }
    }
    
    /**
     * Get fiber percentage based on life stage
     * Fiber needs are similar for both dogs and cats
     */
    private static func getFiberPercentage(for lifeStage: PetLifeStage) -> Double {
        switch lifeStage {
        case .puppy:
            return 3.0
        case .adult:
            return 4.0
        case .senior:
            return 5.0
        case .pregnant:
            return 3.5
        case .lactating:
            return 3.0
        }
    }
    
    /**
     * Get default weight for pets without weight data
     */
    private static func getDefaultWeight(for pet: Pet) -> Double {
        switch pet.species {
        case .dog:
            return 20.0 // Average medium dog
        case .cat:
            return 4.0 // Average cat
        }
    }
}

/**
 * Food Nutritional Analysis
 * Represents the nutritional content of a scanned or analyzed pet food
 */
struct FoodNutritionalAnalysis: Codable, Identifiable {
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case petId = "pet_id"
        case foodName = "food_name"
        case brand
        case caloriesPer100g = "calories_per_100g"
        case proteinPercentage = "protein_percentage"
        case fatPercentage = "fat_percentage"
        case fiberPercentage = "fiber_percentage"
        case moisturePercentage = "moisture_percentage"
        case ingredients
        case allergens
        case analyzedAt = "analyzed_at"
    }
    
    /**
     * Custom decoder to handle missing fields in old cached data
     * Provides default values for missing required fields
     * Also handles string-encoded numbers from backend
     */
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        petId = try container.decode(String.self, forKey: .petId)
        foodName = try container.decode(String.self, forKey: .foodName)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        
        // Handle missing calories_per_100g in old cached data
        // Try to decode as Double first, then as String and convert
        if let caloriesDouble = try? container.decode(Double.self, forKey: .caloriesPer100g) {
            caloriesPer100g = caloriesDouble
        } else if let caloriesString = try? container.decode(String.self, forKey: .caloriesPer100g),
                  let caloriesDouble = Double(caloriesString) {
            caloriesPer100g = caloriesDouble
        } else {
            caloriesPer100g = 0.0
        }
        
        // Handle protein percentage (can be Double or String)
        if let proteinDouble = try? container.decode(Double.self, forKey: .proteinPercentage) {
            proteinPercentage = proteinDouble
        } else if let proteinString = try? container.decode(String.self, forKey: .proteinPercentage),
                  let proteinDouble = Double(proteinString) {
            proteinPercentage = proteinDouble
        } else {
            proteinPercentage = 0.0
        }
        
        // Handle fat percentage (can be Double or String)
        if let fatDouble = try? container.decode(Double.self, forKey: .fatPercentage) {
            fatPercentage = fatDouble
        } else if let fatString = try? container.decode(String.self, forKey: .fatPercentage),
                  let fatDouble = Double(fatString) {
            fatPercentage = fatDouble
        } else {
            fatPercentage = 0.0
        }
        
        // Handle fiber percentage (can be Double or String)
        if let fiberDouble = try? container.decode(Double.self, forKey: .fiberPercentage) {
            fiberPercentage = fiberDouble
        } else if let fiberString = try? container.decode(String.self, forKey: .fiberPercentage),
                  let fiberDouble = Double(fiberString) {
            fiberPercentage = fiberDouble
        } else {
            fiberPercentage = 0.0
        }
        
        // Handle moisture percentage (can be Double or String)
        if let moistureDouble = try? container.decode(Double.self, forKey: .moisturePercentage) {
            moisturePercentage = moistureDouble
        } else if let moistureString = try? container.decode(String.self, forKey: .moisturePercentage),
                  let moistureDouble = Double(moistureString) {
            moisturePercentage = moistureDouble
        } else {
            moisturePercentage = 0.0
        }
        
        ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        allergens = try container.decodeIfPresent([String].self, forKey: .allergens) ?? []
        
        analyzedAt = try container.decodeIfPresent(Date.self, forKey: .analyzedAt) ?? Date()
    }
    
    /**
     * Check if this food meets the pet's nutritional requirements
     * - Parameter requirements: The pet's nutritional requirements
     * - Returns: Nutrition compatibility assessment
     */
    func assessCompatibility(with requirements: PetNutritionalRequirements) -> NutritionCompatibility {
        var score = 0.0
        var issues: [String] = []
        var recommendations: [String] = []
        
        // Check protein content
        if proteinPercentage >= requirements.proteinPercentage {
            score += 25
        } else {
            issues.append("Protein content (\(String(format: "%.1f", proteinPercentage))%) is below recommended (\(String(format: "%.1f", requirements.proteinPercentage))%)")
            recommendations.append("Consider adding protein-rich supplements or switching to higher protein food")
        }
        
        // Check fat content
        let fatRange = (requirements.fatPercentage * 0.8)...(requirements.fatPercentage * 1.2)
        if fatRange.contains(fatPercentage) {
            score += 25
        } else if fatPercentage < requirements.fatPercentage * 0.8 {
            issues.append("Fat content (\(String(format: "%.1f", fatPercentage))%) is too low")
            recommendations.append("Consider adding healthy fats to your pet's diet")
        } else {
            issues.append("Fat content (\(String(format: "%.1f", fatPercentage))%) may be too high for sedentary pets")
            recommendations.append("Monitor your pet's weight and consider reducing portion sizes")
        }
        
        // Check fiber content
        let fiberRange = (requirements.fiberPercentage * 0.5)...(requirements.fiberPercentage * 2.0)
        if fiberRange.contains(fiberPercentage) {
            score += 25
        } else {
            issues.append("Fiber content (\(String(format: "%.1f", fiberPercentage))%) is outside optimal range")
            recommendations.append("Consider adjusting fiber intake based on your pet's digestive health")
        }
        
        // Check for allergens
        if !allergens.isEmpty {
            score -= 20
            issues.append("Contains potential allergens: \(allergens.joined(separator: ", "))")
            recommendations.append("Monitor your pet for allergic reactions")
        } else {
            score += 25
        }
        
        let compatibility: NutritionCompatibilityLevel
        if score >= 90 {
            compatibility = .excellent
        } else if score >= 70 {
            compatibility = .good
        } else if score >= 50 {
            compatibility = .fair
        } else {
            compatibility = .poor
        }
        
        return NutritionCompatibility(
            foodAnalysis: self,
            requirements: requirements,
            compatibility: compatibility,
            score: score,
            issues: issues,
            recommendations: recommendations,
            assessedAt: Date()
        )
    }
}

/**
 * Nutrition Compatibility Assessment
 * Result of comparing food analysis with pet requirements
 */
struct NutritionCompatibility: Codable {
    let foodAnalysis: FoodNutritionalAnalysis
    let requirements: PetNutritionalRequirements
    let compatibility: NutritionCompatibilityLevel
    let score: Double
    let issues: [String]
    let recommendations: [String]
    let assessedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case foodAnalysis = "food_analysis"
        case requirements
        case compatibility
        case score
        case issues
        case recommendations
        case assessedAt = "assessed_at"
    }
    
    /**
     * Get user-friendly compatibility description
     */
    var compatibilityDescription: String {
        switch compatibility {
        case .excellent:
            return "Excellent match for your pet's nutritional needs"
        case .good:
            return "Good nutritional match with minor considerations"
        case .fair:
            return "Fair match - some nutritional gaps to address"
        case .poor:
            return "Poor match - significant nutritional concerns"
        }
    }
    
    /**
     * Get color for UI representation
     */
    var compatibilityColor: String {
        switch compatibility {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .fair:
            return "orange"
        case .poor:
            return "red"
        }
    }
}

/**
 * Nutrition Compatibility Level
 */
enum NutritionCompatibilityLevel: String, Codable, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent:
            return "Excellent"
        case .good:
            return "Good"
        case .fair:
            return "Fair"
        case .poor:
            return "Poor"
        }
    }
}

/**
 * Feeding Record
 * Tracks individual feeding instances
 */
struct FeedingRecord: Codable, Identifiable {
    let id: String
    let petId: String
    let foodAnalysisId: String
    let amountGrams: Double
    let feedingTime: Date
    let notes: String?
    let createdAt: Date
    let foodName: String?
    let foodBrand: String?
    let calories: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case petId = "pet_id"
        case foodAnalysisId = "food_analysis_id"
        case amountGrams = "amount_grams"
        case feedingTime = "feeding_time"
        case notes = "notes"
        case createdAt = "created_at"
        case foodName = "food_name"
        case foodBrand = "food_brand"
        case calories = "calories"
    }
    
    /**
     * Custom decoder to handle calories as either string or number
     * Database may return calories as a string (e.g., "29.54") or as a number
     */
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        petId = try container.decode(String.self, forKey: .petId)
        foodAnalysisId = try container.decode(String.self, forKey: .foodAnalysisId)
        
        // Handle amount_grams as either string or number (database may return as string)
        if let amountString = try? container.decode(String.self, forKey: .amountGrams),
           let amount = Double(amountString) {
            amountGrams = amount
        } else {
            amountGrams = try container.decode(Double.self, forKey: .amountGrams)
        }
        
        feedingTime = try container.decode(Date.self, forKey: .feedingTime)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        foodName = try container.decodeIfPresent(String.self, forKey: .foodName)
        foodBrand = try container.decodeIfPresent(String.self, forKey: .foodBrand)
        
        // CRITICAL: Handle calories as either string or number
        // Database may return calories as a string (e.g., "29.54") or as a number
        // Since calories is now non-optional, we must always provide a value
        // Try multiple decoding strategies to handle different API response formats
        var decodedCalories: Double = 0.0
        var decodedSuccessfully = false
        
        // Check if calories key exists in the container
        let hasCaloriesKey = container.contains(.calories)
        
        // Strategy 1: Try decoding as String first (most common from database)
        // Database returns "calories":"29.54" as a string
        do {
            let caloriesString = try container.decode(String.self, forKey: .calories)
            if let caloriesValue = Double(caloriesString) {
                decodedCalories = caloriesValue
                decodedSuccessfully = true
            }
        } catch {
            // Not a string - try other strategies
        }
        
        // Strategy 2: If string decode failed, try as Double
        if !decodedSuccessfully {
            do {
                let caloriesNumber = try container.decode(Double.self, forKey: .calories)
                decodedCalories = caloriesNumber
                decodedSuccessfully = true
            } catch {
                // Not a number - try optional
            }
        }
        
        // Strategy 3: If both failed, try as optional Double (might be null)
        if !decodedSuccessfully {
            do {
                if let caloriesValue = try container.decodeIfPresent(Double.self, forKey: .calories) {
                    decodedCalories = caloriesValue
                    decodedSuccessfully = true
                }
            } catch {
                // Continue to strategy 4
            }
        }
        
        // Strategy 4: If still not decoded, check if key exists but is null
        if !decodedSuccessfully {
            if hasCaloriesKey {
                // Key exists - check if it's null or use default
                if (try? container.decodeNil(forKey: .calories)) == true {
                    decodedCalories = 0.0
                } else {
                    // Key exists but all decoding strategies failed
                    decodedCalories = 0.0
                }
            } else {
                // Key doesn't exist at all in JSON response
                decodedCalories = 0.0
            }
        }
        
        calories = decodedCalories
    }
    
    /**
     * Calculate calories consumed from this feeding
     * - Parameter foodAnalysis: The nutritional analysis of the fed food
     * - Returns: Calories consumed
     */
    func calculateCaloriesConsumed(from foodAnalysis: FoodNutritionalAnalysis) -> Double {
        return (foodAnalysis.caloriesPer100g / 100.0) * amountGrams
    }
    
    /**
     * Get calories for this feeding record
     * - Returns: Calories from API response if > 0, otherwise calculates from food analysis
     * - Note: Since calories is now non-optional, we check if it's > 0 to determine if it's valid
     */
    func getCalories(foodAnalysis: FoodNutritionalAnalysis?) -> Double? {
        // Prefer calories from API response if available and > 0
        if calories > 0 {
            return calories
        }
        // Fallback to calculation if food analysis is available
        if let analysis = foodAnalysis {
            return calculateCaloriesConsumed(from: analysis)
        }
        return nil
    }
}

/**
 * Daily Nutrition Summary
 * Aggregated nutrition data for a specific day
 */
struct DailyNutritionSummary: Codable {
    let petId: String
    let date: Date
    let totalCalories: Double
    let totalProtein: Double
    let totalFat: Double
    let totalFiber: Double
    let feedingCount: Int
    let averageCompatibility: Double
    let recommendations: [String]
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case date
        case totalCalories = "total_calories"
        case totalProtein = "total_protein"
        case totalFat = "total_fat"
        case totalFiber = "total_fiber"
        case feedingCount = "feeding_count"
        case averageCompatibility = "average_compatibility"
        case recommendations
    }
    
    /**
     * Check if daily nutrition meets requirements
     * - Parameter requirements: Pet's daily nutritional requirements
     * - Returns: Whether requirements are met
     */
    func meetsRequirements(_ requirements: PetNutritionalRequirements) -> Bool {
        let calorieRange = (requirements.dailyCalories * 0.9)...(requirements.dailyCalories * 1.1)
        return calorieRange.contains(totalCalories)
    }
}

// MARK: - API Models

/**
 * Nutrition Analysis Request
 * For creating new nutritional analyses
 */
struct NutritionAnalysisRequest: Codable {
    let petId: String
    let foodName: String
    let brand: String?
    let ingredients: [String]
    let nutritionalInfo: NutritionalInfo?
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case foodName = "food_name"
        case brand
        case ingredients
        case nutritionalInfo = "nutritional_info"
    }
}

/**
 * Nutritional Information
 * Contains nutritional data for a food item
 */
struct NutritionalInfo: Codable {
    let caloriesPer100g: Double?
    let proteinPercentage: Double?
    let fatPercentage: Double?
    let fiberPercentage: Double?
    let moisturePercentage: Double?
    let ashPercentage: Double?
    let ingredients: [String]?
    let allergens: [String]?
    
    enum CodingKeys: String, CodingKey {
        case caloriesPer100g = "calories_per_100g"
        case proteinPercentage = "protein_percentage"
        case fatPercentage = "fat_percentage"
        case fiberPercentage = "fiber_percentage"
        case moisturePercentage = "moisture_percentage"
        case ashPercentage = "ash_percentage"
        case ingredients
        case allergens
    }
}

/**
 * Feeding Record Request
 * For creating new feeding records
 */
struct FeedingRecordRequest: Codable {
    let petId: String
    let foodAnalysisId: String
    let amountGrams: Double
    let feedingTime: Date
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case foodAnalysisId = "food_analysis_id"
        case amountGrams = "amount_grams"
        case feedingTime = "feeding_time"
        case notes
    }
}

// MARK: - Extensions

extension Pet {
    /**
     * Get current nutritional requirements for this pet
     * - Returns: Calculated nutritional requirements
     */
    func getNutritionalRequirements() -> PetNutritionalRequirements {
        return PetNutritionalRequirements.calculate(for: self)
    }
    
    /**
     * Check if this pet can access multiple pet features
     * - Parameter user: The pet owner's user account
     * - Returns: Whether multiple pet features are available
     */
    func canAccessMultiplePetFeatures(user: User) -> Bool {
        return user.role == .premium
    }
}
