//
//  PetDataAggregator.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation

/**
 * Pet Data Aggregator Service
 * 
 * Aggregates all relevant pet data for PDF export including:
 * - Pet profile information
 * - Nutritional requirements and history
 * - Scan history with safety assessments
 * - Feeding records
 * 
 * Follows SOLID principles with single responsibility for data aggregation
 * Implements DRY by reusing existing service methods
 * Follows KISS by keeping aggregation logic simple and focused
 */
@MainActor
class PetDataAggregator {
    static let shared = PetDataAggregator()
    
    private let nutritionService = CachedNutritionService.shared
    private let scanService = CachedScanService.shared
    private let healthEventService = HealthEventService.shared
    private let apiService = APIService.shared
    
    private init() {}
    
    /**
     * Aggregate complete pet data for PDF export
     * - Parameter pet: The pet to aggregate data for
     * - Returns: Complete pet data structure for PDF generation
     */
    func aggregatePetData(for pet: Pet) async throws -> VetReportData {
        // Calculate nutritional requirements
        let nutritionalRequirements = PetNutritionalRequirements.calculate(for: pet)
        
        // Load feeding records (last 30 days)
        let feedingRecords = try await loadFeedingRecords(for: pet.id, days: 30)
        
        // Load food analyses for foods that were actually fed
        let fedFoodAnalyses = try await loadFedFoodAnalyses(for: pet.id, feedingRecords: feedingRecords)
        
        // Load scan history filtered to only show scans for foods that were fed
        let scanHistory = await loadScanHistoryForFedFoods(for: pet.id, days: 30, fedFoodAnalyses: fedFoodAnalyses)
        
        // Load daily nutrition summaries (last 30 days)
        let dailySummaries = try await loadDailySummaries(for: pet.id, days: 30)
        
        // Load health events (last 30 days)
        let healthEvents = try await loadHealthEvents(for: pet.id, days: 30)
        
        return VetReportData(
            pet: pet,
            nutritionalRequirements: nutritionalRequirements,
            feedingRecords: feedingRecords,
            fedFoodAnalyses: fedFoodAnalyses,
            scanHistory: scanHistory,
            dailySummaries: dailySummaries,
            healthEvents: healthEvents,
            generatedAt: Date()
        )
    }
    
    /**
     * Load feeding records for a pet
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to load
     * - Returns: Array of feeding records
     */
    private func loadFeedingRecords(for petId: String, days: Int) async throws -> [FeedingRecord] {
        do {
            try await nutritionService.loadFeedingRecords(for: petId, days: days)
            return nutritionService.feedingRecords.filter { $0.petId == petId }
        } catch {
            print("Failed to load feeding records: \(error)")
            // Return empty array instead of throwing to allow PDF generation with partial data
            return []
        }
    }
    
    /**
     * Load food analyses for foods that were actually fed to the pet
     * - Parameter petId: The pet's ID
     * - Parameter feedingRecords: Array of feeding records
     * - Returns: Array of food analyses for fed foods
     */
    private func loadFedFoodAnalyses(for petId: String, feedingRecords: [FeedingRecord]) async throws -> [FoodNutritionalAnalysis] {
        // Get unique food analysis IDs from feeding records
        let foodAnalysisIds = Set(feedingRecords.map { $0.foodAnalysisId })
        
        if foodAnalysisIds.isEmpty {
            return []
        }
        
        do {
            // Load food analyses
            try await nutritionService.loadFoodAnalyses(for: petId)
            
            // Filter to only include analyses that were fed
            return nutritionService.foodAnalyses.filter { analysis in
                foodAnalysisIds.contains(analysis.id)
            }
        } catch {
            print("Failed to load food analyses: \(error)")
            return []
        }
    }
    
    /**
     * Load scan history filtered to only show scans for foods that were actually fed
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to load
     * - Parameter fedFoodAnalyses: Array of food analyses for foods that were fed
     * - Returns: Array of scans for fed foods only
     */
    private func loadScanHistoryForFedFoods(for petId: String, days: Int, fedFoodAnalyses: [FoodNutritionalAnalysis]) async -> [Scan] {
        // Load scans for the pet
        let allScans = await scanService.getScansForPetWithFallback(petId: petId)
        
        // Filter by date (last N days)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentScans = allScans.filter { scan in
            scan.createdAt >= cutoffDate
        }
        
        // Get set of food names that were actually fed (case-insensitive matching)
        let fedFoodNames = Set(fedFoodAnalyses.map { $0.foodName.lowercased().trimmingCharacters(in: .whitespaces) })
        
        // Filter scans to only include those matching fed foods
        // Match by product name from scan result
        let filteredScans = recentScans.filter { scan in
            guard let productName = scan.result?.productName else { return false }
            let normalizedName = productName.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Check if scan product name matches any fed food name
            return fedFoodNames.contains(normalizedName) || 
                   fedFoodNames.contains { fedName in
                       normalizedName.contains(fedName) || fedName.contains(normalizedName)
                   }
        }
        
        return filteredScans.sorted { $0.createdAt > $1.createdAt }
    }
    
    /**
     * Load daily nutrition summaries for a pet
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to load
     * - Returns: Array of daily nutrition summaries
     */
    private func loadDailySummaries(for petId: String, days: Int) async throws -> [DailyNutritionSummary] {
        do {
            try await nutritionService.loadDailySummaries(for: petId, days: days)
            return nutritionService.dailySummaries[petId] ?? []
        } catch {
            print("Failed to load daily summaries: \(error)")
            // Return empty array instead of throwing to allow PDF generation with partial data
            return []
        }
    }
    
    /**
     * Load health events for a pet
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to load
     * - Returns: Array of health events
     */
    private func loadHealthEvents(for petId: String, days: Int) async throws -> [HealthEvent] {
        do {
            let events = try await healthEventService.getHealthEvents(for: petId, limit: 100)
            
            // Filter by date (last N days)
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            return events.filter { event in
                event.eventDate >= cutoffDate
            }.sorted { $0.eventDate > $1.eventDate }
        } catch {
            print("Failed to load health events: \(error)")
            // Return empty array instead of throwing to allow PDF generation with partial data
            return []
        }
    }
}

/**
 * Complete pet data structure for veterinary report
 */
struct VetReportData {
    let pet: Pet
    let nutritionalRequirements: PetNutritionalRequirements
    let feedingRecords: [FeedingRecord]
    let fedFoodAnalyses: [FoodNutritionalAnalysis] // Food analyses for foods that were fed
    let scanHistory: [Scan]
    let dailySummaries: [DailyNutritionSummary]
    let healthEvents: [HealthEvent]
    let generatedAt: Date
}

