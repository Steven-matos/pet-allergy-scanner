//
//  FeedingLogService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import Combine
import SwiftUI

/**
 * Feeding Log Service
 * 
 * Handles feeding log data operations including:
 * - Recording feeding instances
 * - Fetching feeding history
 * - Calculating daily summaries
 * - Syncing with backend API
 * 
 * Follows SOLID principles with single responsibility for feeding data
 * Implements DRY by reusing common API patterns
 * Follows KISS by keeping the API simple and focused
 */
@MainActor
class FeedingLogService: ObservableObject {
    static let shared = FeedingLogService()
    
    @Published var recentFeedingRecords: [FeedingRecord] = []
    @Published var dailySummaries: [String: DailyNutritionSummary] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService: APIService
    private let cachedNutritionService = CachedNutritionService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.apiService = APIService.shared
    }
    
    // MARK: - Public API
    
    /**
     * Log a feeding record for a pet using cached service
     * - Parameter feedingRecord: The feeding record to log
     */
    func logFeeding(_ feedingRecord: FeedingRecordRequest) async throws {
        isLoading = true
        error = nil
        
        do {
            // Use cached nutrition service for better performance
            let response = try await cachedNutritionService.recordFeeding(feedingRecord)
            
            // Add to local cache
            recentFeedingRecords.insert(response, at: 0)
            
            // Invalidate trends cache so trends update with new feeding data
            let trendsService = CachedNutritionalTrendsService.shared
            trendsService.invalidateTrendsCache(for: feedingRecord.petId)
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Get feeding records for a pet using cached service
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to fetch (default: 30)
     */
    func getFeedingRecords(for petId: String, days: Int = 30) async throws -> [FeedingRecord] {
        isLoading = true
        error = nil
        
        do {
            // Use cached nutrition service for better performance
            try await cachedNutritionService.loadFeedingRecords(for: petId, days: days)
            recentFeedingRecords = cachedNutritionService.feedingRecords
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
        return recentFeedingRecords
    }
    
    /**
     * Get daily nutrition summary for a pet using cached service
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to get summary for
     */
    func getDailySummary(for petId: String, date: Date) async throws -> DailyNutritionSummary? {
        // Try cached service first
        if let cachedSummary = cachedNutritionService.getDailySummary(for: petId, on: date) {
            dailySummaries[petId] = cachedSummary
            return cachedSummary
        }
        
        // Fallback to server if not in cache
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: date)
        
        do {
            let response = try await apiService.get(
                endpoint: "/nutrition/daily-summary/\(petId)?date=\(dateString)",
                responseType: DailyNutritionSummary.self
            )
            
            dailySummaries[petId] = response
            return response
            
        } catch {
            // If no summary exists (404 or other not found error), return nil
            // Otherwise, re-throw the error
            if case APIError.serverError(404) = error {
                return nil
            }
            throw error
        }
    }
    
    /**
     * Get feeding records for a specific date
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to get records for
     */
    func getFeedingRecordsForDate(for petId: String, date: Date) -> [FeedingRecord] {
        let calendar = Calendar.current
        return recentFeedingRecords.filter { record in
            calendar.isDate(record.feedingTime, inSameDayAs: date) && record.petId == petId
        }
    }
    
    /**
     * Calculate total calories for a pet on a specific date
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to calculate for
     */
    func calculateDailyCalories(for petId: String, date: Date) async -> Double {
        let records = getFeedingRecordsForDate(for: petId, date: date)
        
        var totalCalories: Double = 0
        
        for record in records {
            do {
                // Get food analysis for this record
                let foodAnalysis = try await getFoodAnalysis(for: record.foodAnalysisId)
                let calories = record.calculateCaloriesConsumed(from: foodAnalysis)
                totalCalories += calories
            } catch {
                // Log error but continue with other records
                print("Error calculating calories for record \(record.id): \(error)")
            }
        }
        
        return totalCalories
    }
    
    /**
     * Delete a feeding record
     * - Parameter recordId: The ID of the record to delete
     */
    func deleteFeedingRecord(_ recordId: String) async throws {
        isLoading = true
        error = nil
        
        do {
            // Get the record before deleting to get petId for cache invalidation
            guard let record = recentFeedingRecords.first(where: { $0.id == recordId }) else {
                throw NSError(domain: "FeedingLogService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Feeding record not found"])
            }
            
            let petId = record.petId
            
            try await apiService.delete(endpoint: "/nutrition/feeding/\(recordId)")
            
            // Remove from local cache
            recentFeedingRecords.removeAll { $0.id == recordId }
            
            // Also remove from cached nutrition service
            cachedNutritionService.feedingRecords.removeAll { $0.id == recordId }
            
            // Invalidate trends cache so trends update after deletion
            let trendsService = CachedNutritionalTrendsService.shared
            trendsService.invalidateTrendsCache(for: petId)
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Update a feeding record
     * - Parameter record: The updated feeding record
     */
    func updateFeedingRecord(_ record: FeedingRecord) async throws {
        isLoading = true
        error = nil
        
        do {
            let request = FeedingRecordRequest(
                petId: record.petId,
                foodAnalysisId: record.foodAnalysisId,
                amountGrams: record.amountGrams,
                feedingTime: record.feedingTime,
                notes: record.notes
            )
            
            let response = try await apiService.put(
                endpoint: "/nutrition/feeding/\(record.id)",
                body: request,
                responseType: FeedingRecord.self
            )
            
            // Update local cache
            if let index = recentFeedingRecords.firstIndex(where: { $0.id == record.id }) {
                recentFeedingRecords[index] = response
            }
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    /**
     * Update daily summary for a pet and date
     * - Parameter petId: The pet's ID
     * - Parameter date: The date to update
     */
    private func updateDailySummary(for petId: String, date: Date) async {
        do {
            let summary = try await getDailySummary(for: petId, date: date)
            dailySummaries[petId] = summary
        } catch {
            // Summary might not exist yet, which is fine
            print("Could not update daily summary: \(error)")
        }
    }
    
    /**
     * Get food analysis by ID
     * - Parameter foodAnalysisId: The food analysis ID
     */
    private func getFoodAnalysis(for foodAnalysisId: String) async throws -> FoodNutritionalAnalysis {
        return try await apiService.get(
            endpoint: "/nutrition/food-analysis/\(foodAnalysisId)",
            responseType: FoodNutritionalAnalysis.self
        )
    }
}

// MARK: - Extensions

extension FeedingLogService {
    /**
     * Get feeding frequency for a pet over a period
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to analyze
     */
    func getFeedingFrequency(for petId: String, days: Int = 7) -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        let relevantRecords = recentFeedingRecords.filter { record in
            record.petId == petId &&
            record.feedingTime >= startDate &&
            record.feedingTime <= endDate
        }
        
        return Double(relevantRecords.count) / Double(days)
    }
    
    /**
     * Get average feeding amount for a pet
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to analyze
     */
    func getAverageFeedingAmount(for petId: String, days: Int = 7) -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        let relevantRecords = recentFeedingRecords.filter { record in
            record.petId == petId &&
            record.feedingTime >= startDate &&
            record.feedingTime <= endDate
        }
        
        guard !relevantRecords.isEmpty else { return 0 }
        
        let totalAmount = relevantRecords.reduce(0) { $0 + $1.amountGrams }
        return totalAmount / Double(relevantRecords.count)
    }
    
    /**
     * Get feeding consistency score (0-100)
     * - Parameter petId: The pet's ID
     * - Parameter days: Number of days to analyze
     */
    func getFeedingConsistencyScore(for petId: String, days: Int = 7) -> Double {
        let feedingFrequency = getFeedingFrequency(for: petId, days: days)
        
        // Ideal frequency is 2-3 times per day
        let idealFrequency = 2.5
        let deviation = abs(feedingFrequency - idealFrequency)
        
        // Score decreases as deviation increases
        let score = max(0, 100 - (deviation * 20))
        return min(100, score)
    }
}
