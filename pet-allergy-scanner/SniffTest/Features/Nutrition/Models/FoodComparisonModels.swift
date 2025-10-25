//
//  FoodComparisonModels.swift
//  SniffTest
//
//  Created by Steven Matos on 1/25/25.
//

import Foundation

// MARK: - Food Comparison Models

/**
 * Food Comparison Results
 * Results of a food comparison
 */
struct FoodComparisonResults: Codable {
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

/**
 * Comparison Metrics
 * Metrics calculated during food comparison
 */
struct ComparisonMetrics {
    let costPerCalorie: [String: Double]
    let nutritionalDensity: [String: Double]
    let compatibilityScores: [String: Double]
}

/**
 * Best Options
 * Best food options from comparison
 */
struct BestOptions {
    let overall: String
    let value: String
    let nutrition: String
}

/**
 * Food Analysis
 * Detailed analysis of a food item
 */
struct FoodAnalysis: Identifiable, Codable {
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

/**
 * Saved Comparison
 * Metadata for a saved comparison
 */
struct SavedComparison: Identifiable, Codable {
    let id: String
    let name: String
    let foodCount: Int
    let createdAt: Date
}

// MARK: - Comparison Errors

/**
 * Comparison Error
 * Errors that can occur during food comparison
 */
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

