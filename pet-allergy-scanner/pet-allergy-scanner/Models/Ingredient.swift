//
//  Ingredient.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Ingredient data model representing an ingredient in the database
struct Ingredient: Codable, Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    let safetyLevel: IngredientSafety
    let speciesCompatibility: SpeciesCompatibility
    let description: String?
    let commonAllergen: Bool
    let nutritionalValue: [String: String]?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case aliases
        case safetyLevel = "safety_level"
        case speciesCompatibility = "species_compatibility"
        case description
        case commonAllergen = "common_allergen"
        case nutritionalValue = "nutritional_value"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Ingredient safety level enumeration
enum IngredientSafety: String, Codable, CaseIterable {
    case safe = "safe"
    case caution = "caution"
    case unsafe = "unsafe"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .safe:
            return "Safe"
        case .caution:
            return "Caution"
        case .unsafe:
            return "Unsafe"
        case .unknown:
            return "Unknown"
        }
    }
    
    var color: String {
        switch self {
        case .safe:
            return "green"
        case .caution:
            return "yellow"
        case .unsafe:
            return "red"
        case .unknown:
            return "gray"
        }
    }
}

/// Species compatibility enumeration
enum SpeciesCompatibility: String, Codable, CaseIterable {
    case dogOnly = "dog_only"
    case catOnly = "cat_only"
    case both = "both"
    case neither = "neither"
    
    var displayName: String {
        switch self {
        case .dogOnly:
            return "Dogs Only"
        case .catOnly:
            return "Cats Only"
        case .both:
            return "Both Species"
        case .neither:
            return "Neither Species"
        }
    }
}

/// Ingredient analysis result model
struct IngredientAnalysis: Codable, Identifiable {
    let id = UUID()
    let ingredientName: String
    let safetyLevel: IngredientSafety
    let isUnsafeForPet: Bool
    let reason: String?
    let alternatives: [String]
    
    enum CodingKeys: String, CodingKey {
        case ingredientName = "ingredient_name"
        case safetyLevel = "safety_level"
        case isUnsafeForPet = "is_unsafe_for_pet"
        case reason
        case alternatives
    }
}
