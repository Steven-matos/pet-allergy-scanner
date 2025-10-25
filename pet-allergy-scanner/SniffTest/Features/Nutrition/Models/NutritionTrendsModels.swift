//
//  NutritionTrendsModels.swift
//  SniffTest
//
//  Created by Steven Matos on 1/25/25.
//

import Foundation

// MARK: - Trend Data Models

/**
 * Calorie Trend
 * Daily calorie consumption data point
 */
struct CalorieTrend: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let calories: Double
    let target: Double?
    
    enum CodingKeys: String, CodingKey {
        case date, calories, target
    }
}

/**
 * Macronutrient Trend
 * Daily macronutrient breakdown
 */
struct MacronutrientTrend: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let protein: Double
    let fat: Double
    let fiber: Double
    
    enum CodingKeys: String, CodingKey {
        case date, protein, fat, fiber
    }
}

/**
 * Feeding Pattern
 * Daily feeding frequency and compatibility
 */
struct FeedingPattern: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let feedingCount: Int
    let compatibilityScore: Double
    
    enum CodingKeys: String, CodingKey {
        case date, feedingCount, compatibilityScore
    }
}

/**
 * Weight Correlation
 * Correlation between nutrition and weight changes
 */
struct WeightCorrelation: Codable {
    let correlation: Double
    let strength: String
    let interpretation: String
}

/**
 * Trend Period
 * Time period for trend analysis
 */
enum TrendPeriod: CaseIterable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    
    var displayName: String {
        switch self {
        case .sevenDays:
            return "7 Days"
        case .thirtyDays:
            return "30 Days"
        case .ninetyDays:
            return "90 Days"
        }
    }
    
    var days: Int {
        switch self {
        case .sevenDays:
            return 7
        case .thirtyDays:
            return 30
        case .ninetyDays:
            return 90
        }
    }
}

/**
 * Trend Direction
 * Direction of a trend over time
 */
enum TrendDirection {
    case increasing
    case decreasing
    case stable
}

// MARK: - API Response Models

/**
 * Nutritional Trend Response
 * Response model from backend API
 */
struct NutritionalTrendResponse: Codable {
    let petId: String
    let trendDate: Date
    let totalCalories: Double
    let totalProteinG: Double
    let totalFatG: Double
    let totalFiberG: Double
    let feedingCount: Int
    let averageCompatibilityScore: Double
    let weightChangeKg: Double
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case trendDate = "trend_date"
        case totalCalories = "total_calories"
        case totalProteinG = "total_protein_g"
        case totalFatG = "total_fat_g"
        case totalFiberG = "total_fiber_g"
        case feedingCount = "feeding_count"
        case averageCompatibilityScore = "average_compatibility_score"
        case weightChangeKg = "weight_change_kg"
    }
}

/**
 * Nutritional Trends Dashboard
 * Dashboard response from backend API
 */
struct NutritionalTrendsDashboard: Codable {
    let petId: String
    let periodStart: Date
    let periodEnd: Date
    let totalCalories: Double
    let averageDailyCalories: Double
    let averageFeedingFrequency: Double
    let weightCorrelation: WeightCorrelationData?
    let insights: [String]
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case totalCalories = "total_calories"
        case averageDailyCalories = "average_daily_calories"
        case averageFeedingFrequency = "average_feeding_frequency"
        case weightCorrelation = "weight_correlation"
        case insights
    }
}

/**
 * Weight Correlation Data
 * Weight correlation information from backend
 */
struct WeightCorrelationData: Codable {
    let correlation: Double
    let strength: String
    let interpretation: String
}

