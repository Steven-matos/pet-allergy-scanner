//
//  VisitSummaryModels.swift
//  SniffTest
//
//  Created for Gap #2: Vet-Readable Packaging
//  Compressed clarity for veterinary visits
//

import Foundation

/**
 * Visit Summary Models
 *
 * Data models for one-tap vet visit summaries that package:
 * - Food changes with flagged ingredients
 * - Weight trends (sparkline data)
 * - Active medications
 * - Owner notes
 * - Known sensitivities
 *
 * Design Principle: No diagnoses. No recommendations. Just compressed clarity.
 */

// MARK: - Visit Summary

/// Complete visit summary for a pet
struct VisitSummary: Identifiable, Equatable {
    let id: String
    let pet: Pet
    let dateRange: VisitSummaryDateRange
    let generatedAt: Date
    
    // Core data sections
    let foodChanges: [FoodChangeEntry]
    let weightTrend: WeightTrendData
    let activeMedications: [ActiveMedication]
    let recentHealthEvents: [HealthEventSummary]
    let knownSensitivities: [String]
    let ownerNotes: [OwnerNote]
    
    /// Summary statistics for quick reference
    var stats: VisitSummaryStats {
        VisitSummaryStats(
            totalFoodChanges: foodChanges.count,
            flaggedIngredientCount: foodChanges.reduce(0) { $0 + $1.flaggedIngredients.count },
            weightChangePercent: weightTrend.overallChangePercent,
            activeMedicationCount: activeMedications.count,
            healthEventCount: recentHealthEvents.count
        )
    }
    
    /// Check if summary has meaningful data to display
    var hasData: Bool {
        return !foodChanges.isEmpty || 
               weightTrend.hasData ||
               !activeMedications.isEmpty ||
               !recentHealthEvents.isEmpty
    }
}

/// Date range options for visit summary
enum VisitSummaryDateRange: Int, CaseIterable, Identifiable {
    case thirtyDays = 30
    case sixtyDays = 60
    case ninetyDays = 90
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .thirtyDays: return "Last 30 Days"
        case .sixtyDays: return "Last 60 Days"
        case .ninetyDays: return "Last 90 Days"
        }
    }
    
    var shortName: String {
        "\(rawValue)d"
    }
    
    /// Start date for this range
    func startDate(from endDate: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -rawValue, to: endDate) ?? endDate
    }
}

/// Quick statistics for the summary header
struct VisitSummaryStats: Equatable {
    let totalFoodChanges: Int
    let flaggedIngredientCount: Int
    let weightChangePercent: Double?
    let activeMedicationCount: Int
    let healthEventCount: Int
}

// MARK: - Food Changes

/// Food change entry with flagged ingredients
struct FoodChangeEntry: Identifiable, Equatable {
    let id: String
    let date: Date
    let foodName: String
    let brand: String?
    let changeType: FoodChangeType
    let flaggedIngredients: [FlaggedIngredient]
    let scanId: String?
    
    /// Initialize with auto-generated ID
    init(
        date: Date,
        foodName: String,
        brand: String? = nil,
        changeType: FoodChangeType,
        flaggedIngredients: [FlaggedIngredient] = [],
        scanId: String? = nil
    ) {
        self.id = UUID().uuidString
        self.date = date
        self.foodName = foodName
        self.brand = brand
        self.changeType = changeType
        self.flaggedIngredients = flaggedIngredients
        self.scanId = scanId
    }
    
    /// Display name combining brand and food
    var displayName: String {
        if let brand = brand, !brand.isEmpty {
            return "\(brand) \(foodName)"
        }
        return foodName
    }
}

/// Type of food change
enum FoodChangeType: String, Codable, CaseIterable {
    case added = "added"
    case removed = "removed"
    case switched = "switched"
    
    var displayName: String {
        switch self {
        case .added: return "Added"
        case .removed: return "Removed"
        case .switched: return "Switched"
        }
    }
    
    var icon: String {
        switch self {
        case .added: return "plus.circle.fill"
        case .removed: return "minus.circle.fill"
        case .switched: return "arrow.triangle.2.circlepath"
        }
    }
}

/// Flagged ingredient with reason
struct FlaggedIngredient: Identifiable, Equatable {
    let id: String
    let name: String
    let reason: String
    let severity: FlaggedIngredientSeverity
    
    init(
        name: String,
        reason: String,
        severity: FlaggedIngredientSeverity
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.reason = reason
        self.severity = severity
    }
}

/// Severity level for flagged ingredients
enum FlaggedIngredientSeverity: String, Codable, CaseIterable {
    case caution = "caution"
    case unsafe = "unsafe"
    case knownSensitivity = "known_sensitivity"
    
    var displayName: String {
        switch self {
        case .caution: return "Caution"
        case .unsafe: return "Unsafe"
        case .knownSensitivity: return "Known Sensitivity"
        }
    }
}

// MARK: - Weight Trend

/// Weight trend data for sparkline visualization
struct WeightTrendData: Equatable {
    let dataPoints: [WeightDataPoint]
    let startWeight: Double?
    let endWeight: Double?
    let minWeight: Double?
    let maxWeight: Double?
    let overallChangePercent: Double?
    let trend: WeightTrend
    
    /// Check if there's meaningful data
    var hasData: Bool {
        return dataPoints.count >= 2
    }
    
    /// Empty trend data
    static var empty: WeightTrendData {
        WeightTrendData(
            dataPoints: [],
            startWeight: nil,
            endWeight: nil,
            minWeight: nil,
            maxWeight: nil,
            overallChangePercent: nil,
            trend: .stable
        )
    }
}

/// Individual weight data point
struct WeightDataPoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let weightKg: Double
    
    init(date: Date, weightKg: Double) {
        self.id = UUID().uuidString
        self.date = date
        self.weightKg = weightKg
    }
}

/// Overall weight trend direction
enum WeightTrend: String, Codable, CaseIterable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
    case insufficient = "insufficient"
    
    var displayName: String {
        switch self {
        case .increasing: return "Increasing"
        case .decreasing: return "Decreasing"
        case .stable: return "Stable"
        case .insufficient: return "Insufficient Data"
        }
    }
    
    var icon: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "minus"
        case .insufficient: return "questionmark"
        }
    }
}

// MARK: - Active Medications

/// Active medication summary for vet review
struct ActiveMedication: Identifiable, Equatable {
    let id: String
    let name: String
    let dosage: String
    let frequency: String
    let startDate: Date
    let endDate: Date?
    let isOngoing: Bool
    
    /// Duration description
    var durationDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        if isOngoing {
            return "Started \(formatter.string(from: startDate)) - Ongoing"
        } else if let end = endDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: end))"
        }
        return "Started \(formatter.string(from: startDate))"
    }
}

// MARK: - Health Events Summary

/// Condensed health event for vet review
struct HealthEventSummary: Identifiable, Equatable {
    let id: String
    let date: Date
    let type: HealthEventType
    let title: String
    let severityLevel: Int
    let notes: String?
    
    /// Brief description for summary display
    var briefDescription: String {
        return "\(type.displayName): \(title)"
    }
}

// MARK: - Owner Notes

/// Owner note attached to the summary
struct OwnerNote: Identifiable, Equatable {
    let id: String
    let date: Date
    let content: String
    let category: OwnerNoteCategory
    
    init(
        date: Date = Date(),
        content: String,
        category: OwnerNoteCategory = .general
    ) {
        self.id = UUID().uuidString
        self.date = date
        self.content = content
        self.category = category
    }
}

/// Categories for owner notes
enum OwnerNoteCategory: String, Codable, CaseIterable {
    case general = "general"
    case behavior = "behavior"
    case diet = "diet"
    case concern = "concern"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .behavior: return "Behavior"
        case .diet: return "Diet"
        case .concern: return "Concern"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "note.text"
        case .behavior: return "pawprint"
        case .diet: return "fork.knife"
        case .concern: return "exclamationmark.circle"
        }
    }
}
