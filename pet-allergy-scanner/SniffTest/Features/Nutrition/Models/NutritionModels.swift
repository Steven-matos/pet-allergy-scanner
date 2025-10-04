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
     * - Parameter pet: The pet to calculate requirements for
     * - Returns: Calculated nutritional requirements
     */
    static func calculate(for pet: Pet) -> PetNutritionalRequirements {
        let baseCalories = calculateBaseCalories(for: pet)
        let activityMultiplier = getActivityMultiplier(for: pet.effectiveActivityLevel)
        let lifeStageMultiplier = getLifeStageMultiplier(for: pet.lifeStage)
        
        let dailyCalories = baseCalories * activityMultiplier * lifeStageMultiplier
        
        return PetNutritionalRequirements(
            petId: pet.id,
            dailyCalories: dailyCalories,
            proteinPercentage: getProteinPercentage(for: pet.lifeStage),
            fatPercentage: getFatPercentage(for: pet.lifeStage),
            fiberPercentage: getFiberPercentage(for: pet.lifeStage),
            moisturePercentage: 10.0, // Standard recommendation
            lifeStage: pet.lifeStage,
            activityLevel: pet.effectiveActivityLevel,
            calculatedAt: Date()
        )
    }
    
    /**
     * Calculate base calories using Resting Energy Requirement (RER) formula
     * RER = 70 * (body weight in kg)^0.75
     */
    private static func calculateBaseCalories(for pet: Pet) -> Double {
        guard let weightKg = pet.weightKg else {
            // Default weight based on species and life stage
            return getDefaultWeight(for: pet) * 70.0
        }
        return 70.0 * pow(weightKg, 0.75)
    }
    
    /**
     * Get activity level multiplier for calorie calculation
     */
    private static func getActivityMultiplier(for activityLevel: PetActivityLevel) -> Double {
        switch activityLevel {
        case .low:
            return 1.0
        case .moderate:
            return 1.2
        case .high:
            return 1.4
        }
    }
    
    /**
     * Get life stage multiplier for calorie calculation
     */
    private static func getLifeStageMultiplier(for lifeStage: PetLifeStage) -> Double {
        switch lifeStage {
        case .puppy:
            return 2.0
        case .adult:
            return 1.0
        case .senior:
            return 0.9
        case .pregnant:
            return 1.5
        case .lactating:
            return 2.0
        }
    }
    
    /**
     * Get protein percentage based on life stage
     */
    private static func getProteinPercentage(for lifeStage: PetLifeStage) -> Double {
        switch lifeStage {
        case .puppy:
            return 28.0
        case .adult:
            return 25.0
        case .senior:
            return 26.0
        case .pregnant:
            return 29.0
        case .lactating:
            return 30.0
        }
    }
    
    /**
     * Get fat percentage based on life stage
     */
    private static func getFatPercentage(for lifeStage: PetLifeStage) -> Double {
        switch lifeStage {
        case .puppy:
            return 17.0
        case .adult:
            return 12.0
        case .senior:
            return 10.0
        case .pregnant:
            return 20.0
        case .lactating:
            return 22.0
        }
    }
    
    /**
     * Get fiber percentage based on life stage
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case petId = "pet_id"
        case foodAnalysisId = "food_analysis_id"
        case amountGrams = "amount_grams"
        case feedingTime = "feeding_time"
        case notes
        case createdAt = "created_at"
    }
    
    /**
     * Calculate calories consumed from this feeding
     * - Parameter foodAnalysis: The nutritional analysis of the fed food
     * - Returns: Calories consumed
     */
    func calculateCaloriesConsumed(from foodAnalysis: FoodNutritionalAnalysis) -> Double {
        return (foodAnalysis.caloriesPer100g / 100.0) * amountGrams
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
 * Optional detailed nutritional breakdown
 */
struct NutritionalInfo: Codable {
    let caloriesPer100g: Double?
    let proteinPercentage: Double?
    let fatPercentage: Double?
    let fiberPercentage: Double?
    let moisturePercentage: Double?
    
    enum CodingKeys: String, CodingKey {
        case caloriesPer100g = "calories_per_100g"
        case proteinPercentage = "protein_percentage"
        case fatPercentage = "fat_percentage"
        case fiberPercentage = "fiber_percentage"
        case moisturePercentage = "moisture_percentage"
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
