/**
 * Data Quality Assessment Service
 * Comprehensive data quality scoring based on ingredients and nutritional values
 * 
 * This service provides consistent data quality assessment across the iOS app,
 * matching the backend Python implementation for unified quality metrics.
 */

import Foundation

/**
 * Data quality classification levels
 */
enum DataQualityLevel: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.seal.fill"
        case .good: return "checkmark.circle.fill"
        case .fair: return "exclamationmark.circle"
        case .poor: return "xmark.circle"
        }
    }
}

/**
 * Comprehensive data quality metrics
 */
struct DataQualityMetrics {
    let overallScore: Double
    let level: DataQualityLevel
    let ingredientsScore: Double
    let nutritionalScore: Double
    let completenessScore: Double
    let ingredientsCount: Int
    let nutritionalFieldsCount: Int
    let missingCriticalFields: [String]
    let qualityIndicators: [String: Bool]
    
    /**
     * Get formatted quality summary for display
     */
    var summary: String {
        switch level {
        case .excellent:
            return "Complete nutritional and ingredient data available"
        case .good:
            return "Good nutritional data with some missing details"
        case .fair:
            return "Basic nutritional information available"
        case .poor:
            return "Limited nutritional data - consider adding more information"
        }
    }
}

/**
 * Enhanced data quality assessment service
 * Focuses on ingredients and nutritional values as primary quality indicators
 */
class DataQualityService {
    
    // MARK: - Constants
    
    /// Critical nutritional fields that should be present for good quality
    private static let criticalNutritionalFields = [
        "calories_per_100g",
        "protein_percentage",
        "fat_percentage", 
        "fiber_percentage",
        "moisture_percentage"
    ]
    
    /// Important nutritional fields that add to quality
    private static let importantNutritionalFields = [
        "ash_percentage",
        "carbohydrates_percentage",
        "sodium_percentage"
    ]
    
    /// Extended nutritional fields for excellent quality
    private static let extendedNutritionalFields = [
        "sugars_percentage",
        "saturated_fat_percentage"
    ]
    
    /// Quality thresholds
    private static let excellentThreshold: Double = 0.9
    private static let goodThreshold: Double = 0.7
    private static let fairThreshold: Double = 0.5
    
    // MARK: - Public Methods
    
    /**
     * Calculate ingredients quality score
     * 
     * - Parameter ingredients: Array of ingredient strings
     * - Returns: Tuple of (score, count)
     */
    static func calculateIngredientsScore(_ ingredients: [String]) -> (score: Double, count: Int) {
        let ingredientCount = ingredients.count
        
        let score: Double
        switch ingredientCount {
        case 0:
            score = 0.0
        case 1..<3:
            score = 0.2  // Very basic
        case 3..<6:
            score = 0.5  // Basic
        case 6..<10:
            score = 0.7  // Good
        case 10..<15:
            score = 0.85 // Very good
        default:
            score = 1.0  // Excellent detail
        }
        
        return (min(score, 1.0), ingredientCount)
    }
    
    /**
     * Calculate nutritional information quality score
     * 
     * - Parameter nutritionalData: Dictionary containing nutritional information
     * - Returns: Tuple of (score, count of available fields)
     */
    static func calculateNutritionalScore(_ nutritionalData: [String: Any]) -> (score: Double, count: Int) {
        var availableFields = 0
        var totalScore = 0.0
        
        // Check critical fields (weight: 0.4 each)
        var criticalScore = 0.0
        for field in criticalNutritionalFields {
            if nutritionalData[field] != nil {
                criticalScore += 0.4
                availableFields += 1
            }
        }
        
        // Check important fields (weight: 0.2 each)
        var importantScore = 0.0
        for field in importantNutritionalFields {
            if nutritionalData[field] != nil {
                importantScore += 0.2
                availableFields += 1
            }
        }
        
        // Check extended fields (weight: 0.1 each)
        var extendedScore = 0.0
        for field in extendedNutritionalFields {
            if nutritionalData[field] != nil {
                extendedScore += 0.1
                availableFields += 1
            }
        }
        
        totalScore = criticalScore + importantScore + extendedScore
        
        return (min(totalScore, 1.0), availableFields)
    }
    
    /**
     * Calculate overall data completeness score for a food product
     * 
     * - Parameter foodProduct: FoodProduct to assess
     * - Returns: Completeness score (0.0 to 1.0)
     */
    static func calculateCompletenessScore(_ foodProduct: FoodProduct) -> Double {
        var score = 0.0
        
        // Basic product information (30% weight)
        if !foodProduct.name.isEmpty { score += 0.1 }
        if foodProduct.brand != nil && !foodProduct.brand!.isEmpty { score += 0.1 }
        if foodProduct.barcode != nil && !foodProduct.barcode!.isEmpty { score += 0.1 }
        
        // Nutritional information (50% weight)
        let nutritionalData = foodProduct.nutritionalInfo?.toDictionary() ?? [:]
        let nutritionalScore = calculateNutritionalScore(nutritionalData).score
        score += nutritionalScore * 0.5
        
        // Ingredients information (20% weight)
        let ingredients = foodProduct.nutritionalInfo?.ingredients ?? []
        let ingredientsScore = calculateIngredientsScore(ingredients).score
        score += ingredientsScore * 0.2
        
        return min(score, 1.0)
    }
    
    /**
     * Identify missing critical nutritional fields
     * 
     * - Parameter nutritionalData: Dictionary containing nutritional information
     * - Returns: Array of missing critical field names
     */
    static func identifyMissingCriticalFields(_ nutritionalData: [String: Any]) -> [String] {
        return criticalNutritionalFields.filter { field in
            nutritionalData[field] == nil
        }
    }
    
    /**
     * Generate quality indicator flags
     * 
     * - Parameters:
     *   - nutritionalData: Dictionary containing nutritional information
     *   - ingredients: Array of ingredients
     * - Returns: Dictionary of quality indicators
     */
    static func generateQualityIndicators(_ nutritionalData: [String: Any], ingredients: [String]) -> [String: Bool] {
        return [
            "has_calories": nutritionalData["calories_per_100g"] != nil,
            "has_protein": nutritionalData["protein_percentage"] != nil,
            "has_fat": nutritionalData["fat_percentage"] != nil,
            "has_fiber": nutritionalData["fiber_percentage"] != nil,
            "has_moisture": nutritionalData["moisture_percentage"] != nil,
            "has_ingredients": !ingredients.isEmpty,
            "has_allergens": (nutritionalData["allergens"] as? [String])?.isEmpty == false,
            "has_additives": (nutritionalData["additives"] as? [String])?.isEmpty == false,
            "has_vitamins": (nutritionalData["vitamins"] as? [String])?.isEmpty == false,
            "has_minerals": (nutritionalData["minerals"] as? [String])?.isEmpty == false,
            "has_extended_nutrition": extendedNutritionalFields.contains { field in
                nutritionalData[field] != nil
            }
        ]
    }
    
    /**
     * Comprehensive data quality assessment for a food product
     * 
     * - Parameter foodProduct: FoodProduct to assess
     * - Returns: DataQualityMetrics object with detailed quality assessment
     */
    static func assessDataQuality(_ foodProduct: FoodProduct) -> DataQualityMetrics {
        let nutritionalData = foodProduct.nutritionalInfo?.toDictionary() ?? [:]
        let ingredients = foodProduct.nutritionalInfo?.ingredients ?? []
        
        // Calculate individual scores
        let ingredientsResult = calculateIngredientsScore(ingredients)
        let nutritionalResult = calculateNutritionalScore(nutritionalData)
        let completenessScore = calculateCompletenessScore(foodProduct)
        
        // Calculate overall score (weighted average)
        let overallScore = (
            ingredientsResult.score * 0.3 +
            nutritionalResult.score * 0.5 +
            completenessScore * 0.2
        )
        
        // Determine quality level
        let level: DataQualityLevel
        switch overallScore {
        case excellentThreshold...:
            level = .excellent
        case goodThreshold..<excellentThreshold:
            level = .good
        case fairThreshold..<goodThreshold:
            level = .fair
        default:
            level = .poor
        }
        
        // Identify missing critical fields
        let missingCriticalFields = identifyMissingCriticalFields(nutritionalData)
        
        // Generate quality indicators
        let qualityIndicators = generateQualityIndicators(nutritionalData, ingredients: ingredients)
        
        return DataQualityMetrics(
            overallScore: overallScore,
            level: level,
            ingredientsScore: ingredientsResult.score,
            nutritionalScore: nutritionalResult.score,
            completenessScore: completenessScore,
            ingredientsCount: ingredientsResult.count,
            nutritionalFieldsCount: nutritionalResult.count,
            missingCriticalFields: missingCriticalFields,
            qualityIndicators: qualityIndicators
        )
    }
    
    /**
     * Generate quality improvement recommendations
     * 
     * - Parameter metrics: DataQualityMetrics object
     * - Returns: Array of improvement recommendations
     */
    static func getQualityRecommendations(_ metrics: DataQualityMetrics) -> [String] {
        var recommendations: [String] = []
        
        // Ingredients recommendations
        if metrics.ingredientsCount == 0 {
            recommendations.append("Add ingredient list for better product transparency")
        } else if metrics.ingredientsCount < 3 {
            recommendations.append("Provide more detailed ingredient information")
        }
        
        // Nutritional recommendations
        if metrics.nutritionalScore < 0.5 {
            recommendations.append("Add basic nutritional information (calories, protein, fat)")
        } else if metrics.nutritionalScore < 0.8 {
            recommendations.append("Include additional nutritional values (fiber, moisture, ash)")
        }
        
        // Missing critical fields
        if !metrics.missingCriticalFields.isEmpty {
            let missingList = metrics.missingCriticalFields.joined(separator: ", ")
            recommendations.append("Add missing critical nutritional data: \(missingList)")
        }
        
        // Quality indicators
        if metrics.qualityIndicators["has_allergens"] == false {
            recommendations.append("Include allergen information for pet safety")
        }
        
        return recommendations
    }
    
    /**
     * Format quality metrics for display
     * 
     * - Parameter metrics: DataQualityMetrics object
     * - Returns: Formatted dictionary for UI display
     */
    static func formatQualitySummary(_ metrics: DataQualityMetrics) -> [String: Any] {
        return [
            "overall_score": round(metrics.overallScore * 1000) / 1000,
            "quality_level": metrics.level.rawValue,
            "breakdown": [
                "ingredients": [
                    "score": round(metrics.ingredientsScore * 1000) / 1000,
                    "count": metrics.ingredientsCount
                ],
                "nutritional": [
                    "score": round(metrics.nutritionalScore * 1000) / 1000,
                    "fields_count": metrics.nutritionalFieldsCount
                ],
                "completeness": [
                    "score": round(metrics.completenessScore * 1000) / 1000
                ]
            ],
            "missing_critical_fields": metrics.missingCriticalFields,
            "quality_indicators": metrics.qualityIndicators,
            "recommendations": getQualityRecommendations(metrics),
            "summary": metrics.summary
        ]
    }
}

// MARK: - Extensions

extension FoodProduct.NutritionalInfo {
    /**
     * Convert NutritionalInfo to dictionary for quality assessment
     */
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        // Nutritional values
        if let calories = caloriesPer100g { dict["calories_per_100g"] = calories }
        if let protein = proteinPercentage { dict["protein_percentage"] = protein }
        if let fat = fatPercentage { dict["fat_percentage"] = fat }
        if let fiber = fiberPercentage { dict["fiber_percentage"] = fiber }
        if let moisture = moisturePercentage { dict["moisture_percentage"] = moisture }
        if let ash = ashPercentage { dict["ash_percentage"] = ash }
        if let carbs = carbohydratesPercentage { dict["carbohydrates_percentage"] = carbs }
        if let sugars = sugarsPercentage { dict["sugars_percentage"] = sugars }
        if let satFat = saturatedFatPercentage { dict["saturated_fat_percentage"] = satFat }
        if let sodium = sodiumPercentage { dict["sodium_percentage"] = sodium }
        
        // Arrays
        if !ingredients.isEmpty { dict["ingredients"] = ingredients }
        if !allergens.isEmpty { dict["allergens"] = allergens }
        if !additives.isEmpty { dict["additives"] = additives }
        if !vitamins.isEmpty { dict["vitamins"] = vitamins }
        if !minerals.isEmpty { dict["minerals"] = minerals }
        
        return dict
    }
}
