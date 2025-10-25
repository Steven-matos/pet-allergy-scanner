//
//  CachedNutritionalTrendsService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/25/25.
//

import Foundation
import Combine

/**
 * Cached Nutritional Trends Service
 * 
 * Provides intelligent caching for nutritional trend analysis.
 * Significantly reduces API calls for trend data by caching results.
 * 
 * Features:
 * - Cache-first loading pattern
 * - Automatic cache invalidation on data changes
 * - Background refresh for stale data
 * - User and pet-scoped caching
 * 
 * Follows SOLID principles: Single responsibility for cached trend analysis
 * Implements DRY by reusing cache patterns
 * Follows KISS by keeping the caching logic simple and transparent
 */
@MainActor
class CachedNutritionalTrendsService: ObservableObject {
    static let shared = CachedNutritionalTrendsService()
    
    // MARK: - Published Properties
    
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
    @Published var isRefreshing = false
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private let apiService: APIService
    private let cacheService = CacheService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Current user ID for cache scoping
    private var currentUserId: String? {
        authService.currentUser?.id
    }
    
    // MARK: - Initialization
    
    private init() {
        self.apiService = APIService.shared
        observeAuthChanges()
    }
    
    // MARK: - Public API
    
    /**
     * Check if we have cached trends data for a pet
     * - Parameter petId: The pet's ID
     * - Returns: True if we have any cached trends data
     */
    func hasCachedTrendsData(for petId: String) -> Bool {
        let hasCalorieTrends = !calorieTrends(for: petId).isEmpty
        let hasMacroTrends = !macronutrientTrends(for: petId).isEmpty
        let hasFeedingPatterns = !feedingPatterns(for: petId).isEmpty
        let hasWeightCorrelation = weightCorrelation(for: petId) != nil
        let hasInsights = !insights(for: petId).isEmpty
        
        return hasCalorieTrends || hasMacroTrends || hasFeedingPatterns || hasWeightCorrelation || hasInsights
    }
    
    /**
     * Load trends data with intelligent caching
     * - Parameter petId: The pet's ID
     * - Parameter period: Analysis period
     * - Parameter forceRefresh: Force refresh from server, bypassing cache
     */
    func loadTrendsData(for petId: String, period: TrendPeriod, forceRefresh: Bool = false) async throws {
        guard let userId = currentUserId else {
            self.calorieTrends[petId] = []
            self.macronutrientTrends[petId] = []
            self.feedingPatterns[petId] = []
            self.weightCorrelations[petId] = nil
            self.insights[petId] = []
            return
        }
        
        // Generate cache key based on pet and period
        let cacheKey = generateTrendsCacheKey(petId: petId, period: period, userId: userId)
        
        // Try cache first unless force refresh is requested
        if !forceRefresh {
            if let cachedData = cacheService.retrieve(TrendsCacheData.self, forKey: cacheKey) {
                // Only use cache if it has meaningful data (at least one non-empty array)
                let hasData = !cachedData.calorieTrends.isEmpty || 
                             !cachedData.macronutrientTrends.isEmpty || 
                             !cachedData.feedingPatterns.isEmpty ||
                             cachedData.weightCorrelation != nil ||
                             !cachedData.insights.isEmpty
                
                if hasData {
                    // Update published properties from cache
                    self.calorieTrends[petId] = cachedData.calorieTrends
                    self.macronutrientTrends[petId] = cachedData.macronutrientTrends
                    self.feedingPatterns[petId] = cachedData.feedingPatterns
                    self.weightCorrelations[petId] = cachedData.weightCorrelation
                    self.insights[petId] = cachedData.insights
                    
                    // Calculate derived metrics
                    calculateDerivedMetrics(for: petId)
                    
                    // Trigger background refresh if cache is stale
                    refreshTrendsInBackground(petId: petId, period: period, cacheKey: cacheKey)
                    return
                }
            }
        }
        
        // Load from server if cache miss, force refresh, or empty cached data
        try await loadTrendsFromServer(petId: petId, period: period)
    }
    
    /**
     * Refresh trends data from server
     * - Parameter petId: The pet's ID
     * - Parameter period: Analysis period
     */
    func refreshTrends(for petId: String, period: TrendPeriod) async throws {
        try await loadTrendsData(for: petId, period: period, forceRefresh: true)
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
    
    /**
     * Invalidate trends cache for a pet
     * Call this when feeding records are added/updated/deleted
     * - Parameter petId: The pet's ID
     */
    func invalidateTrendsCache(for petId: String) {
        guard let userId = currentUserId else { return }
        
        // Invalidate all period caches for this pet
        for period in TrendPeriod.allCases {
            let cacheKey = generateTrendsCacheKey(petId: petId, period: period, userId: userId)
            cacheService.invalidate(forKey: cacheKey)
        }
        
        // Clear local data
        calorieTrends.removeValue(forKey: petId)
        macronutrientTrends.removeValue(forKey: petId)
        feedingPatterns.removeValue(forKey: petId)
        weightCorrelations.removeValue(forKey: petId)
        insights.removeValue(forKey: petId)
        averageDailyCalories.removeValue(forKey: petId)
        averageFeedingFrequency.removeValue(forKey: petId)
        nutritionalBalanceScores.removeValue(forKey: petId)
        totalWeightChanges.removeValue(forKey: petId)
    }
    
    /**
     * Clear all cached trends data
     * Call this on logout
     */
    func clearCache() {
        calorieTrends = [:]
        macronutrientTrends = [:]
        feedingPatterns = [:]
        weightCorrelations = [:]
        insights = [:]
        averageDailyCalories = [:]
        averageFeedingFrequency = [:]
        nutritionalBalanceScores = [:]
        totalWeightChanges = [:]
        error = nil
        isLoading = false
        isRefreshing = false
        
        // Clear user-specific cache
        if let userId = currentUserId {
            cacheService.clearUserCache(userId: userId)
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Load trends from server
     * - Parameter petId: The pet's ID
     * - Parameter period: Analysis period
     */
    private func loadTrendsFromServer(petId: String, period: TrendPeriod) async throws {
        guard let userId = currentUserId else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Load different types of trend data in parallel
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
            self.calorieTrends[petId] = calories
            self.macronutrientTrends[petId] = macronutrients
            self.feedingPatterns[petId] = feeding
            self.weightCorrelations[petId] = correlation
            self.insights[petId] = insights
            
            // Calculate derived metrics
            calculateDerivedMetrics(for: petId)
            
            // Cache the data
            let cacheData = TrendsCacheData(
                calorieTrends: calories,
                macronutrientTrends: macronutrients,
                feedingPatterns: feeding,
                weightCorrelation: correlation,
                insights: insights
            )
            
            let cacheKey = generateTrendsCacheKey(petId: petId, period: period, userId: userId)
            cacheService.store(cacheData, forKey: cacheKey, policy: .timeBased(300)) // 5 minutes cache
            
            isLoading = false
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    /**
     * Refresh trends in background if cache is stale
     * - Parameter petId: The pet's ID
     * - Parameter period: Analysis period
     * - Parameter cacheKey: Cache key to check
     */
    private func refreshTrendsInBackground(petId: String, period: TrendPeriod, cacheKey: String) {
        // Check if cache exists (if not, it's stale)
        if !cacheService.exists(forKey: cacheKey) {
            isRefreshing = true
            
            Task {
                do {
                    try await loadTrendsFromServer(petId: petId, period: period)
                    isRefreshing = false
                } catch {
                    print("❌ Background refresh failed: \(error)")
                    isRefreshing = false
                }
            }
        }
    }
    
    /**
     * Generate cache key for trends data
     * - Parameters:
     *   - petId: The pet's ID
     *   - period: Analysis period
     *   - userId: User ID for scoping
     * - Returns: Cache key string
     */
    private func generateTrendsCacheKey(petId: String, period: TrendPeriod, userId: String) -> String {
        return "nutritional_trends_\(userId)_\(petId)_\(period.days)days"
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
    
    /**
     * Load calorie trends from server
     * - Parameters:
     *   - petId: The pet's ID
     *   - period: Analysis period
     * - Returns: Array of calorie trends
     */
    private func loadCalorieTrends(petId: String, period: TrendPeriod) async throws -> [CalorieTrend] {
        let response = try await apiService.get(
            endpoint: "/advanced-nutrition/trends/\(petId)?days_back=\(period.days)",
            responseType: [NutritionalTrendResponse].self
        )
        
        return response.map { trend in
            CalorieTrend(
                date: trend.trendDate,
                calories: trend.totalCalories,
                target: nil
            )
        }.sorted { $0.date < $1.date }
    }
    
    /**
     * Load macronutrient trends from server
     * - Parameters:
     *   - petId: The pet's ID
     *   - period: Analysis period
     * - Returns: Array of macronutrient trends
     */
    private func loadMacronutrientTrends(petId: String, period: TrendPeriod) async throws -> [MacronutrientTrend] {
        let response = try await apiService.get(
            endpoint: "/advanced-nutrition/trends/\(petId)?days_back=\(period.days)",
            responseType: [NutritionalTrendResponse].self
        )
        
        return response.map { trend in
            MacronutrientTrend(
                date: trend.trendDate,
                protein: trend.totalProteinG,
                fat: trend.totalFatG,
                fiber: trend.totalFiberG
            )
        }.sorted { $0.date < $1.date }
    }
    
    /**
     * Load feeding patterns from server
     * - Parameters:
     *   - petId: The pet's ID
     *   - period: Analysis period
     * - Returns: Array of feeding patterns
     */
    private func loadFeedingPatterns(petId: String, period: TrendPeriod) async throws -> [FeedingPattern] {
        let response = try await apiService.get(
            endpoint: "/advanced-nutrition/trends/\(petId)?days_back=\(period.days)",
            responseType: [NutritionalTrendResponse].self
        )
        
        return response.map { trend in
            FeedingPattern(
                date: trend.trendDate,
                feedingCount: trend.feedingCount,
                compatibilityScore: trend.averageCompatibilityScore
            )
        }.sorted { $0.date < $1.date }
    }
    
    /**
     * Load weight correlation from server
     * - Parameters:
     *   - petId: The pet's ID
     *   - period: Analysis period
     * - Returns: Weight correlation data or nil
     */
    private func loadWeightCorrelation(petId: String, period: TrendPeriod) async throws -> WeightCorrelation? {
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
            return nil
        }
    }
    
    /**
     * Load insights from server
     * - Parameters:
     *   - petId: The pet's ID
     *   - period: Analysis period
     * - Returns: Array of insight strings
     */
    private func loadInsights(petId: String, period: TrendPeriod) async throws -> [String] {
        do {
            let response = try await apiService.get(
                endpoint: "/advanced-nutrition/trends/dashboard/\(petId)?days_back=\(period.days)",
                responseType: NutritionalTrendsDashboard.self
            )
            
            return response.insights
        } catch {
            return [
                "Start logging your pet's feeding to see personalized insights",
                "Regular feeding tracking helps identify nutritional patterns",
                "Monitor your pet's weight alongside feeding habits"
            ]
        }
    }
    
    /**
     * Calculate derived metrics from trend data
     * - Parameter petId: The pet's ID
     */
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
            totalWeightChanges[petId] = correlation.correlation * 2.0
        }
    }
}

// MARK: - Cache Data Model

/**
 * Trends Cache Data
 * Container for cached trends data
 */
struct TrendsCacheData: Codable {
    let calorieTrends: [CalorieTrend]
    let macronutrientTrends: [MacronutrientTrend]
    let feedingPatterns: [FeedingPattern]
    let weightCorrelation: WeightCorrelation?
    let insights: [String]
}

// Models imported from NutritionTrendsModels.swift

