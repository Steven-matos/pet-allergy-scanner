//
//  PetSensitivityService.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation

/**
 * Service for assessing pet sensitivities against scanned ingredients
 * 
 * This service compares scanned food ingredients with a pet's known sensitivities
 * to provide personalized safety warnings and recommendations.
 * 
 * Follows SOLID principles:
 * - Single Responsibility: Handles only sensitivity assessment logic
 * - Open/Closed: Extensible for new sensitivity types and assessment methods
 * - Dependency Inversion: Depends on abstractions (Pet, ScanResult models)
 */
@MainActor
class PetSensitivityService: ObservableObject {
    
    // MARK: - Properties
    
    private let apiService: APIService
    private let cacheService: CacheService
    
    // MARK: - Initialization
    
    init(apiService: APIService = APIService.shared, cacheService: CacheService = CacheService.shared) {
        self.apiService = apiService
        self.cacheService = cacheService
    }
    
    // MARK: - Public Methods
    
    /**
     * Assess scanned ingredients against pet's known sensitivities
     * 
     * - Parameters:
     *   - scan: The scan containing ingredients to assess
     * - Returns: SensitivityAssessment with detailed analysis
     */
    func assessSensitivities(for scan: Scan) async throws -> SensitivityAssessment {
        // Fetch pet information
        let pet = try await fetchPet(id: scan.petId)
        
        // Get ingredients from scan result
        guard let result = scan.result else {
            return SensitivityAssessment(
                petId: scan.petId,
                petName: pet.name,
                hasSensitivityMatches: false,
                matchedSensitivities: [],
                safeIngredients: [],
                warningIngredients: [],
                recommendations: ["No scan result available for sensitivity assessment"]
            )
        }
        
        // Perform sensitivity analysis
        return analyzeSensitivities(
            pet: pet,
            ingredients: result.ingredientsFound,
            unsafeIngredients: result.unsafeIngredients,
            safeIngredients: result.safeIngredients
        )
    }
    
    /**
     * Check if any scanned ingredients match pet's known sensitivities
     * 
     * - Parameters:
     *   - pet: Pet with known sensitivities
     *   - ingredients: List of ingredients from scan
     * - Returns: Array of matched sensitivity ingredients
     */
    func findSensitivityMatches(pet: Pet, ingredients: [String]) -> [String] {
        let petSensitivities = pet.knownSensitivities.map { $0.lowercased() }
        let scannedIngredients = ingredients.map { $0.lowercased() }
        
        return petSensitivities.compactMap { sensitivity in
            scannedIngredients.contains { ingredient in
                // Check for exact match or partial match (e.g., "chicken" matches "chicken meal")
                ingredient.contains(sensitivity) || sensitivity.contains(ingredient)
            } ? sensitivity : nil
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Fetch pet information by ID with caching
     */
    private func fetchPet(id: String) async throws -> Pet {
        // Try cache first
        if let cachedPet: Pet = cacheService.retrievePetData(Pet.self, forKey: .petDetails, petId: id) {
            return cachedPet
        }
        
        // Fetch from API
        let pet = try await apiService.getPet(id: id)
        
        // Cache the result
        cacheService.storePetData(pet, forKey: .petDetails, petId: id)
        
        return pet
    }
    
    /**
     * Analyze ingredients against pet sensitivities
     */
    private func analyzeSensitivities(
        pet: Pet,
        ingredients: [String],
        unsafeIngredients: [String],
        safeIngredients: [String]
    ) -> SensitivityAssessment {
        
        let matchedSensitivities = findSensitivityMatches(pet: pet, ingredients: ingredients)
        let hasMatches = !matchedSensitivities.isEmpty
        
        // Categorize ingredients based on sensitivity matches
        let warningIngredients = ingredients.filter { ingredient in
            matchedSensitivities.contains { sensitivity in
                ingredient.lowercased().contains(sensitivity.lowercased())
            }
        }
        
        let safeIngredients = ingredients.filter { ingredient in
            !matchedSensitivities.contains { sensitivity in
                ingredient.lowercased().contains(sensitivity.lowercased())
            }
        }
        
        // Generate recommendations
        let recommendations = generateRecommendations(
            pet: pet,
            matchedSensitivities: matchedSensitivities,
            hasMatches: hasMatches
        )
        
        return SensitivityAssessment(
            petId: pet.id,
            petName: pet.name,
            hasSensitivityMatches: hasMatches,
            matchedSensitivities: matchedSensitivities,
            safeIngredients: safeIngredients,
            warningIngredients: warningIngredients,
            recommendations: recommendations
        )
    }
    
    /**
     * Generate personalized recommendations based on sensitivity analysis
     */
    private func generateRecommendations(
        pet: Pet,
        matchedSensitivities: [String],
        hasMatches: Bool
    ) -> [String] {
        var recommendations: [String] = []
        
        if hasMatches {
            recommendations.append("⚠️ This product contains ingredients that may cause sensitivity reactions in \(pet.name)")
            recommendations.append("Consider avoiding this product or consulting with your veterinarian")
            
            if matchedSensitivities.count == 1 {
                recommendations.append("The problematic ingredient is: \(matchedSensitivities[0].capitalized)")
            } else {
                recommendations.append("Problematic ingredients include: \(matchedSensitivities.map { $0.capitalized }.joined(separator: ", "))")
            }
        } else {
            recommendations.append("✅ No known sensitivity ingredients detected for \(pet.name)")
            recommendations.append("This product appears safe based on \(pet.name)'s known sensitivities")
        }
        
        // Add general recommendations
        if !pet.knownSensitivities.isEmpty {
            recommendations.append("Always monitor \(pet.name) for any adverse reactions when trying new foods")
        }
        
        return recommendations
    }
}

// MARK: - Sensitivity Assessment Model

/**
 * Result of sensitivity assessment for a scanned product
 */
struct SensitivityAssessment: Codable, Equatable {
    let petId: String
    let petName: String
    let hasSensitivityMatches: Bool
    let matchedSensitivities: [String]
    let safeIngredients: [String]
    let warningIngredients: [String]
    let recommendations: [String]
    
    /// Severity level of sensitivity concerns
    var severityLevel: SensitivitySeverity {
        if matchedSensitivities.isEmpty {
            return .none
        } else if matchedSensitivities.count == 1 {
            return .low
        } else if matchedSensitivities.count <= 3 {
            return .moderate
        } else {
            return .high
        }
    }
    
    /// Primary warning message
    var primaryWarning: String? {
        guard hasSensitivityMatches else { return nil }
        
        if matchedSensitivities.count == 1 {
            return "Contains \(matchedSensitivities[0].capitalized) - a known sensitivity for \(petName)"
        } else {
            return "Contains \(matchedSensitivities.count) ingredients that may cause sensitivity reactions in \(petName)"
        }
    }
}

/**
 * Severity levels for sensitivity assessments
 */
enum SensitivitySeverity: String, Codable, CaseIterable {
    case none = "none"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .none:
            return "No Concerns"
        case .low:
            return "Low Risk"
        case .moderate:
            return "Moderate Risk"
        case .high:
            return "High Risk"
        }
    }
    
    var color: String {
        switch self {
        case .none:
            return "green"
        case .low:
            return "yellow"
        case .moderate:
            return "orange"
        case .high:
            return "red"
        }
    }
}
