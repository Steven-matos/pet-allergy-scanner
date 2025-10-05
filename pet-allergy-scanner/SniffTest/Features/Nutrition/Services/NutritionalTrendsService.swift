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
        // Implementation would call the backend API
        // For now, return mock data
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        let days = period.days
        let now = Date()
        
        return (0..<days).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            let baseCalories = 300.0
            let variation = Double.random(in: -50...50)
            let calories = baseCalories + variation + Double(dayOffset) * 2 // Slight upward trend
            
            return CalorieTrend(
                date: date,
                calories: calories,
                target: 300.0
            )
        }.reversed()
    }
    
    private func loadMacronutrientTrends(petId: String, period: TrendPeriod) async throws -> [MacronutrientTrend] {
        // Implementation would call the backend API
        // For now, return mock data
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        let days = period.days
        let now = Date()
        
        return (0..<days).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            
            return MacronutrientTrend(
                date: date,
                protein: 25.0 + Double.random(in: -5...5),
                fat: 12.0 + Double.random(in: -3...3),
                fiber: 4.0 + Double.random(in: -1...1)
            )
        }.reversed()
    }
    
    private func loadFeedingPatterns(petId: String, period: TrendPeriod) async throws -> [FeedingPattern] {
        // Implementation would call the backend API
        // For now, return mock data
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        let days = period.days
        let now = Date()
        
        return (0..<days).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            
            return FeedingPattern(
                date: date,
                feedingCount: Int.random(in: 1...3),
                compatibilityScore: 70.0 + Double.random(in: -20...20)
            )
        }.reversed()
    }
    
    private func loadWeightCorrelation(petId: String, period: TrendPeriod) async throws -> WeightCorrelation? {
        // Implementation would call the backend API
        // For now, return mock data
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        return WeightCorrelation(
            correlation: Double.random(in: -0.8...0.8),
            strength: ["weak", "moderate", "strong"].randomElement() ?? "weak",
            interpretation: "Positive correlation between calorie intake and weight change"
        )
    }
    
    private func loadInsights(petId: String, period: TrendPeriod) async throws -> [String] {
        // Implementation would call the backend API
        // For now, return mock data
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        return [
            "Calorie intake has been consistent over the past \(period.displayName.lowercased())",
            "Feeding frequency is optimal for your pet's needs",
            "Nutritional balance is within healthy ranges",
            "Consider monitoring weight changes more closely"
        ]
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
