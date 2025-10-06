//
//  WeightUnitPreferenceService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/**
 * Weight Unit Preference Service
 * 
 * Manages user preference for weight unit display (kg or lb)
 * Provides conversion utilities and centralized unit management
 * 
 * Follows SOLID principles with single responsibility for unit preferences
 * Implements DRY by centralizing unit conversion logic
 * Follows KISS by providing a simple, focused API
 */
@MainActor
class WeightUnitPreferenceService: ObservableObject {
    static let shared = WeightUnitPreferenceService()
    
    @Published var selectedUnit: WeightUnit = .kg
    
    private let userDefaults = UserDefaults.standard
    private let unitKey = "weight_unit_preference"
    
    private init() {
        loadPreference()
    }
    
    /**
     * Set the preferred weight unit
     * - Parameter unit: The weight unit to use
     */
    func setUnit(_ unit: WeightUnit) {
        selectedUnit = unit
        userDefaults.set(unit.rawValue, forKey: unitKey)
    }
    
    /**
     * Get the preferred weight unit
     * - Returns: The current weight unit preference
     */
    func getUnit() -> WeightUnit {
        return selectedUnit
    }
    
    /**
     * Convert weight from kg to the preferred unit
     * - Parameter kg: Weight in kilograms
     * - Returns: Weight in the preferred unit
     */
    func convertFromKg(_ kg: Double) -> Double {
        switch selectedUnit {
        case .kg:
            return kg
        case .lb:
            return kg * 2.20462
        }
    }
    
    /**
     * Convert weight from the preferred unit to kg
     * - Parameter weight: Weight in the preferred unit
     * - Returns: Weight in kilograms
     */
    func convertToKg(_ weight: Double) -> Double {
        switch selectedUnit {
        case .kg:
            return weight
        case .lb:
            return weight / 2.20462
        }
    }
    
    /**
     * Get the unit symbol for display
     * - Returns: The unit symbol (kg or lb)
     */
    func getUnitSymbol() -> String {
        return selectedUnit.symbol
    }
    
    /**
     * Format weight for display with unit
     * - Parameter kg: Weight in kilograms
     * - Parameter precision: Number of decimal places (default: 1)
     * - Returns: Formatted weight string with unit
     */
    func formatWeight(_ kg: Double, precision: Int = 1) -> String {
        let convertedWeight = convertFromKg(kg)
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = precision
        formatter.maximumFractionDigits = precision
        return "\(formatter.string(from: NSNumber(value: convertedWeight)) ?? "0") \(getUnitSymbol())"
    }
    
    private func loadPreference() {
        if let savedUnit = userDefaults.string(forKey: unitKey),
           let unit = WeightUnit(rawValue: savedUnit) {
            selectedUnit = unit
        } else {
            // Default to kg if no preference is set
            selectedUnit = .kg
        }
    }
}

/**
 * Weight Unit Enum
 */
enum WeightUnit: String, CaseIterable, Codable {
    case kg = "kg"
    case lb = "lb"
    
    var symbol: String {
        return rawValue
    }
    
    var displayName: String {
        switch self {
        case .kg:
            return "Kilograms (kg)"
        case .lb:
            return "Pounds (lb)"
        }
    }
}
