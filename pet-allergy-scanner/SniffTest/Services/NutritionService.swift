//
//  NutritionService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/**
 * Nutrition Service
 * 
 * Handles all nutrition-related operations including:
 * - Nutritional requirement calculations
 * - Food analysis and compatibility assessment
 * - Feeding record management
 * - Nutrition history tracking
 * 
 * Follows SOLID principles with single responsibility for nutrition operations
 */
@MainActor
class NutritionService: ObservableObject {
    static let shared = NutritionService()
    
    @Published var nutritionalRequirements: [String: PetNutritionalRequirements] = [:]
    @Published var foodAnalyses: [FoodNutritionalAnalysis] = []
    @Published var feedingRecords: [FeedingRecord] = []
    @Published var dailySummaries: [String: [DailyNutritionSummary]] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.apiService = APIService.shared
    }
    
    // MARK: - Nutritional Requirements
    
    /**
     * Calculate nutritional requirements for a pet
     * - Parameter pet: The pet to calculate requirements for
     * - Returns: Calculated nutritional requirements
     */
    func calculateNutritionalRequirements(for pet: Pet) async throws -> PetNutritionalRequirements {
        let requirements = PetNutritionalRequirements.calculate(for: pet)
        nutritionalRequirements[pet.id] = requirements
        
        // Save to server
        try await saveNutritionalRequirements(requirements)
        
        return requirements
    }
    
    /**
     * Get cached nutritional requirements for a pet
     * - Parameter petId: The pet's ID
     * - Returns: Cached requirements if available
     */
    func getNutritionalRequirements(for petId: String) -> PetNutritionalRequirements? {
        return nutritionalRequirements[petId]
    }
    
    /**
     * Load nutritional requirements from server
     * - Parameter petId: The pet's ID
     */
    func loadNutritionalRequirements(for petId: String) async throws {
        do {
            let requirements: PetNutritionalRequirements = try await apiService.get(
                endpoint: "/nutrition/requirements/\(petId)",
                responseType: PetNutritionalRequirements.self
            )
            nutritionalRequirements[petId] = requirements
        } catch {
            print("Failed to load nutritional requirements: \(error)")
            throw error
        }
    }
    
    /**
     * Save nutritional requirements to server
     * - Parameter requirements: The requirements to save
     */
    private func saveNutritionalRequirements(_ requirements: PetNutritionalRequirements) async throws {
        do {
            let _: EmptyResponse = try await apiService.post(
                endpoint: "/nutrition/requirements",
                body: requirements,
                responseType: EmptyResponse.self
            )
        } catch {
            print("Failed to save nutritional requirements: \(error)")
            throw error
        }
    }
    
    // MARK: - Food Analysis
    
    /**
     * Analyze food nutritional content
     * - Parameter request: The analysis request
     * - Returns: Food nutritional analysis
     */
    func analyzeFood(_ request: NutritionAnalysisRequest) async throws -> FoodNutritionalAnalysis {
        isLoading = true
        error = nil
        
        do {
            let analysis: FoodNutritionalAnalysis = try await apiService.post(
                endpoint: "/nutrition/analyze",
                body: request,
                responseType: FoodNutritionalAnalysis.self
            )
            
            foodAnalyses.append(analysis)
            
            // Check compatibility with pet's requirements
            if let requirements = nutritionalRequirements[request.petId] {
                let compatibility = analysis.assessCompatibility(with: requirements)
                print("Food compatibility: \(compatibility.compatibility.rawValue) (\(compatibility.score))")
            }
            
            isLoading = false
            return analysis
            
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    /**
     * Get food analysis by ID
     * - Parameter analysisId: The analysis ID
     * - Returns: Food analysis if found
     */
    func getFoodAnalysis(by analysisId: String) -> FoodNutritionalAnalysis? {
        return foodAnalyses.first { $0.id == analysisId }
    }
    
    /**
     * Load food analyses for a pet
     * - Parameter petId: The pet's ID
     */
    func loadFoodAnalyses(for petId: String) async throws {
        do {
            let analyses: [FoodNutritionalAnalysis] = try await apiService.get(
                endpoint: "/nutrition/analyses/\(petId)",
                responseType: [FoodNutritionalAnalysis].self
            )
            
            // Update local cache
            for analysis in analyses {
                if !foodAnalyses.contains(where: { $0.id == analysis.id }) {
                    foodAnalyses.append(analysis)
                }
            }
        } catch {
            print("Failed to load food analyses: \(error)")
            throw error
        }
    }
    
    // MARK: - Feeding Records
    
    /**
     * Record a feeding instance
     * - Parameter request: The feeding record request
     * - Returns: Created feeding record
     */
    func recordFeeding(_ request: FeedingRecordRequest) async throws -> FeedingRecord {
        do {
            let record: FeedingRecord = try await apiService.post(
                endpoint: "/nutrition/feeding",
                body: request,
                responseType: FeedingRecord.self
            )
            
            feedingRecords.append(record)
            
            // Update daily summary
            await updateDailySummary(for: request.petId, date: request.feedingTime)
            
            return record
            
        } catch {
            print("Failed to record feeding: \(error)")
            throw error
        }
    }
    
    /**
     * Load feeding records for a pet
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to load (default: 30)
     */
    func loadFeedingRecords(for petId: String, days: Int = 30) async throws {
        do {
            let records: [FeedingRecord] = try await apiService.get(
                endpoint: "/nutrition/feeding/\(petId)?days=\(days)",
                responseType: [FeedingRecord].self
            )
            
            // Update local cache
            for record in records {
                if !feedingRecords.contains(where: { $0.id == record.id }) {
                    feedingRecords.append(record)
                }
            }
            
        } catch {
            print("Failed to load feeding records: \(error)")
            throw error
        }
    }
    
    /**
     * Get feeding records for a specific date
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to get records for
     * - Returns: Feeding records for the date
     */
    func getFeedingRecords(for petId: String, on date: Date) -> [FeedingRecord] {
        let calendar = Calendar.current
        return feedingRecords.filter { record in
            record.petId == petId && calendar.isDate(record.feedingTime, inSameDayAs: date)
        }
    }
    
    // MARK: - Daily Summaries
    
    /**
     * Update daily nutrition summary for a pet
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to update
     */
    private func updateDailySummary(for petId: String, date: Date) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let dayRecords = getFeedingRecords(for: petId, on: date)
        
        var totalCalories = 0.0
        var totalProtein = 0.0
        var totalFat = 0.0
        var totalFiber = 0.0
        var compatibilityScores: [Double] = []
        var recommendations: [String] = []
        
        for record in dayRecords {
            if let analysis = getFoodAnalysis(by: record.foodAnalysisId) {
                totalCalories += record.calculateCaloriesConsumed(from: analysis)
                totalProtein += (analysis.proteinPercentage / 100.0) * record.amountGrams
                totalFat += (analysis.fatPercentage / 100.0) * record.amountGrams
                totalFiber += (analysis.fiberPercentage / 100.0) * record.amountGrams
                
                if let requirements = nutritionalRequirements[petId] {
                    let compatibility = analysis.assessCompatibility(with: requirements)
                    compatibilityScores.append(compatibility.score)
                    recommendations.append(contentsOf: compatibility.recommendations)
                }
            }
        }
        
        let averageCompatibility = compatibilityScores.isEmpty ? 0.0 : compatibilityScores.reduce(0, +) / Double(compatibilityScores.count)
        
        let summary = DailyNutritionSummary(
            petId: petId,
            date: startOfDay,
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalFat: totalFat,
            totalFiber: totalFiber,
            feedingCount: dayRecords.count,
            averageCompatibility: averageCompatibility,
            recommendations: Array(Set(recommendations)) // Remove duplicates
        )
        
        if dailySummaries[petId] == nil {
            dailySummaries[petId] = []
        }
        
        // Remove existing summary for this date
        dailySummaries[petId]?.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
        
        // Add new summary
        dailySummaries[petId]?.append(summary)
        
        // Sort by date
        dailySummaries[petId]?.sort { $0.date > $1.date }
    }
    
    /**
     * Get daily summary for a specific date
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to get summary for
     * - Returns: Daily summary if available
     */
    func getDailySummary(for petId: String, on date: Date) -> DailyNutritionSummary? {
        let calendar = Calendar.current
        return dailySummaries[petId]?.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    /**
     * Load daily summaries for a pet
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to load (default: 30)
     */
    func loadDailySummaries(for petId: String, days: Int = 30) async throws {
        do {
            let summaries: [DailyNutritionSummary] = try await apiService.get(
                endpoint: "/nutrition/summaries/\(petId)?days=\(days)",
                responseType: [DailyNutritionSummary].self
            )
            
            dailySummaries[petId] = summaries
            
        } catch {
            print("Failed to load daily summaries: \(error)")
            throw error
        }
    }
    
    // MARK: - Premium Features
    
    /**
     * Check if user can access multiple pet nutrition features
     * - Parameter user: The user account
     * - Returns: Whether premium features are available
     */
    func canAccessMultiplePetFeatures(user: User) -> Bool {
        return user.role == .premium
    }
    
    /**
     * Get nutrition insights for multiple pets
     * - Parameter pets: Array of pets to analyze
     * - Returns: Comparative nutrition insights
     */
    func getMultiPetInsights(for pets: [Pet]) async throws -> MultiPetNutritionInsights {
        guard !pets.isEmpty else {
            throw NutritionError.noPetsProvided
        }
        
        var insights = MultiPetNutritionInsights(pets: pets, generatedAt: Date())
        
        for pet in pets {
            if let requirements = nutritionalRequirements[pet.id] {
                insights.requirements[pet.id] = requirements
            }
            
            if let summaries = dailySummaries[pet.id] {
                insights.recentSummaries[pet.id] = Array(summaries.prefix(7)) // Last 7 days
            }
        }
        
        // Generate comparative insights
        insights.comparativeInsights = generateComparativeInsights(insights)
        
        return insights
    }
    
    /**
     * Generate comparative insights across multiple pets
     * - Parameter insights: The multi-pet insights object
     * - Returns: Array of comparative insights
     */
    private func generateComparativeInsights(_ insights: MultiPetNutritionInsights) -> [ComparativeInsight] {
        var comparativeInsights: [ComparativeInsight] = []
        
        // Compare calorie requirements
        let calorieRequirements = insights.requirements.values.map { $0.dailyCalories }
        if let maxCalories = calorieRequirements.max(),
           let minCalories = calorieRequirements.min(),
           maxCalories > minCalories * 1.5 {
            comparativeInsights.append(ComparativeInsight(
                type: .calorieRange,
                title: "Calorie Requirements Vary Significantly",
                description: "Your pets have very different calorie needs. Consider feeding schedules accordingly.",
                severity: .medium
            ))
        }
        
        // Compare recent nutrition trends
        let recentSummaries = insights.recentSummaries.values.flatMap { $0 }
        let averageCompatibility = recentSummaries.map { $0.averageCompatibility }.reduce(0, +) / Double(max(recentSummaries.count, 1))
        
        if averageCompatibility < 70 {
            comparativeInsights.append(ComparativeInsight(
                type: .nutritionQuality,
                title: "Nutrition Quality Could Improve",
                description: "Consider reviewing your pets' current food choices for better nutritional balance.",
                severity: .high
            ))
        }
        
        return comparativeInsights
    }
    
    // MARK: - Data Management
    
    /**
     * Clear all cached data
     */
    func clearCache() {
        nutritionalRequirements.removeAll()
        foodAnalyses.removeAll()
        feedingRecords.removeAll()
        dailySummaries.removeAll()
    }
    
    /**
     * Refresh all data for a pet
     * - Parameter petId: The pet's ID
     */
    func refreshPetData(petId: String) async throws {
        try await loadNutritionalRequirements(for: petId)
        try await loadFoodAnalyses(for: petId)
        try await loadFeedingRecords(for: petId)
        try await loadDailySummaries(for: petId)
    }
}

// MARK: - Supporting Models

/**
 * Multi-Pet Nutrition Insights
 * Comprehensive analysis across multiple pets
 */
struct MultiPetNutritionInsights {
    let pets: [Pet]
    let generatedAt: Date
    var requirements: [String: PetNutritionalRequirements] = [:]
    var recentSummaries: [String: [DailyNutritionSummary]] = [:]
    var comparativeInsights: [ComparativeInsight] = []
}

/**
 * Comparative Insight
 * Insight comparing nutrition across multiple pets
 */
struct ComparativeInsight {
    let type: InsightType
    let title: String
    let description: String
    let severity: InsightSeverity
}

/**
 * Insight Types
 */
enum InsightType {
    case calorieRange
    case nutritionQuality
    case feedingSchedule
    case allergenRisk
}

/**
 * Insight Severity
 */
enum InsightSeverity {
    case low
    case medium
    case high
    case critical
}

/**
 * Nutrition Errors
 */
enum NutritionError: LocalizedError {
    case noPetsProvided
    case invalidPetData
    case analysisFailed
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .noPetsProvided:
            return "No pets provided for analysis"
        case .invalidPetData:
            return "Invalid pet data provided"
        case .analysisFailed:
            return "Food analysis failed"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
