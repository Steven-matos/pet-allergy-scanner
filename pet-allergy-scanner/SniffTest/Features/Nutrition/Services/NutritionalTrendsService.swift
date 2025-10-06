//
//  NutritionalTrendsService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/**
 * Nutritional Trends Service
 * 
 * Handles all nutritional trend analysis operations including:
 * - Trend data collection and analysis
 * - Pattern recognition and insights
 * - Historical data visualization
 * - Predictive analytics and recommendations
 * 
 * Follows SOLID principles with single responsibility for trend analysis
 * Implements DRY by reusing common analysis methods
 * Follows KISS by keeping the API simple and focused
 */
@MainActor
class NutritionalTrendsService: ObservableObject {
    static let shared = NutritionalTrendsService()
    
    @Published var calorieTrends: [String: [CalorieTrend]] = [:]
    @Published var macronutrientTrends: [String: [MacronutrientTrend]] = [:]
    @Published var feedingPatterns: [String: [FeedingPattern]] = [:]
    @Published var weightCorrelations: [String: WeightCorrelation] = [:]
    @Published var insights: [String: [String]] = [:]
    @Published var averageDailyCalories: [String: Double] = [:]
    @Published var averageFeedingFrequency: [String: Double] = [:]
    @Published var nutritionalBalanceScores: [String: Double] = [:]
    @Published var totalWeightChanges: [String: Double] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.apiService = APIService.shared
    }
    
    // MARK: - Public API
    
    /**
     * Load trends data for a pet
     * - Parameter petId: The pet's ID
     * - Parameter period: Analysis period
     */
    func loadTrendsData(for petId: String, period: TrendPeriod) async throws {
        isLoading = true
        error = nil
        
        do {
            // Load different types of trend data
            async let calorieData = loadCalorieTrends(petId: petId, period: period)
            async let macronutrientData = loadMacronutrientTrends(petId: petId, period: period)
            async let feedingData = loadFeedingPatterns(petId: petId, period: period)
            async let correlationData = loadWeightCorrelation(petId: petId, period: period)
            async let insightsData = loadInsights(petId: petId, period: period)
            
            // Wait for all data to load
            let (calories, macronutrients, feeding, correlation, insights) = try await (
                calorieData, macronutrientData, feedingData, correlationData, insightsData
            )
            
            // Update published properties
            calorieTrends[petId] = calories
            macronutrientTrends[petId] = macronutrients
            feedingPatterns[petId] = feeding
            weightCorrelations[petId] = correlation
            self.insights[petId] = insights
            
            // Calculate derived metrics
            calculateDerivedMetrics(for: petId)
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Get calorie trends for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Array of calorie trend data
     */
    func calorieTrends(for petId: String) -> [CalorieTrend] {
        return calorieTrends[petId] ?? []
    }
    
    /**
     * Get macronutrient trends for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Array of macronutrient trend data
     */
    func macronutrientTrends(for petId: String) -> [MacronutrientTrend] {
        return macronutrientTrends[petId] ?? []
    }
    
    /**
     * Get feeding patterns for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Array of feeding pattern data
     */
    func feedingPatterns(for petId: String) -> [FeedingPattern] {
        return feedingPatterns[petId] ?? []
    }
    
    /**
     * Get weight correlation for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Weight correlation data or nil
     */
    func weightCorrelation(for petId: String) -> WeightCorrelation? {
        return weightCorrelations[petId]
    }
    
    /**
     * Get insights for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Array of insight strings
     */
    func insights(for petId: String) -> [String] {
        return insights[petId] ?? []
    }
    
    /**
     * Get average daily calories for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Average daily calories
     */
    func averageDailyCalories(for petId: String) -> Double {
        return averageDailyCalories[petId] ?? 0.0
    }
    
    /**
     * Get average feeding frequency for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Average feeding frequency per day
     */
    func averageFeedingFrequency(for petId: String) -> Double {
        return averageFeedingFrequency[petId] ?? 0.0
    }
    
    /**
     * Get nutritional balance score for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Nutritional balance score (0-100)
     */
    func nutritionalBalanceScore(for petId: String) -> Double {
        return nutritionalBalanceScores[petId] ?? 0.0
    }
    
    /**
     * Get total weight change for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Total weight change in kg
     */
    func totalWeightChange(for petId: String) -> Double {
        return totalWeightChanges[petId] ?? 0.0
    }
    
    /**
     * Get calorie trend direction for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Trend direction
     */
    func calorieTrend(for petId: String) -> TrendDirection {
        let trends = calorieTrends(for: petId)
        guard trends.count >= 2 else { return .stable }
        
        let first = trends.last!.calories
        let last = trends.first!.calories
        let change = last - first
        
        if change > 50 {
            return .increasing
        } else if change < -50 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    /**
     * Get feeding trend direction for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Trend direction
     */
    func feedingTrend(for petId: String) -> TrendDirection {
        let patterns = feedingPatterns(for: petId)
        guard patterns.count >= 2 else { return .stable }
        
        let first = patterns.last!.feedingCount
        let last = patterns.first!.feedingCount
        let change = last - first
        
        if Double(change) > 0.5 {
            return .increasing
        } else if Double(change) < -0.5 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    /**
     * Get nutritional balance trend direction for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Trend direction
     */
    func balanceTrend(for petId: String) -> TrendDirection {
        let patterns = feedingPatterns(for: petId)
        guard patterns.count >= 2 else { return .stable }
        
        let first = patterns.last!.compatibilityScore
        let last = patterns.first!.compatibilityScore
        let change = last - first
        
        if change > 10 {
            return .increasing
        } else if change < -10 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    /**
     * Get weight change trend direction for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Trend direction
     */
    func weightChangeTrend(for petId: String) -> TrendDirection {
        let change = totalWeightChange(for: petId)
        
        if change > 0.5 {
            return .increasing
        } else if change < -0.5 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCalorieTrends(petId: String, period: TrendPeriod) async throws -> [CalorieTrend] {
        // Load real feeding data from backend
        let response = try await apiService.get(
            endpoint: "/advanced-nutrition/trends/\(petId)?days_back=\(period.days)",
            responseType: [NutritionalTrendResponse].self
        )
        
        // Convert API response to CalorieTrend models
        return response.map { trend in
            CalorieTrend(
                date: trend.trendDate,
                calories: trend.totalCalories,
                target: nil // User-defined targets will be implemented later
            )
        }.sorted { $0.date < $1.date }
    }
    
    private func loadMacronutrientTrends(petId: String, period: TrendPeriod) async throws -> [MacronutrientTrend] {
        // Load real feeding data from backend
        let response = try await apiService.get(
            endpoint: "/advanced-nutrition/trends/\(petId)?days_back=\(period.days)",
            responseType: [NutritionalTrendResponse].self
        )
        
        // Convert API response to MacronutrientTrend models
        return response.map { trend in
            MacronutrientTrend(
                date: trend.trendDate,
                protein: trend.totalProteinG,
                fat: trend.totalFatG,
                fiber: trend.totalFiberG
            )
        }.sorted { $0.date < $1.date }
    }
    
    private func loadFeedingPatterns(petId: String, period: TrendPeriod) async throws -> [FeedingPattern] {
        // Load real feeding data from backend
        let response = try await apiService.get(
            endpoint: "/advanced-nutrition/trends/\(petId)?days_back=\(period.days)",
            responseType: [NutritionalTrendResponse].self
        )
        
        // Convert API response to FeedingPattern models
        return response.map { trend in
            FeedingPattern(
                date: trend.trendDate,
                feedingCount: trend.feedingCount,
                compatibilityScore: trend.averageCompatibilityScore
            )
        }.sorted { $0.date < $1.date }
    }
    
    private func loadWeightCorrelation(petId: String, period: TrendPeriod) async throws -> WeightCorrelation? {
        // Load weight correlation data from backend
        do {
            let response = try await apiService.get(
                endpoint: "/advanced-nutrition/trends/dashboard/\(petId)?days_back=\(period.days)",
                responseType: NutritionalTrendsDashboard.self
            )
            
            guard let correlation = response.weightCorrelation else { return nil }
            
            return WeightCorrelation(
                correlation: correlation.correlation,
                strength: correlation.strength,
                interpretation: correlation.interpretation
            )
        } catch {
            // Return nil if no weight correlation data available
            return nil
        }
    }
    
    private func loadInsights(petId: String, period: TrendPeriod) async throws -> [String] {
        // Load insights from backend dashboard
        do {
            let response = try await apiService.get(
                endpoint: "/advanced-nutrition/trends/dashboard/\(petId)?days_back=\(period.days)",
                responseType: NutritionalTrendsDashboard.self
            )
            
            return response.insights
        } catch {
            // Return default insights if backend data unavailable
            return [
                "Start logging your pet's feeding to see personalized insights",
                "Regular feeding tracking helps identify nutritional patterns",
                "Monitor your pet's weight alongside feeding habits"
            ]
        }
    }
    
    private func calculateDerivedMetrics(for petId: String) {
        // Calculate average daily calories
        let calories = calorieTrends(for: petId)
        if !calories.isEmpty {
            let total = calories.reduce(0) { $0 + $1.calories }
            averageDailyCalories[petId] = total / Double(calories.count)
        }
        
        // Calculate average feeding frequency
        let patterns = feedingPatterns(for: petId)
        if !patterns.isEmpty {
            let total = patterns.reduce(0) { $0 + $1.feedingCount }
            averageFeedingFrequency[petId] = Double(total) / Double(patterns.count)
        }
        
        // Calculate nutritional balance score
        if !patterns.isEmpty {
            let total = patterns.reduce(0) { $0 + $1.compatibilityScore }
            nutritionalBalanceScores[petId] = total / Double(patterns.count)
        }
        
        // Calculate total weight change
        if let correlation = weightCorrelations[petId] {
            // This would be calculated from actual weight data
            totalWeightChanges[petId] = correlation.correlation * 2.0 // Mock calculation
        }
    }
}

// MARK: - Data Models

struct CalorieTrend: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let target: Double?
}

struct MacronutrientTrend: Identifiable {
    let id = UUID()
    let date: Date
    let protein: Double
    let fat: Double
    let fiber: Double
}

struct FeedingPattern: Identifiable {
    let id = UUID()
    let date: Date
    let feedingCount: Int
    let compatibilityScore: Double
}

struct WeightCorrelation {
    let correlation: Double
    let strength: String
    let interpretation: String
}

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

enum TrendDirection {
    case increasing
    case decreasing
    case stable
}
