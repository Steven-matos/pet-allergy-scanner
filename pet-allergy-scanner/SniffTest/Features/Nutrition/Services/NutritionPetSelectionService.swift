//
//  NutritionPetSelectionService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/**
 * Nutrition Pet Selection Service
 * 
 * Manages pet selection state across all nutrition-related views to ensure
 * users only need to select a pet once and can change it later.
 * 
 * Follows SOLID principles with single responsibility for pet selection state
 * Implements DRY by centralizing pet selection logic
 * Follows KISS by providing a simple, focused API
 */
@MainActor
class NutritionPetSelectionService: ObservableObject {
    static let shared = NutritionPetSelectionService()
    
    @Published var selectedPet: Pet?
    @Published var isPetSelectionRequired: Bool = true
    
    private init() {}
    
    /// Set the selected pet and mark selection as complete
    /// - Parameter pet: The pet to select
    func selectPet(_ pet: Pet) {
        selectedPet = pet
        isPetSelectionRequired = false
    }
    
    /// Clear the selected pet and require new selection
    func clearSelection() {
        selectedPet = nil
        isPetSelectionRequired = true
    }
    
    /// Check if a pet is currently selected
    var hasSelectedPet: Bool {
        return selectedPet != nil
    }
    
    /// Get the selected pet or return nil
    var currentPet: Pet? {
        return selectedPet
    }
}
