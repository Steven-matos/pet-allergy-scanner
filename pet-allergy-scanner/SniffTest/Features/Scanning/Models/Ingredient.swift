//
//  Ingredient.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//  Extended for Gap #3: Analysis Trust Framing with Explainability Layer
//

import Foundation

/**
 * Ingredient Data Model
 *
 * Represents an ingredient in the database with extended explainability layer.
 *
 * Gap #3 - Analysis Trust Framing:
 * Each flagged ingredient should answer:
 * - Why was this flagged? (explanation)
 * - For which species? (speciesCompatibility + speciesNote)
 * - At what confidence level? (confidenceLevel)
 *
 * Design Principle: Prefer calm clarity, not alarm.
 */
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
    
    // MARK: - Explainability Layer (Gap #3)
    
    /// Risk category explaining WHY this ingredient is flagged
    let riskCategory: IngredientRiskCategory?
    
    /// Confidence level for the safety assessment (0.0 - 1.0)
    let confidenceLevel: Double?
    
    /// Localized explanation key for user-friendly messaging
    let explanationKey: String?
    
    /// Additional species-specific note
    let speciesNote: String?
    
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
        case riskCategory = "risk_category"
        case confidenceLevel = "confidence_level"
        case explanationKey = "explanation_key"
        case speciesNote = "species_note"
    }
    
    /// Custom decoder to handle missing explainability fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        safetyLevel = try container.decode(IngredientSafety.self, forKey: .safetyLevel)
        speciesCompatibility = try container.decode(SpeciesCompatibility.self, forKey: .speciesCompatibility)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        commonAllergen = try container.decodeIfPresent(Bool.self, forKey: .commonAllergen) ?? false
        nutritionalValue = try container.decodeIfPresent([String: String].self, forKey: .nutritionalValue)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        
        // Explainability fields (optional - may not exist in older data)
        riskCategory = try container.decodeIfPresent(IngredientRiskCategory.self, forKey: .riskCategory)
        confidenceLevel = try container.decodeIfPresent(Double.self, forKey: .confidenceLevel)
        explanationKey = try container.decodeIfPresent(String.self, forKey: .explanationKey)
        speciesNote = try container.decodeIfPresent(String.self, forKey: .speciesNote)
    }
    
    // MARK: - Computed Explainability Properties
    
    /// Get user-friendly explanation for why this ingredient is flagged
    var explanation: IngredientExplanation {
        IngredientExplanation.generate(for: self)
    }
    
    /// Confidence description for UI display
    var confidenceDescription: String {
        guard let level = confidenceLevel else { return "Unknown" }
        switch level {
        case 0.9...: return "High confidence"
        case 0.7..<0.9: return "Moderate confidence"
        case 0.5..<0.7: return "Low confidence"
        default: return "Very low confidence"
        }
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

// MARK: - Risk Category (Gap #3)

/**
 * Ingredient Risk Category - Explains WHY an ingredient is flagged
 *
 * Used for the explainability layer to provide calm, clear reasons
 * rather than alarming or absolute statements.
 */
enum IngredientRiskCategory: String, Codable, CaseIterable {
    case allergen = "allergen"           // Common allergen
    case toxic = "toxic"                 // Known toxicity
    case digestive = "digestive"         // Digestive concerns
    case nutritionalImbalance = "nutritional_imbalance"  // Nutritional issues
    case speciesSpecific = "species_specific"  // Species-specific concern
    case qualityConcern = "quality_concern"    // Quality/sourcing issues
    case none = "none"                   // No concerns
    
    /// User-friendly display name
    var displayName: String {
        switch self {
        case .allergen: return "Common Allergen"
        case .toxic: return "Toxicity Concern"
        case .digestive: return "Digestive Sensitivity"
        case .nutritionalImbalance: return "Nutritional Concern"
        case .speciesSpecific: return "Species-Specific"
        case .qualityConcern: return "Quality Concern"
        case .none: return "No Concerns"
        }
    }
    
    /// Icon for UI display
    var icon: String {
        switch self {
        case .allergen: return "allergens"
        case .toxic: return "exclamationmark.triangle.fill"
        case .digestive: return "stomach"
        case .nutritionalImbalance: return "chart.bar.xaxis"
        case .speciesSpecific: return "pawprint.fill"
        case .qualityConcern: return "questionmark.circle"
        case .none: return "checkmark.circle"
        }
    }
    
    /// Calm explanation template
    var calmExplanation: String {
        switch self {
        case .allergen:
            return "This ingredient is a common allergen in pets. Monitor for reactions if your pet hasn't had it before."
        case .toxic:
            return "This ingredient may be harmful to pets. Consult your vet before feeding."
        case .digestive:
            return "Some pets may experience digestive sensitivity to this ingredient."
        case .nutritionalImbalance:
            return "In large amounts, this could affect nutritional balance."
        case .speciesSpecific:
            return "This ingredient may not be suitable for all species."
        case .qualityConcern:
            return "Quality can vary. Look for products with verified sourcing."
        case .none:
            return "Generally considered safe for pets."
        }
    }
}

// MARK: - Ingredient Explanation (Gap #3)

/**
 * Ingredient Explanation - User-friendly explanation for flagged ingredients
 *
 * Answers the three key questions:
 * 1. Why was this flagged?
 * 2. For which species?
 * 3. At what confidence level?
 *
 * Design Principle: Calm clarity, not alarm.
 */
struct IngredientExplanation: Equatable {
    let whyFlagged: String
    let speciesContext: String
    let confidenceStatement: String
    let actionSuggestion: String
    let severity: ExplanationSeverity
    
    /// Severity level for UI styling (calm, not alarming)
    enum ExplanationSeverity: String, CaseIterable {
        case safe = "safe"
        case informational = "informational"
        case moderate = "moderate"
        case concern = "concern"
        
        /// Appropriate tone adjective for messaging
        var toneAdjective: String {
            switch self {
            case .safe: return "generally"
            case .informational: return "typically"
            case .moderate: return "sometimes"
            case .concern: return "may be"
            }
        }
    }
    
    /// Generate explanation for an ingredient
    static func generate(for ingredient: Ingredient) -> IngredientExplanation {
        // Determine why it was flagged
        let whyFlagged = generateWhyFlagged(ingredient)
        
        // Determine species context
        let speciesContext = generateSpeciesContext(ingredient)
        
        // Determine confidence statement
        let confidenceStatement = generateConfidenceStatement(ingredient)
        
        // Generate action suggestion
        let actionSuggestion = generateActionSuggestion(ingredient)
        
        // Determine severity
        let severity = determineSeverity(ingredient)
        
        return IngredientExplanation(
            whyFlagged: whyFlagged,
            speciesContext: speciesContext,
            confidenceStatement: confidenceStatement,
            actionSuggestion: actionSuggestion,
            severity: severity
        )
    }
    
    // MARK: - Private Generation Methods
    
    private static func generateWhyFlagged(_ ingredient: Ingredient) -> String {
        // Use custom explanation key if available
        if let key = ingredient.explanationKey {
            return localizedExplanation(for: key, ingredient: ingredient)
        }
        
        // Use risk category if available
        if let category = ingredient.riskCategory {
            return category.calmExplanation
        }
        
        // Fall back to safety level
        switch ingredient.safetyLevel {
        case .safe:
            return "Generally considered safe for pets."
        case .caution:
            if ingredient.commonAllergen {
                return "Common allergen in \(ingredient.speciesCompatibility.affectedSpecies). Monitor for reactions."
            }
            return "Some pets may be sensitive. Monitor after feeding."
        case .unsafe:
            return "This ingredient may not be suitable for pets. Consult your vet."
        case .unknown:
            return "Limited data available. Introduce cautiously."
        }
    }
    
    private static func generateSpeciesContext(_ ingredient: Ingredient) -> String {
        // Use custom species note if available
        if let note = ingredient.speciesNote {
            return note
        }
        
        switch ingredient.speciesCompatibility {
        case .dogOnly:
            return "Safe for dogs. Unsafe for cats."
        case .catOnly:
            return "Safe for cats. Unsafe for dogs."
        case .both:
            return "Suitable for both dogs and cats."
        case .neither:
            return "Not recommended for dogs or cats."
        }
    }
    
    private static func generateConfidenceStatement(_ ingredient: Ingredient) -> String {
        guard let level = ingredient.confidenceLevel else {
            return "Based on available ingredient databases."
        }
        
        switch level {
        case 0.9...:
            return "High confidence based on extensive research."
        case 0.7..<0.9:
            return "Moderate confidence based on available studies."
        case 0.5..<0.7:
            return "Based on limited available data."
        default:
            return "Preliminary assessment - more research needed."
        }
    }
    
    private static func generateActionSuggestion(_ ingredient: Ingredient) -> String {
        switch ingredient.safetyLevel {
        case .safe:
            return "No special precautions needed."
        case .caution:
            return "Monitor for any changes in behavior, appetite, or digestion for 24-48 hours."
        case .unsafe:
            return "Consider alternative foods or consult your veterinarian."
        case .unknown:
            return "Start with small amounts and observe your pet's reaction."
        }
    }
    
    private static func determineSeverity(_ ingredient: Ingredient) -> ExplanationSeverity {
        switch ingredient.safetyLevel {
        case .safe:
            return .safe
        case .caution:
            return ingredient.commonAllergen ? .moderate : .informational
        case .unsafe:
            return .concern
        case .unknown:
            return .informational
        }
    }
    
    /// Localized explanation for known explanation keys
    private static func localizedExplanation(for key: String, ingredient: Ingredient) -> String {
        // Common explanation keys with calm, factual language
        let explanations: [String: String] = [
            "common_dog_allergen": "Common allergen in dogs. Watch for itching, digestive upset, or skin reactions.",
            "common_cat_allergen": "Common allergen in cats. Monitor for vomiting, diarrhea, or skin issues.",
            "toxic_to_dogs": "Known to be harmful to dogs. Avoid feeding to dogs.",
            "toxic_to_cats": "Known to be harmful to cats. Avoid feeding to cats.",
            "high_sodium": "High sodium content. May not be suitable for pets with heart or kidney conditions.",
            "artificial_preservative": "Contains artificial preservatives. Some pets may be sensitive.",
            "by_product": "Contains by-products. Quality can vary by manufacturer.",
            "grain_sensitivity": "Contains grains. Some pets may have grain sensitivities.",
            "lactose_concern": "Contains lactose. Many pets are lactose intolerant.",
            "generally_safe": "Generally well-tolerated by most pets."
        ]
        
        return explanations[key] ?? ingredient.description ?? "No additional information available."
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
    
    /// Human-readable affected species for explanations
    var affectedSpecies: String {
        switch self {
        case .dogOnly:
            return "dogs"
        case .catOnly:
            return "cats"
        case .both:
            return "dogs and cats"
        case .neither:
            return "pets"
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
