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
    
    // In-memory caches for SwiftUI observation (synced with UnifiedCacheCoordinator)
    @Published private var calorieTrendsCache: [String: [CalorieTrend]] = [:]
    @Published private var macronutrientTrendsCache: [String: [MacronutrientTrend]] = [:]
    @Published private var feedingPatternsCache: [String: [FeedingPattern]] = [:]
    @Published private var weightCorrelationsCache: [String: WeightCorrelation] = [:]
    @Published private var insightsCache: [String: [String]] = [:]
    @Published private var averageDailyCaloriesCache: [String: Double] = [:]
    @Published private var averageFeedingFrequencyCache: [String: Double] = [:]
    @Published private var nutritionalBalanceScoresCache: [String: Double] = [:]
    @Published private var totalWeightChangesCache: [String: Double] = [:]
    
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var error: Error?
    
    // MARK: - Services
    
    private let apiService: APIService
    private var requirementsCreatedObserver: NSObjectProtocol?
    private let cacheCoordinator = UnifiedCacheCoordinator.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Current user ID for cache scoping
    private var currentUserId: String? {
        authService.currentUser?.id
    }
    
    // MARK: - Initialization
    
    private init() {
        self.apiService = APIService.shared
        loadCachedDataOnInit()
        observeAuthChanges()
        observeRequirementsCreated()
    }
    
    /**
     * Observe when nutritional requirements are created
     * This triggers a recalculation of derived metrics
     */
    private func observeRequirementsCreated() {
        requirementsCreatedObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NutritionalRequirementsCreated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let petId = notification.userInfo?["petId"] as? String else {
                return
            }
            print("🔄 [CachedNutritionalTrendsService] Requirements created for pet \(petId) - recalculating metrics")
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.calculateDerivedMetrics(for: petId)
                print("✅ [CachedNutritionalTrendsService] Metrics recalculated after requirements creation")
                print("   - Average Daily Calories: \(self.averageDailyCaloriesCache[petId] ?? 0)")
                print("   - Nutritional Balance: \(self.nutritionalBalanceScoresCache[petId] ?? 0)")
            }
        }
    }
    
    /**
     * Load cached data synchronously on init for immediate UI rendering
     */
    private func loadCachedDataOnInit() {
        guard currentUserId != nil else { return }
        
        // Load cached trends data from UnifiedCacheCoordinator synchronously
        // Note: Trends are complex objects, will be loaded on demand
        let pets = CachedPetService.shared.pets
        for pet in pets {
            _ = CacheKey.nutritionalTrends.scoped(forPetId: pet.id)
        }
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
            self.calorieTrendsCache[petId] = []
            self.macronutrientTrendsCache[petId] = []
            self.feedingPatternsCache[petId] = []
            self.weightCorrelationsCache.removeValue(forKey: petId)
            self.insightsCache[petId] = []
            self.objectWillChange.send()
            return
        }
        
        // Generate cache key based on pet and period
        let cacheKey = generateTrendsCacheKey(petId: petId, period: period, userId: userId)
        
        // Try cache first unless force refresh is requested
        if !forceRefresh {
            if let cachedData = cacheCoordinator.get(TrendsCacheData.self, forKey: cacheKey) {
                // Only use cache if it has meaningful data (at least one non-empty array)
                let hasData = !cachedData.calorieTrends.isEmpty || 
                             !cachedData.macronutrientTrends.isEmpty || 
                             !cachedData.feedingPatterns.isEmpty ||
                             cachedData.weightCorrelation != nil ||
                             !cachedData.insights.isEmpty
                
                if hasData {
                    // Update cache managers from cached data
                    self.calorieTrendsCache[petId] = cachedData.calorieTrends
                    self.macronutrientTrendsCache[petId] = cachedData.macronutrientTrends
                    self.feedingPatternsCache[petId] = cachedData.feedingPatterns
                    if let correlation = cachedData.weightCorrelation {
                        self.weightCorrelationsCache[petId] = correlation
                    }
                    self.insightsCache[petId] = cachedData.insights
                    self.objectWillChange.send()
                    
                    // Calculate derived metrics (async to allow requirements loading)
                    await calculateDerivedMetrics(for: petId)
                    
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
        return calorieTrendsCache[petId] ?? []
    }
    
    /**
     * Get macronutrient trends for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Array of macronutrient trend data
     */
    func macronutrientTrends(for petId: String) -> [MacronutrientTrend] {
        return macronutrientTrendsCache[petId] ?? []
    }
    
    /**
     * Get feeding patterns for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Array of feeding pattern data
     */
    func feedingPatterns(for petId: String) -> [FeedingPattern] {
        return feedingPatternsCache[petId] ?? []
    }
    
    /**
     * Get weight correlation for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Weight correlation data or nil
     */
    func weightCorrelation(for petId: String) -> WeightCorrelation? {
        return weightCorrelationsCache[petId]
    }
    
    /**
     * Get insights for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Array of insight strings
     */
    func insights(for petId: String) -> [String] {
        return insightsCache[petId] ?? []
    }
    
    /**
     * Get average daily calories for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Average daily calories
     */
    func averageDailyCalories(for petId: String) -> Double {
        return averageDailyCaloriesCache[petId] ?? 0.0
    }
    
    /**
     * Get average feeding frequency for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Average feeding frequency per day
     */
    func averageFeedingFrequency(for petId: String) -> Double {
        return averageFeedingFrequencyCache[petId] ?? 0.0
    }
    
    /**
     * Get nutritional balance score for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Nutritional balance score (0-100)
     */
    func nutritionalBalanceScore(for petId: String) -> Double {
        return nutritionalBalanceScoresCache[petId] ?? 0.0
    }
    
    /**
     * Get detailed nutritional breakdown for a pet
     * 
     * Provides comprehensive breakdown of protein, fat, and fiber intake
     * compared to recommendations, including color-coded status and contextual text.
     * 
     * - Parameter petId: The pet's ID
     * - Returns: NutritionalBreakdown with macro details, or nil if insufficient data
     * - Note: Requires at least 3 feeding records to generate meaningful breakdown
     */
    func getNutritionalBreakdown(for petId: String) -> NutritionalBreakdown? {
        let nutritionService = CachedNutritionService.shared
        let feedingRecords = nutritionService.feedingRecords.filter { $0.petId == petId }
        
        LoggingManager.debug("Breakdown - Pet: \(petId), Feeding records: \(feedingRecords.count)", category: .nutrition)
        
        // Get nutritional requirements first
        guard let requirements = nutritionService.nutritionalRequirements(for: petId),
              requirements.dailyCalories > 0 else {
            print("❌ [Breakdown] No nutritional requirements found for pet \(petId)")
            // Return breakdown with insufficient data flag
            return NutritionalBreakdown(
                overallScore: 0.0,
                protein: MacroNutrientData(
                    name: "Protein",
                    actual: 0,
                    recommended: 0,
                    percentage: 0,
                    status: .tooLow,
                    icon: "leaf.fill",
                    contextText: "Unable to load nutritional requirements"
                ),
                fat: MacroNutrientData(
                    name: "Fat",
                    actual: 0,
                    recommended: 0,
                    percentage: 0,
                    status: .tooLow,
                    icon: "bolt.fill",
                    contextText: "Unable to load nutritional requirements"
                ),
                fiber: MacroNutrientData(
                    name: "Fiber",
                    actual: 0,
                    recommended: 0,
                    percentage: 0,
                    status: .tooLow,
                    icon: "leaf",
                    contextText: "Unable to load nutritional requirements"
                ),
                hasInsufficientData: true
            )
        }
        
        print("✅ [Breakdown] Found requirements - Protein: \(requirements.proteinPercentage)%, Fat: \(requirements.fatPercentage)%, Fiber: \(requirements.fiberPercentage)%")
        
        // Check for insufficient data (minimum 1 feeding record - reduced from 3 for better UX)
        // Show partial data even with limited records to give users immediate feedback
        guard !feedingRecords.isEmpty else {
            LoggingManager.debug("No feeding records found for breakdown", category: .nutrition)
            return NutritionalBreakdown(
                overallScore: 0.0,
                protein: MacroNutrientData(
                    name: "Protein",
                    actual: 0,
                    recommended: requirements.proteinPercentage,
                    percentage: 0,
                    status: .tooLow,
                    icon: "leaf.fill",
                    contextText: "Start logging meals to track protein intake"
                ),
                fat: MacroNutrientData(
                    name: "Fat",
                    actual: 0,
                    recommended: requirements.fatPercentage,
                    percentage: 0,
                    status: .tooLow,
                    icon: "bolt.fill",
                    contextText: "Start logging meals to track fat intake"
                ),
                fiber: MacroNutrientData(
                    name: "Fiber",
                    actual: 0,
                    recommended: requirements.fiberPercentage,
                    percentage: 0,
                    status: .tooLow,
                    icon: "leaf",
                    contextText: "Start logging meals to track fiber intake"
                ),
                hasInsufficientData: true
            )
        }
        
        // Calculate actual macro percentages from feeding records
        var totalProteinG = 0.0
        var totalFatG = 0.0
        var totalFiberG = 0.0
        var totalWeightG = 0.0
        
        for record in feedingRecords {
            print("   🔍 [Breakdown] Record \(record.id): foodAnalysisId=\(record.foodAnalysisId), foodName=\(record.foodName ?? "nil")")
            
            // Get food analysis
            var analysis: FoodNutritionalAnalysis? = nutritionService.getFoodAnalysis(by: record.foodAnalysisId)
            
            print("   🔍 [Breakdown] Lookup by ID '\(record.foodAnalysisId)': \(analysis != nil ? "FOUND" : "NOT FOUND")")
            
            // Fallback: try to find by food name
            if analysis == nil, let foodName = record.foodName {
                analysis = nutritionService.foodAnalyses.first(where: {
                    $0.petId == petId &&
                    $0.foodName.localizedCaseInsensitiveContains(foodName)
                })
                print("   🔍 [Breakdown] Fallback lookup by name '\(foodName)': \(analysis != nil ? "FOUND (ID: \(analysis!.id))" : "NOT FOUND")")
            }
            
            guard let analysis = analysis else {
                print("⚠️ [Breakdown] No analysis found for record \(record.id), foodAnalysisId: \(record.foodAnalysisId), foodName: \(record.foodName ?? "none")")
                totalWeightG += record.amountGrams
                continue
            }
            
            print("✅ [Breakdown] Found analysis for record \(record.id): \(analysis.foodName)")
            print("   📊 [Breakdown] Macro %: Protein: \(analysis.proteinPercentage)%, Fat: \(analysis.fatPercentage)%, Fiber: \(analysis.fiberPercentage)%")
            print("   📊 [Breakdown] Amount: \(record.amountGrams)g")
            
            // Calculate macros for this feeding
            // Note: analysis stores percentages, convert to grams based on amount
            let proteinG = (analysis.proteinPercentage / 100.0) * record.amountGrams
            let fatG = (analysis.fatPercentage / 100.0) * record.amountGrams
            let fiberG = (analysis.fiberPercentage / 100.0) * record.amountGrams
            
            print("   📊 [Breakdown] Calculated grams: Protein: \(proteinG)g, Fat: \(fatG)g, Fiber: \(fiberG)g")
            
            totalProteinG += proteinG
            totalFatG += fatG
            totalFiberG += fiberG
            totalWeightG += record.amountGrams
        }
        
        print("📊 [Breakdown] Totals - Protein: \(totalProteinG)g, Fat: \(totalFatG)g, Fiber: \(totalFiberG)g, Weight: \(totalWeightG)g")
        
        // Calculate percentages (as percentage of total food weight)
        let actualProteinPercent = totalWeightG > 0 ? (totalProteinG / totalWeightG) * 100.0 : 0.0
        let actualFatPercent = totalWeightG > 0 ? (totalFatG / totalWeightG) * 100.0 : 0.0
        let actualFiberPercent = totalWeightG > 0 ? (totalFiberG / totalWeightG) * 100.0 : 0.0
        
        print("📊 [Breakdown] Actual %: Protein: \(actualProteinPercent)%, Fat: \(actualFatPercent)%, Fiber: \(actualFiberPercent)%")
        
        // Get recommended percentages
        let recommendedProtein = requirements.proteinPercentage
        let recommendedFat = requirements.fatPercentage
        let recommendedFiber = requirements.fiberPercentage
        
        // Calculate comparison percentages (actual/recommended * 100)
        let proteinComparison = recommendedProtein > 0 ? (actualProteinPercent / recommendedProtein) * 100.0 : 0.0
        let fatComparison = recommendedFat > 0 ? (actualFatPercent / recommendedFat) * 100.0 : 0.0
        let fiberComparison = recommendedFiber > 0 ? (actualFiberPercent / recommendedFiber) * 100.0 : 0.0
        
        // Calculate status for each macro
        let proteinStatus = calculateMacroStatus(percentage: proteinComparison)
        let fatStatus = calculateMacroStatus(percentage: fatComparison)
        let fiberStatus = calculateMacroStatus(percentage: fiberComparison)
        
        // Generate context text
        let proteinContext = generateContextText(macro: "Protein", status: proteinStatus, percentage: proteinComparison)
        let fatContext = generateContextText(macro: "Fat", status: fatStatus, percentage: fatComparison)
        let fiberContext = generateContextText(macro: "Fiber", status: fiberStatus, percentage: fiberComparison)
        
        // Calculate overall score (average of the three macro scores)
        let overallScore = (proteinComparison + fatComparison + fiberComparison) / 3.0
        let clampedScore = max(0.0, min(100.0, overallScore))
        
        return NutritionalBreakdown(
            overallScore: clampedScore,
            protein: MacroNutrientData(
                name: "Protein",
                actual: actualProteinPercent,
                recommended: recommendedProtein,
                percentage: proteinComparison,
                status: proteinStatus,
                icon: "leaf.fill",
                contextText: proteinContext
            ),
            fat: MacroNutrientData(
                name: "Fat",
                actual: actualFatPercent,
                recommended: recommendedFat,
                percentage: fatComparison,
                status: fatStatus,
                icon: "bolt.fill",
                contextText: fatContext
            ),
            fiber: MacroNutrientData(
                name: "Fiber",
                actual: actualFiberPercent,
                recommended: recommendedFiber,
                percentage: fiberComparison,
                status: fiberStatus,
                icon: "leaf",
                contextText: fiberContext
            ),
            hasInsufficientData: false
        )
    }
    
    /**
     * Calculate macro status based on comparison percentage
     * - Parameter percentage: Actual as percentage of recommended (e.g., 105 = 105% of recommended)
     * - Returns: Color-coded status
     */
    private func calculateMacroStatus(percentage: Double) -> MacroStatus {
        switch percentage {
        case 90...110:
            return .optimal
        case 80..<90:
            return .slightlyLow
        case 110..<120:
            return .slightlyHigh
        case ..<80:
            return .tooLow
        default: // >120
            return .tooHigh
        }
    }
    
    /**
     * Generate user-friendly context text for a macro status
     * - Parameters:
     *   - macro: Macronutrient name ("Protein", "Fat", "Fiber")
     *   - status: Current status
     *   - percentage: Comparison percentage
     * - Returns: Contextual explanation text
     */
    private func generateContextText(macro: String, status: MacroStatus, percentage: Double) -> String {
        let diff = abs(percentage - 100)
        
        switch status {
        case .optimal:
            return "\(macro) is optimal for your pet's health"
        case .slightlyLow:
            return "\(macro) is \(Int(diff))% below recommended"
        case .slightlyHigh:
            return "\(macro) is \(Int(diff))% above recommended"
        case .tooLow:
            return "\(macro) is significantly low - consider increasing intake"
        case .tooHigh:
            return "\(macro) is significantly high - consider reducing intake"
        }
    }
    
    /**
     * Get total weight change for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Total weight change in kg
     */
    func totalWeightChange(for petId: String) -> Double {
        return totalWeightChangesCache[petId] ?? 0.0
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
     * Call this when new feeding records or weight data is added
     * - Parameter petId: The pet's ID
     * - Parameter autoReload: If true, automatically reload trends after invalidation (default: false)
     */
    func invalidateTrendsCache(for petId: String, autoReload: Bool = false) {
        guard let userId = currentUserId else { return }
        
        // Invalidate all period caches for this pet
        for period in TrendPeriod.allCases {
            let cacheKey = generateTrendsCacheKey(petId: petId, period: period, userId: userId)
            cacheCoordinator.invalidate(forKey: cacheKey)
        }
        
        // Clear local data
        calorieTrendsCache.removeValue(forKey: petId)
        macronutrientTrendsCache.removeValue(forKey: petId)
        feedingPatternsCache.removeValue(forKey: petId)
        weightCorrelationsCache.removeValue(forKey: petId)
        insightsCache.removeValue(forKey: petId)
        averageDailyCaloriesCache.removeValue(forKey: petId)
        averageFeedingFrequencyCache.removeValue(forKey: petId)
        nutritionalBalanceScoresCache.removeValue(forKey: petId)
        totalWeightChangesCache.removeValue(forKey: petId)
        objectWillChange.send()
        
        // Auto-reload trends if requested
        if autoReload {
            Task {
                // Wait a brief moment for data to be saved
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                // Reload with default period (30 days)
                try? await loadTrendsData(for: petId, period: .thirtyDays, forceRefresh: true)
            }
        }
    }
    
    /**
     * Clear all cached trends data
     * Call this on logout
     */
    func clearCache() {
        calorieTrendsCache.removeAll()
        macronutrientTrendsCache.removeAll()
        feedingPatternsCache.removeAll()
        weightCorrelationsCache.removeAll()
        insightsCache.removeAll()
        averageDailyCaloriesCache.removeAll()
        averageFeedingFrequencyCache.removeAll()
        nutritionalBalanceScoresCache.removeAll()
        totalWeightChangesCache.removeAll()
        objectWillChange.send()
        error = nil
        isLoading = false
        isRefreshing = false
        
        // Clear user-specific cache
        if let userId = currentUserId {
            cacheCoordinator.clearUserCache(userId: userId)
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
            
            // Update cache managers
            self.calorieTrendsCache[petId] = calories
            self.macronutrientTrendsCache[petId] = macronutrients
            self.feedingPatternsCache[petId] = feeding
            if let correlation = correlation {
                self.weightCorrelationsCache[petId] = correlation
            }
            self.insightsCache[petId] = insights
            self.objectWillChange.send()
            
            // Ensure nutritional requirements and food analyses are loaded for balance calculation
            // These are needed for accurate nutritional balance calculation
            let nutritionService = CachedNutritionService.shared
            
            print("🔄 [loadTrendsFromServer] Loading requirements and food analyses for pet \(petId)")
            
            // Load requirements and food analyses in parallel (will use cache if available)
            // This ensures requirements are available for compatibility calculations
            // Requirements will be auto-created if they don't exist (returns zeros from server)
            let requirements = try? await nutritionService.getNutritionalRequirements(for: petId)
            try? await nutritionService.loadFoodAnalyses(for: petId)
            
            // Verify requirements are valid after loading
            if let req = requirements {
                print("📊 [loadTrendsFromServer] Requirements loaded: calories=\(req.dailyCalories), protein=\(req.proteinPercentage)")
                
                if req.dailyCalories == 0.0 && req.proteinPercentage == 0.0 {
                    print("⚠️ [loadTrendsFromServer] Requirements still zeros after load - checking cache")
                    // Check cache again - getNutritionalRequirements should have updated it
                    if let cachedReq = nutritionService.nutritionalRequirements(for: petId),
                       cachedReq.dailyCalories > 0 {
                        print("✅ [loadTrendsFromServer] Found valid requirements in cache after auto-creation")
                    } else {
                        print("⚠️ [loadTrendsFromServer] Requirements still zeros - will try to calculate in fallback")
                    }
                } else {
                    print("✅ [loadTrendsFromServer] Valid requirements loaded: calories=\(req.dailyCalories)")
                }
            } else {
                print("⚠️ [loadTrendsFromServer] Failed to load requirements - will try fallback calculation")
            }
            
            // Calculate derived metrics from loaded trends
            // This will use fallback calculation from raw data if trends are empty or have placeholder values
            // Requirements should now be in cache (either from server or auto-created)
            await calculateDerivedMetrics(for: petId)
            
            // Cache the data
            let cacheData = TrendsCacheData(
                calorieTrends: calories,
                macronutrientTrends: macronutrients,
                feedingPatterns: feeding,
                weightCorrelation: correlation,
                insights: insights
            )
            
            let cacheKey = generateTrendsCacheKey(petId: petId, period: period, userId: userId)
            cacheCoordinator.set(cacheData, forKey: cacheKey) // 5 minutes cache (handled by coordinator)
            
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
        if !cacheCoordinator.exists(forKey: cacheKey) {
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
            endpoint: "/advanced-nutrition/trends/\(petId)?days=\(period.days)",
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
            endpoint: "/advanced-nutrition/trends/\(petId)?days=\(period.days)",
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
            endpoint: "/advanced-nutrition/trends/\(petId)?days=\(period.days)",
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
                endpoint: "/advanced-nutrition/trends/dashboard/\(petId)?days=\(period.days)",
                responseType: NutritionalTrendsDashboard.self
            )
            
            guard let correlationDict = response.weightCorrelation else { return nil }
            
            // Extract values from dictionary with defaults
            let correlationValue = Double(correlationDict["correlation"] ?? "0") ?? 0.0
            let strengthValue = correlationDict["strength"] ?? "insufficient_data"
            let interpretationValue = correlationDict["interpretation"] ?? "Not enough data"
            
            return WeightCorrelation(
                correlation: correlationValue,
                strength: strengthValue,
                interpretation: interpretationValue
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
     * Note: This is async to allow loading requirements if they don't exist
     */
    @MainActor
    private func calculateDerivedMetrics(for petId: String) async {
        // Ensure food analyses are loaded before calculating
        let nutritionService = CachedNutritionService.shared
        do {
            try await nutritionService.loadFoodAnalyses(for: petId)
        } catch {
            LoggingManager.debug("Failed to load food analyses: \(error.localizedDescription)", category: .nutrition)
        }
        
        // Calculate average daily calories
        let calories = calorieTrends(for: petId)
        if !calories.isEmpty {
            let total = calories.reduce(0) { $0 + $1.calories }
            averageDailyCaloriesCache[petId] = total / Double(calories.count)
        } else {
            // If no trends data, try to calculate from feeding records directly
            // This ensures we show data even if trends haven't been generated yet
            let feedingRecords = nutritionService.feedingRecords.filter { $0.petId == petId }
            
            LoggingManager.debug("Calculating metrics from \(feedingRecords.count) feeding records", category: .nutrition)
            
            if !feedingRecords.isEmpty {
                // Collect unique food analysis IDs from feeding records
                let foodAnalysisIds = Set(feedingRecords.compactMap { $0.foodAnalysisId })
                
                // Load missing food analyses by their IDs
                for analysisId in foodAnalysisIds {
                    if nutritionService.getFoodAnalysis(by: analysisId) == nil {
                        do {
                            _ = try await nutritionService.loadFoodAnalysis(by: analysisId)
                        } catch {
                            LoggingManager.debug("Failed to load food analysis \(analysisId): \(error.localizedDescription)", category: .nutrition)
                        }
                    }
                }
                
                // Calculate average calories from feeding records
                var totalCalories: Double = 0
                var recordCount = 0
                
                for record in feedingRecords {
                    // Try to get calories from record first (if API provided it)
                    var recordCalories: Double? = nil
                    if record.calories > 0 {
                        recordCalories = record.calories
                    } else if let analysis = nutritionService.getFoodAnalysis(by: record.foodAnalysisId) {
                        // Fallback to calculating from food analysis
                        recordCalories = record.calculateCaloriesConsumed(from: analysis)
                    } else {
                        // Food analysis not found - try to find by food name as fallback
                        if let foodName = record.foodName {
                            // Try to find food analysis by name (case-insensitive match)
                            if let matchingAnalysis = nutritionService.foodAnalyses.first(where: { 
                                $0.petId == petId && 
                                $0.foodName.localizedCaseInsensitiveContains(foodName)
                            }) {
                                recordCalories = record.calculateCaloriesConsumed(from: matchingAnalysis)
                            }
                        }
                    }
                    
                    if let calories = recordCalories {
                        totalCalories += calories
                        recordCount += 1
                    }
                }
                
                if recordCount > 0 {
                    // Calculate average per day (group by date)
                    let calendar = Calendar.current
                    let groupedByDate = Dictionary(grouping: feedingRecords) { record in
                        calendar.startOfDay(for: record.feedingTime)
                    }
                    let daysCount = Double(groupedByDate.keys.count)
                    let avgCalories = daysCount > 0 ? totalCalories / daysCount : 0
                    averageDailyCaloriesCache[petId] = avgCalories
                    objectWillChange.send()
                } else {
                    // No records with valid food analysis - set to 0
                    averageDailyCaloriesCache[petId] = 0.0
                    objectWillChange.send()
                }
            } else {
                averageDailyCaloriesCache[petId] = 0.0
            }
        }
        
        // Calculate average feeding frequency
        let patterns = feedingPatterns(for: petId)
        if !patterns.isEmpty {
            let total = patterns.reduce(0) { $0 + $1.feedingCount }
            averageFeedingFrequencyCache[petId] = Double(total) / Double(patterns.count)
        } else {
            // Calculate from feeding records if no patterns
            let nutritionService = CachedNutritionService.shared
            let feedingRecords = nutritionService.feedingRecords.filter { $0.petId == petId }
            if !feedingRecords.isEmpty {
                let calendar = Calendar.current
                let groupedByDate = Dictionary(grouping: feedingRecords) { record in
                    calendar.startOfDay(for: record.feedingTime)
                }
                let daysCount = Double(groupedByDate.keys.count)
                let totalFeedings = Double(feedingRecords.count)
                averageFeedingFrequencyCache[petId] = daysCount > 0 ? totalFeedings / daysCount : 0
            } else {
                averageFeedingFrequencyCache[petId] = 0.0
            }
        }
        
        // Calculate nutritional balance score
        // Check if patterns have valid compatibility scores (not placeholder values)
        let patternsWithValidScores = patterns.filter { $0.compatibilityScore > 0 && $0.compatibilityScore != 70.0 }
        
        if !patternsWithValidScores.isEmpty {
            // Use patterns data if we have valid scores
            let total = patternsWithValidScores.reduce(0) { $0 + $1.compatibilityScore }
            nutritionalBalanceScoresCache[petId] = total / Double(patternsWithValidScores.count)
        } else {
            // If no valid patterns data, calculate from feeding records directly
            // This ensures we show accurate data even if database has placeholder values
            let nutritionService = CachedNutritionService.shared
            let feedingRecords = nutritionService.feedingRecords.filter { $0.petId == petId }
            
            if !feedingRecords.isEmpty {
                LoggingManager.debug("Calculating nutritional balance with \(feedingRecords.count) records", category: .nutrition)
                
                // Get nutritional requirements for compatibility assessment
                // First check cache, then try to load if missing
                var requirements = nutritionService.nutritionalRequirements(for: petId)
                
                // If no requirements in cache OR requirements are zeros, load them (this will auto-create if missing)
                if requirements == nil || (requirements?.dailyCalories == 0.0 && requirements?.proteinPercentage == 0.0) {
                    // Try to load/create requirements synchronously in this async context
                    // This is called from loadTrendsFromServer which is already async
                    do {
                        requirements = try await nutritionService.getNutritionalRequirements(for: petId)
                        
                        // If still zeros after loading, check cache again (auto-creation might have just completed)
                        if requirements?.dailyCalories == 0.0 && requirements?.proteinPercentage == 0.0 {
                            // Small delay to allow auto-creation to complete
                            try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
                            requirements = nutritionService.nutritionalRequirements(for: petId)
                        }
                    } catch {
                        nutritionalBalanceScoresCache[petId] = 0.0
                        return
                    }
                }
                
                // We should now have valid requirements - calculate compatibility scores
                if let req = requirements, req.dailyCalories > 0 {
                    var compatibilityScores: [Double] = []
                    
                    for record in feedingRecords {
                        // Try to get food analysis to calculate compatibility
                        var analysis: FoodNutritionalAnalysis? = nutritionService.getFoodAnalysis(by: record.foodAnalysisId)
                        
                        // Fallback: try to find by food name if ID lookup fails
                        if analysis == nil, let foodName = record.foodName {
                            analysis = nutritionService.foodAnalyses.first(where: { 
                                $0.petId == petId && 
                                $0.foodName.localizedCaseInsensitiveContains(foodName)
                            })
                        }
                        
                        if let analysis = analysis {
                            let compatibility = analysis.assessCompatibility(with: req)
                            compatibilityScores.append(compatibility.score)
                        }
                    }
                    
                    if !compatibilityScores.isEmpty {
                        // Calculate average compatibility score
                        let total = compatibilityScores.reduce(0, +)
                        let average = total / Double(compatibilityScores.count)
                        nutritionalBalanceScoresCache[petId] = average
                        objectWillChange.send()
                    } else {
                        nutritionalBalanceScoresCache[petId] = 0.0
                        objectWillChange.send()
                    }
                } else {
                    nutritionalBalanceScoresCache[petId] = 0.0
                }
            } else {
                LoggingManager.debug("No feeding records for pet \(petId)", category: .nutrition)
                nutritionalBalanceScoresCache[petId] = 0.0
            }
        }
        
        // Calculate total weight change
        if let correlation = weightCorrelationsCache[petId] {
            totalWeightChangesCache[petId] = correlation.correlation * 2.0
        } else {
            // Try to calculate from weight records if no correlation data
            let weightService = CachedWeightTrackingService.shared
            let weightHistory = weightService.weightHistory(for: petId)
            if weightHistory.count >= 2 {
                let sortedHistory = weightHistory.sorted { $0.recordedAt < $1.recordedAt }
                let firstWeight = sortedHistory.first!.weightKg
                let lastWeight = sortedHistory.last!.weightKg
                totalWeightChangesCache[petId] = lastWeight - firstWeight
            } else {
                totalWeightChangesCache[petId] = 0.0
            }
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

