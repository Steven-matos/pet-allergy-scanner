//
//  GuidanceEngine.swift
//  SniffTest
//
//  Created for Gap #1: Guided Health Moments
//  Rule-based contextual prompts triggered by user actions
//

import Foundation
import Combine

/**
 * GuidanceEngine - Rule-based Health Guidance Service
 *
 * Provides contextual prompts triggered by domain events to help pet owners:
 * - Know what to log after actions (scans, weight updates, medications)
 * - Understand when to monitor for changes
 * - Learn why logging matters for their pet's health timeline
 *
 * This is NOT ML-based - purely rule-based logic for predictability and trust.
 *
 * Follows SOLID principles:
 * - Single Responsibility: Only handles guidance rule evaluation
 * - Open/Closed: New rules can be added without modifying existing ones
 * - Interface Segregation: Small, focused protocol
 */

// MARK: - Domain Events

/// Events that can trigger health guidance prompts
enum GuidanceEvent: Equatable {
    case scanSaved(hasUnsafeIngredients: Bool, hasCautionIngredients: Bool, productName: String?)
    case weightUpdated(changePercentage: Double, species: PetSpecies)
    case medicationAdded(medicationName: String, frequency: MedicationFrequency)
    case healthEventLogged(eventType: HealthEventType)
    case foodChanged(previousFood: String?, newFood: String)
    case firstScanCompleted
}

// MARK: - Guidance Model

/// Represents a contextual health guidance prompt
struct HealthGuidance: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let icon: String
    let guidanceType: GuidanceType
    let priority: GuidancePriority
    let monitoringDays: Int?
    let actionItems: [String]
    let dismissable: Bool
    let createdAt: Date
    
    /// Initialize with default values for simpler guidance creation
    init(
        id: String = UUID().uuidString,
        title: String,
        message: String,
        icon: String,
        guidanceType: GuidanceType,
        priority: GuidancePriority = .normal,
        monitoringDays: Int? = nil,
        actionItems: [String] = [],
        dismissable: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.icon = icon
        self.guidanceType = guidanceType
        self.priority = priority
        self.monitoringDays = monitoringDays
        self.actionItems = actionItems
        self.dismissable = dismissable
        self.createdAt = createdAt
    }
}

/// Types of guidance for categorization
enum GuidanceType: String, Codable, CaseIterable {
    case monitoring       // Watch for symptoms
    case logging          // Encourage data entry
    case celebration      // Positive reinforcement
    case awareness        // Educational info
    case reminder         // Follow-up action
}

/// Priority levels for guidance display
enum GuidancePriority: Int, Codable, Comparable {
    case low = 1
    case normal = 2
    case high = 3
    
    static func < (lhs: GuidancePriority, rhs: GuidancePriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Guidance Engine

/// Main service for evaluating guidance rules and generating prompts
@MainActor
final class GuidanceEngine: ObservableObject {
    static let shared = GuidanceEngine()
    
    /// Currently active guidance prompts
    @Published private(set) var activeGuidance: [HealthGuidance] = []
    
    /// Dismissed guidance IDs (persisted in UserDefaults)
    private var dismissedGuidanceIds: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: "dismissedGuidanceIds") ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "dismissedGuidanceIds")
        }
    }
    
    private init() {}
    
    // MARK: - Public API
    
    /**
     * Evaluate guidance rules for a domain event
     * - Parameter event: The event that triggered the evaluation
     * - Returns: Array of applicable health guidance prompts
     */
    func evaluate(event: GuidanceEvent) -> [HealthGuidance] {
        let guidance = generateGuidance(for: event)
        
        // Filter out dismissed guidance
        let filteredGuidance = guidance.filter { !dismissedGuidanceIds.contains($0.id) }
        
        // Update active guidance (sorted by priority)
        activeGuidance = filteredGuidance.sorted { $0.priority > $1.priority }
        
        return activeGuidance
    }
    
    /**
     * Dismiss a guidance prompt
     * - Parameter guidanceId: The ID of the guidance to dismiss
     */
    func dismiss(guidanceId: String) {
        dismissedGuidanceIds.insert(guidanceId)
        activeGuidance.removeAll { $0.id == guidanceId }
    }
    
    /**
     * Clear all active guidance (e.g., on navigation)
     */
    func clearActiveGuidance() {
        activeGuidance = []
    }
    
    /**
     * Reset dismissed guidance (for testing or settings reset)
     */
    func resetDismissedGuidance() {
        dismissedGuidanceIds = []
    }
    
    // MARK: - Rule Evaluation
    
    /**
     * Generate guidance based on event type
     * Each case contains rule-based logic for that specific event
     */
    private func generateGuidance(for event: GuidanceEvent) -> [HealthGuidance] {
        switch event {
        case .scanSaved(let hasUnsafe, let hasCaution, let productName):
            return generatePostScanGuidance(
                hasUnsafeIngredients: hasUnsafe,
                hasCautionIngredients: hasCaution,
                productName: productName
            )
            
        case .weightUpdated(let changePercentage, let species):
            return generateWeightChangeGuidance(
                changePercentage: changePercentage,
                species: species
            )
            
        case .medicationAdded(let medicationName, let frequency):
            return generateMedicationGuidance(
                medicationName: medicationName,
                frequency: frequency
            )
            
        case .healthEventLogged(let eventType):
            return generateHealthEventGuidance(eventType: eventType)
            
        case .foodChanged(let previousFood, let newFood):
            return generateFoodChangeGuidance(
                previousFood: previousFood,
                newFood: newFood
            )
            
        case .firstScanCompleted:
            return generateFirstScanGuidance()
        }
    }
    
    // MARK: - Post-Scan Guidance Rules
    
    /**
     * Generate guidance after a food scan is completed
     * Key insight: Most owners don't know what to watch for after trying new food
     */
    private func generatePostScanGuidance(
        hasUnsafeIngredients: Bool,
        hasCautionIngredients: Bool,
        productName: String?
    ) -> [HealthGuidance] {
        var guidance: [HealthGuidance] = []
        let foodName = productName ?? "this food"
        
        if hasUnsafeIngredients {
            // High priority warning for unsafe ingredients
            guidance.append(HealthGuidance(
                id: "scan-unsafe-\(Date().timeIntervalSince1970)",
                title: "Ingredient Alert",
                message: "This food contains ingredients that may not be safe for your pet. Consider alternatives or consult your vet before feeding.",
                icon: "exclamationmark.triangle.fill",
                guidanceType: .awareness,
                priority: .high,
                actionItems: [
                    "Review flagged ingredients",
                    "Consider alternative foods",
                    "Consult your vet if unsure"
                ]
            ))
        } else if hasCautionIngredients {
            // Monitoring guidance for caution ingredients
            guidance.append(HealthGuidance(
                id: "scan-caution-\(Date().timeIntervalSince1970)",
                title: "Monitor Your Pet",
                message: "If you decide to try \(foodName), watch for changes in stool, itching, or appetite over the next 7 days.",
                icon: "eye.fill",
                guidanceType: .monitoring,
                priority: .normal,
                monitoringDays: 7,
                actionItems: [
                    "Check stool consistency daily",
                    "Watch for excessive scratching",
                    "Note any changes in appetite",
                    "Log any unusual behavior"
                ]
            ))
        } else {
            // Positive reinforcement for safe foods
            guidance.append(HealthGuidance(
                id: "scan-safe-\(Date().timeIntervalSince1970)",
                title: "Looking Good!",
                message: "No concerning ingredients detected. Still, introduce new foods gradually over 5-7 days.",
                icon: "checkmark.circle.fill",
                guidanceType: .celebration,
                priority: .low,
                monitoringDays: 7,
                actionItems: [
                    "Introduce gradually over 5-7 days",
                    "Mix with current food initially"
                ]
            ))
        }
        
        return guidance
    }
    
    // MARK: - Weight Change Guidance Rules
    
    /**
     * Generate guidance after a weight update
     * Weight changes of >5% warrant attention
     */
    private func generateWeightChangeGuidance(
        changePercentage: Double,
        species: PetSpecies
    ) -> [HealthGuidance] {
        var guidance: [HealthGuidance] = []
        let absChange = abs(changePercentage)
        
        if absChange >= 10 {
            // Significant weight change - high priority
            let direction = changePercentage > 0 ? "gained" : "lost"
            guidance.append(HealthGuidance(
                id: "weight-significant-\(Date().timeIntervalSince1970)",
                title: "Notable Weight Change",
                message: "Your pet has \(direction) \(String(format: "%.1f", absChange))% of their body weight. Consider logging any diet or activity changes.",
                icon: "scalemass.fill",
                guidanceType: .logging,
                priority: .high,
                actionItems: [
                    "Log any recent food changes",
                    "Note activity level changes",
                    "Consider a vet check-up if unexpected"
                ]
            ))
        } else if absChange >= 5 {
            // Moderate weight change
            guidance.append(HealthGuidance(
                id: "weight-moderate-\(Date().timeIntervalSince1970)",
                title: "Weight Tracking Tip",
                message: "A \(String(format: "%.1f", absChange))% weight change detected. Track feeding amounts and activity to understand the trend.",
                icon: "chart.line.uptrend.xyaxis",
                guidanceType: .logging,
                priority: .normal,
                actionItems: [
                    "Log daily feedings",
                    "Track portion sizes"
                ]
            ))
        }
        
        return guidance
    }
    
    // MARK: - Medication Guidance Rules
    
    /**
     * Generate guidance when medication is added
     * Helps owners know what side effects to watch for
     */
    private func generateMedicationGuidance(
        medicationName: String,
        frequency: MedicationFrequency
    ) -> [HealthGuidance] {
        return [
            HealthGuidance(
                id: "medication-\(Date().timeIntervalSince1970)",
                title: "Medication Started",
                message: "Starting \(medicationName). Watch for any unusual reactions and log them as health events.",
                icon: "pills.fill",
                guidanceType: .monitoring,
                priority: .normal,
                monitoringDays: 14,
                actionItems: [
                    "Watch for appetite changes",
                    "Monitor energy levels",
                    "Note any digestive changes",
                    "Log unusual behavior"
                ]
            )
        ]
    }
    
    // MARK: - Health Event Guidance Rules
    
    /**
     * Generate follow-up guidance after logging a health event
     */
    private func generateHealthEventGuidance(eventType: HealthEventType) -> [HealthGuidance] {
        var guidance: [HealthGuidance] = []
        
        switch eventType {
        case .vomiting, .diarrhea:
            guidance.append(HealthGuidance(
                id: "digestive-\(Date().timeIntervalSince1970)",
                title: "Track Recovery",
                message: "Log any repeat episodes and note what your pet ate recently. Multiple episodes may warrant a vet visit.",
                icon: "heart.text.square.fill",
                guidanceType: .monitoring,
                priority: .normal,
                monitoringDays: 3,
                actionItems: [
                    "Note any repeat episodes",
                    "Track food and water intake",
                    "Monitor energy levels"
                ]
            ))
            
        case .vetVisit:
            guidance.append(HealthGuidance(
                id: "vetvisit-\(Date().timeIntervalSince1970)",
                title: "Visit Logged",
                message: "Great job keeping records! Add any follow-up instructions or medication reminders.",
                icon: "checkmark.seal.fill",
                guidanceType: .celebration,
                priority: .low,
                actionItems: [
                    "Add medication reminders if prescribed",
                    "Schedule any follow-up appointments"
                ]
            ))
            
        default:
            break
        }
        
        return guidance
    }
    
    // MARK: - Food Change Guidance Rules
    
    /**
     * Generate guidance when switching foods
     */
    private func generateFoodChangeGuidance(
        previousFood: String?,
        newFood: String
    ) -> [HealthGuidance] {
        return [
            HealthGuidance(
                id: "food-change-\(Date().timeIntervalSince1970)",
                title: "Transition Period",
                message: "Switching to \(newFood)? Transition gradually over 7 days to avoid digestive upset.",
                icon: "arrow.triangle.2.circlepath",
                guidanceType: .awareness,
                priority: .normal,
                monitoringDays: 7,
                actionItems: [
                    "Days 1-2: 75% old, 25% new",
                    "Days 3-4: 50% old, 50% new",
                    "Days 5-6: 25% old, 75% new",
                    "Day 7+: 100% new food"
                ]
            )
        ]
    }
    
    // MARK: - First Scan Guidance
    
    /**
     * Welcome guidance for first-time users
     */
    private func generateFirstScanGuidance() -> [HealthGuidance] {
        return [
            HealthGuidance(
                id: "first-scan",
                title: "Great Start!",
                message: "You've completed your first scan. Keep scanning foods to build a complete picture of your pet's diet.",
                icon: "star.fill",
                guidanceType: .celebration,
                priority: .normal,
                actionItems: [
                    "Scan your pet's regular foods",
                    "Log feedings to track calories",
                    "Add weight measurements monthly"
                ]
            )
        ]
    }
}
