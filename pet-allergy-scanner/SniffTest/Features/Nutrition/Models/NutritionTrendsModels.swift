//
//  NutritionTrendsModels.swift
//  SniffTest
//
//  Created by Steven Matos on 1/25/25.
//

import Foundation
import SwiftUI

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
 * Matches server/app/models/nutrition/advanced_nutrition.py:NutritionalTrendsDashboard
 * 
 * Note: Backend returns empty arrays when no data, so all collections are non-optional
 */
struct NutritionalTrendsDashboard: Codable {
    let petId: String
    let trendPeriod: String
    let insights: [String]
    
    // Optional dynamic fields that may not always be present
    let calorieTrends: [String: String]?
    let macronutrientTrends: [String: String]?
    let weightCorrelation: [String: String]?
    let feedingPatterns: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case trendPeriod = "trend_period"
        case calorieTrends = "calorie_trends"
        case macronutrientTrends = "macronutrient_trends"
        case weightCorrelation = "weight_correlation"
        case feedingPatterns = "feeding_patterns"
        case insights
    }
    
    // Custom decoder to handle the dynamic arrays/dicts from backend
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        petId = try container.decode(String.self, forKey: .petId)
        trendPeriod = try container.decode(String.self, forKey: .trendPeriod)
        insights = try container.decode([String].self, forKey: .insights)
        
        // Decode optional dynamic fields - ignore if not present or wrong type
        calorieTrends = try? container.decode([String: String].self, forKey: .calorieTrends)
        macronutrientTrends = try? container.decode([String: String].self, forKey: .macronutrientTrends)
        weightCorrelation = try? container.decode([String: String].self, forKey: .weightCorrelation)
        feedingPatterns = try? container.decode([String: String].self, forKey: .feedingPatterns)
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

// MARK: - Nutritional Balance Breakdown Models

/**
 * Status of a macronutrient intake compared to recommendations
 * 
 * Defines color-coded ranges for nutritional balance assessment:
 * - optimal: 90-110% (Green) - Within ideal range
 * - slightlyLow: 80-89% (Yellow) - Slightly below recommended
 * - slightlyHigh: 111-120% (Yellow) - Slightly above recommended
 * - tooLow: <80% (Red/Orange) - Significantly below recommended
 * - tooHigh: >120% (Red/Orange) - Significantly above recommended
 */
enum MacroStatus: String, Codable {
    case optimal
    case slightlyLow
    case slightlyHigh
    case tooLow
    case tooHigh
    
    /**
     * Color associated with this status
     * Uses Trust & Nature Design System colors
     */
    var color: Color {
        switch self {
        case .optimal:
            return ModernDesignSystem.Colors.primary
        case .slightlyLow, .slightlyHigh:
            return ModernDesignSystem.Colors.goldenYellow
        case .tooLow, .tooHigh:
            return ModernDesignSystem.Colors.warmCoral
        }
    }
    
    /**
     * User-friendly display text for this status
     */
    var displayText: String {
        switch self {
        case .optimal:
            return "Optimal"
        case .slightlyLow:
            return "Slightly Low"
        case .slightlyHigh:
            return "Slightly High"
        case .tooLow:
            return "Too Low"
        case .tooHigh:
            return "Too High"
        }
    }
}

/**
 * Individual macronutrient data with context
 * 
 * Contains all information needed to display a single macronutrient's
 * status, including actual vs. recommended values, visual indicators,
 * and user-friendly explanatory text.
 */
struct MacroNutrientData: Codable {
    let name: String              // "Protein", "Fat", "Fiber"
    let actual: Double            // Actual percentage consumed
    let recommended: Double       // Recommended percentage for pet
    let percentage: Double        // (actual/recommended) * 100
    let status: MacroStatus       // Color-coded status
    let icon: String              // SF Symbol name for visualization
    let contextText: String       // User-friendly explanation
    
    /**
     * Accessibility label for VoiceOver
     * Provides complete information about the macronutrient status
     */
    var accessibilityLabel: String {
        "\(name): \(Int(percentage))% of recommended, status: \(status.displayText). \(contextText)"
    }
}

/**
 * Overall nutritional balance status
 * 
 * Indicates the overall health of the nutritional balance based on
 * how many nutrients are within the optimal range (90-110% of recommended)
 */
enum BalanceStatus: String, Codable {
    case optimal          // All nutrients in optimal range
    case good            // 1 nutrient out of optimal range
    case needsAttention  // 2 nutrients out of optimal range
    case critical        // All nutrients out of optimal range
    
    /**
     * User-friendly display text for this status
     */
    var displayText: String {
        switch self {
        case .optimal:
            return "Optimal"
        case .good:
            return "Good"
        case .needsAttention:
            return "Needs Attention"
        case .critical:
            return "Critical"
        }
    }
    
    /**
     * Color associated with this status
     * Uses Trust & Nature Design System colors
     */
    var color: Color {
        switch self {
        case .optimal:
            return ModernDesignSystem.Colors.primary
        case .good:
            return ModernDesignSystem.Colors.goldenYellow
        case .needsAttention:
            return ModernDesignSystem.Colors.warmCoral
        case .critical:
            return Color.red
        }
    }
}

/**
 * Nutritional balance summary with status and metrics
 * 
 * Provides an overall assessment of nutritional balance including
 * status, targets met count, balance index, and primary driver
 */
struct NutritionalBalanceSummary: Codable {
    let balanceIndex: Double?        // 0-100 balance index, nil if using status-only
    let status: BalanceStatus        // Overall status
    let targetsMet: Int              // Number of nutrients in optimal range
    let targetsTotal: Int            // Total number of nutrients (always 3)
    let primaryDriver: String        // Nutrient causing the biggest issue
    let primaryDriverPercent: Double // Percentage of recommended for primary driver
    let explanation: String          // One-line explanation text
    
    /**
     * Accessibility label for VoiceOver
     */
    var accessibilityLabel: String {
        var label = "Nutritional Balance: \(status.displayText). "
        label += "\(targetsMet) of \(targetsTotal) targets met. "
        if let index = balanceIndex {
            label += "Balance Index: \(Int(index)). "
        }
        label += "\(primaryDriver) is the biggest issue today (\(Int(primaryDriverPercent))% of recommended). "
        label += explanation
        return label
    }
}

/**
 * Action plan for improving nutritional balance
 * 
 * Provides prioritized, quantified steps to adjust nutrient intake
 */
struct NutrientPlan {
    let actions: [PlanAction]  // Prioritized list of actions
    
    init(actions: [PlanAction]) {
        self.actions = actions
    }
}

/**
 * Individual action in the nutrient plan
 * 
 * Specifies what adjustment to make for a specific nutrient
 */
struct PlanAction: Identifiable {
    let id: UUID
    let nutrient: String       // "Protein", "Fat", or "Fiber"
    let direction: String      // "Increase" or "Reduce"
    let amountGrams: Double    // Amount to adjust in grams per day
    let current: Double        // Current grams per day
    let target: Double         // Target grams per day (optimal range)
    let priority: Int          // Priority order (1 = highest)
    
    init(nutrient: String, direction: String, amountGrams: Double, current: Double, target: Double, priority: Int) {
        self.id = UUID()
        self.nutrient = nutrient
        self.direction = direction
        self.amountGrams = amountGrams
        self.current = current
        self.target = target
        self.priority = priority
    }
    
    /**
     * Human-readable instruction text
     */
    var instruction: String {
        "\(direction) \(nutrient) by ~\(Int(amountGrams))g/day"
    }
    
    /**
     * Priority indicator (e.g., "1.", "2.", "3.")
     */
    var priorityIndicator: String {
        "\(priority)."
    }
}

/**
 * Complete nutritional breakdown with all macros
 * 
 * Aggregates protein, fat, and fiber data into a single view model
 * for display in the nutritional balance breakdown sheet.
 * Includes overall score and flags for insufficient data scenarios.
 */
struct NutritionalBreakdown: Codable {
    let overallScore: Double           // Overall balance score (0-100) - DEPRECATED: Use summary instead
    let protein: MacroNutrientData     // Protein breakdown
    let fat: MacroNutrientData         // Fat breakdown
    let fiber: MacroNutrientData       // Fiber breakdown
    let hasInsufficientData: Bool      // True if <3 feeding records
    let summary: NutritionalBalanceSummary?  // New balance summary (nil if insufficient data)
    
    // Non-Codable: Plan is computed on the fly and doesn't need persistence
    let plan: NutrientPlan?            // Action plan (nil if insufficient data or all optimal)
    
    enum CodingKeys: String, CodingKey {
        case overallScore, protein, fat, fiber, hasInsufficientData, summary
        // plan is excluded from coding
    }
    
    /**
     * Complete accessibility description for VoiceOver
     * Announces overall status followed by each macro's status
     */
    var accessibilityDescription: String {
        if let summary = summary {
            return """
            \(summary.accessibilityLabel)
            \(protein.accessibilityLabel).
            \(fat.accessibilityLabel).
            \(fiber.accessibilityLabel)
            """
        } else {
            return """
            Nutritional Balance: Insufficient data.
            \(protein.accessibilityLabel).
            \(fat.accessibilityLabel).
            \(fiber.accessibilityLabel)
            """
        }
    }
    
    init(overallScore: Double, protein: MacroNutrientData, fat: MacroNutrientData, fiber: MacroNutrientData, hasInsufficientData: Bool, summary: NutritionalBalanceSummary?, plan: NutrientPlan?) {
        self.overallScore = overallScore
        self.protein = protein
        self.fat = fat
        self.fiber = fiber
        self.hasInsufficientData = hasInsufficientData
        self.summary = summary
        self.plan = plan
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overallScore = try container.decode(Double.self, forKey: .overallScore)
        protein = try container.decode(MacroNutrientData.self, forKey: .protein)
        fat = try container.decode(MacroNutrientData.self, forKey: .fat)
        fiber = try container.decode(MacroNutrientData.self, forKey: .fiber)
        hasInsufficientData = try container.decode(Bool.self, forKey: .hasInsufficientData)
        summary = try container.decodeIfPresent(NutritionalBalanceSummary.self, forKey: .summary)
        plan = nil  // Plan is not decoded, must be computed
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(overallScore, forKey: .overallScore)
        try container.encode(protein, forKey: .protein)
        try container.encode(fat, forKey: .fat)
        try container.encode(fiber, forKey: .fiber)
        try container.encode(hasInsufficientData, forKey: .hasInsufficientData)
        try container.encodeIfPresent(summary, forKey: .summary)
        // plan is not encoded
    }
}

