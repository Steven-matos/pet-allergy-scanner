//
//  VisitSummaryService.swift
//  SniffTest
//
//  Created for Gap #2: Vet-Readable Packaging
//  Client-side data aggregation for visit summaries
//

import Foundation
import Combine

/**
 * VisitSummaryService - Client-Side Data Aggregation
 *
 * Aggregates pet health data into a compressed, vet-readable format.
 * Pure client-side composition - no new backend logic required.
 *
 * Design Principle: "If a vet had 10 minutes with this app, would it make the visit clearer?"
 *
 * Follows SOLID principles:
 * - Single Responsibility: Only handles visit summary generation
 * - Dependency Inversion: Uses service protocols for data access
 */
@MainActor
final class VisitSummaryService: ObservableObject {
    static let shared = VisitSummaryService()
    
    // MARK: - Dependencies
    
    private let nutritionService = CachedNutritionService.shared
    private let feedingLogService = FeedingLogService.shared
    private let healthEventService = HealthEventService.shared
    private let medicationService = MedicationReminderService.shared
    
    // MARK: - Published State
    
    @Published private(set) var isLoading = false
    @Published private(set) var currentSummary: VisitSummary?
    @Published private(set) var errorMessage: String?
    
    private init() {}
    
    // MARK: - Public API
    
    /**
     * Generate a visit summary for a pet
     * - Parameters:
     *   - pet: The pet to generate summary for
     *   - dateRange: Date range for the summary
     * - Returns: Generated visit summary
     */
    func generateSummary(
        for pet: Pet,
        dateRange: VisitSummaryDateRange = .thirtyDays
    ) async throws -> VisitSummary {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // Fetch all data in parallel for performance
            async let foodChanges = fetchFoodChanges(for: pet, dateRange: dateRange)
            async let weightTrend = fetchWeightTrend(for: pet, dateRange: dateRange)
            async let medications = fetchActiveMedications(for: pet)
            async let healthEvents = fetchHealthEvents(for: pet, dateRange: dateRange)
            
            let summary = VisitSummary(
                id: UUID().uuidString,
                pet: pet,
                dateRange: dateRange,
                generatedAt: Date(),
                foodChanges: try await foodChanges,
                weightTrend: try await weightTrend,
                activeMedications: try await medications,
                recentHealthEvents: try await healthEvents,
                knownSensitivities: pet.knownSensitivities,
                ownerNotes: [] // User can add these interactively
            )
            
            currentSummary = summary
            return summary
            
        } catch {
            errorMessage = "Failed to generate summary: \(error.localizedDescription)"
            LoggingManager.error("Visit summary generation failed: \(error)", category: .general)
            throw error
        }
    }
    
    /**
     * Clear the current summary
     */
    func clearSummary() {
        currentSummary = nil
        errorMessage = nil
    }
    
    // MARK: - Data Fetching
    
    /**
     * Fetch food changes within the date range
     * Analyzes feeding log history to identify foods actually fed to the pet
     * Uses feeding logs (not scans) as they represent what the pet actually ate
     */
    private func fetchFoodChanges(
        for pet: Pet,
        dateRange: VisitSummaryDateRange
    ) async throws -> [FoodChangeEntry] {
        let startDate = dateRange.startDate()
        
        // Get feeding records for this pet (actual food fed, not just scanned)
        let feedingRecords = try await feedingLogService.getFeedingRecords(
            for: pet.id,
            days: dateRange.rawValue
        )
        
        // Filter to date range and sort chronologically
        let relevantRecords = feedingRecords.filter { record in
            record.feedingTime >= startDate
        }.sorted { $0.feedingTime < $1.feedingTime }
        
        // Convert feeding records to food change entries
        // Track unique foods to show first occurrence as "added" and subsequent as "switched"
        var foodChanges: [FoodChangeEntry] = []
        var seenFoods: Set<String> = []
        
        for record in relevantRecords {
            let foodName = record.foodName ?? "Unknown Food"
            let normalizedName = foodName.lowercased()
            
            // Determine if this is a new food or existing
            let changeType: FoodChangeType = seenFoods.contains(normalizedName) ? .switched : .added
            seenFoods.insert(normalizedName)
            
            // Check food name against pet's known sensitivities
            var flaggedIngredients: [FlaggedIngredient] = []
            for sensitivity in pet.knownSensitivities {
                let sensitivityLower = sensitivity.lowercased()
                if foodName.lowercased().contains(sensitivityLower) {
                    flaggedIngredients.append(FlaggedIngredient(
                        name: sensitivity,
                        reason: "Food contains known sensitivity",
                        severity: .knownSensitivity
                    ))
                }
            }
            
            foodChanges.append(FoodChangeEntry(
                date: record.feedingTime,
                foodName: foodName,
                brand: record.foodBrand,
                changeType: changeType,
                flaggedIngredients: flaggedIngredients,
                scanId: nil
            ))
        }
        
        // Return unique foods only (first occurrence of each food)
        // to show what foods were introduced during the period
        var uniqueFoodChanges: [FoodChangeEntry] = []
        var addedFoods: Set<String> = []
        
        for change in foodChanges {
            let normalizedName = change.foodName.lowercased()
            if !addedFoods.contains(normalizedName) {
                addedFoods.insert(normalizedName)
                uniqueFoodChanges.append(change)
            }
        }
        
        return uniqueFoodChanges.sorted { $0.date > $1.date }
    }
    
    /**
     * Fetch weight trend data for sparkline display
     */
    private func fetchWeightTrend(
        for pet: Pet,
        dateRange: VisitSummaryDateRange
    ) async throws -> WeightTrendData {
        // Reserved for future weight history query using dateRange.startDate()
        
        // Load feeding records to get weight history
        // Weight updates are tracked through pet profile updates
        // For now, we'll use current weight as the latest data point
        // In a full implementation, this would query weight history table
        
        var dataPoints: [WeightDataPoint] = []
        
        // Add current weight if available
        if let currentWeight = pet.weightKg {
            dataPoints.append(WeightDataPoint(
                date: Date(),
                weightKg: currentWeight
            ))
        }
        
        // Return empty if no data
        guard !dataPoints.isEmpty else {
            return .empty
        }
        
        let weights = dataPoints.map { $0.weightKg }
        let startWeight = dataPoints.first?.weightKg
        let endWeight = dataPoints.last?.weightKg
        
        // Calculate change percentage
        var changePercent: Double?
        if let start = startWeight, let end = endWeight, start > 0 {
            changePercent = ((end - start) / start) * 100
        }
        
        // Determine trend direction
        let trend: WeightTrend
        if dataPoints.count < 2 {
            trend = .insufficient
        } else if let change = changePercent {
            if change > 3 {
                trend = .increasing
            } else if change < -3 {
                trend = .decreasing
            } else {
                trend = .stable
            }
        } else {
            trend = .insufficient
        }
        
        return WeightTrendData(
            dataPoints: dataPoints,
            startWeight: startWeight,
            endWeight: endWeight,
            minWeight: weights.min(),
            maxWeight: weights.max(),
            overallChangePercent: changePercent,
            trend: trend
        )
    }
    
    /**
     * Fetch active medications for the pet
     */
    private func fetchActiveMedications(for pet: Pet) async throws -> [ActiveMedication] {
        let reminders = medicationService.getMedicationReminders(for: pet.id)
        
        return reminders
            .filter { $0.isCurrentlyActive }
            .map { reminder in
                ActiveMedication(
                    id: reminder.id,
                    name: reminder.medicationName,
                    dosage: reminder.dosage,
                    frequency: reminder.frequency.displayName,
                    startDate: reminder.startDate,
                    endDate: reminder.endDate,
                    isOngoing: reminder.endDate == nil
                )
            }
    }
    
    /**
     * Fetch recent health events
     */
    private func fetchHealthEvents(
        for pet: Pet,
        dateRange: VisitSummaryDateRange
    ) async throws -> [HealthEventSummary] {
        let startDate = dateRange.startDate()
        
        do {
            let events = try await healthEventService.getHealthEvents(for: pet.id, limit: 50)
            
            return events
                .filter { $0.eventDate >= startDate }
                .map { event in
                    HealthEventSummary(
                        id: event.id,
                        date: event.eventDate,
                        type: event.eventType,
                        title: event.title,
                        severityLevel: event.severityLevel,
                        notes: event.notes
                    )
                }
                .sorted { $0.date > $1.date }
        } catch {
            LoggingManager.warning("Failed to fetch health events: \(error)", category: .general)
            return []
        }
    }
}
