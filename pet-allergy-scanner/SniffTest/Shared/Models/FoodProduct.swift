//
//  FoodProduct.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation

/**
 * Food product model from database
 *
 * Represents a pet food product with complete nutritional information,
 * retrieved from the food_items database table (Issue #20)
 */
struct FoodProduct: Codable, Equatable, Identifiable, Hashable {
    /**
     * Nutritional information model matching backend API (22 fields)
     *
     * Comprehensive nutritional data structure from PR #19 / Issue #20
     * - 10 nutritional values (calories, protein, fat, fiber, moisture, ash, carbs, sugars, saturated fat, sodium)
     * - 5 array fields (ingredients, allergens, additives, vitamins, minerals)
     * - 4 metadata fields (source, external_id, data_quality_score, last_updated)
     * - 3 object fields (nutrient_levels, packaging_info, manufacturing_info)
     */
    struct NutritionalInfo: Codable, Equatable, Hashable {
    // MARK: - Nutritional Values (10 fields) - numbers or null
    
    /// Calories per 100g of product
    let caloriesPer100g: Double?
    
    /// Protein percentage (crude protein)
    let proteinPercentage: Double?
    
    /// Fat percentage (crude fat)
    let fatPercentage: Double?
    
    /// Fiber percentage (crude fiber)
    let fiberPercentage: Double?
    
    /// Moisture percentage
    let moisturePercentage: Double?
    
    /// Ash percentage (mineral content)
    let ashPercentage: Double?
    
    /// Carbohydrates percentage
    let carbohydratesPercentage: Double?
    
    /// Sugars percentage
    let sugarsPercentage: Double?
    
    /// Saturated fat percentage
    let saturatedFatPercentage: Double?
    
    /// Sodium percentage
    let sodiumPercentage: Double?
    
    // MARK: - Array Fields (5 fields) - empty arrays if missing
    
    /// List of ingredients in descending order by weight
    let ingredients: [String]
    
    /// List of known allergens
    let allergens: [String]
    
    /// List of food additives (preservatives, colors, etc.)
    let additives: [String]
    
    /// List of vitamins
    let vitamins: [String]
    
    /// List of minerals
    let minerals: [String]
    
    // MARK: - Metadata Fields (4 fields) - strings with defaults
    
    /// Data source identifier (e.g., "openpetfoodfacts", "manual")
    let source: String
    
    /// External system ID for data source
    let externalId: String
    
    /// Data completeness score (0.0 to 1.0)
    let dataQualityScore: Double
    
    /// ISO 8601 timestamp of last data update
    let lastUpdated: String
    
    // MARK: - Object Fields (3 fields) - empty objects if missing
    
    /// Nutrient level classifications (high/low/moderate)
    let nutrientLevels: [String: AnyCodable]
    
    /// Packaging details (size, material, recyclability)
    let packagingInfo: [String: AnyCodable]
    
    /// Manufacturing information (country, certifications)
    let manufacturingInfo: [String: AnyCodable]
    
    enum CodingKeys: String, CodingKey {
        case caloriesPer100g = "calories_per_100g"
        case proteinPercentage = "protein_percentage"
        case fatPercentage = "fat_percentage"
        case fiberPercentage = "fiber_percentage"
        case moisturePercentage = "moisture_percentage"
        case ashPercentage = "ash_percentage"
        case carbohydratesPercentage = "carbohydrates_percentage"
        case sugarsPercentage = "sugars_percentage"
        case saturatedFatPercentage = "saturated_fat_percentage"
        case sodiumPercentage = "sodium_percentage"
        case ingredients
        case allergens
        case additives
        case vitamins
        case minerals
        case source
        case externalId = "external_id"
        case dataQualityScore = "data_quality_score"
        case lastUpdated = "last_updated"
        case nutrientLevels = "nutrient_levels"
        case packagingInfo = "packaging_info"
        case manufacturingInfo = "manufacturing_info"
    }
    } // End of NutritionalInfo
    
    // MARK: - FoodProduct Properties
    
    let id: String
    let name: String
    let brand: String?
    let barcode: String?
    let nutritionalInfo: NutritionalInfo?
    let category: String?
    let description: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case barcode
        case nutritionalInfo = "nutritional_info"
        case category
        case description
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /**
     * Display name combining brand and product name
     */
    var displayName: String {
        if let brand = brand, !brand.isEmpty {
            return "\(brand) - \(name)"
        }
        return name
    }
    
    /**
     * Check if product has complete nutritional information
     */
    var hasCompleteNutritionalInfo: Bool {
        guard let info = nutritionalInfo else { return false }
        return info.proteinPercentage != nil &&
               info.fatPercentage != nil &&
               info.fiberPercentage != nil &&
               info.moisturePercentage != nil
    }
    
    /**
     * Get ingredient list as formatted string
     */
    var ingredientsText: String {
        guard let ingredients = nutritionalInfo?.ingredients, !ingredients.isEmpty else {
            return "No ingredients available"
        }
        return ingredients.joined(separator: ", ")
    }
    
    /**
     * Get comprehensive data quality metrics using enhanced assessment
     */
    var qualityMetrics: DataQualityMetrics {
        return DataQualityService.assessDataQuality(self)
    }
    
    /**
     * Get quality improvement recommendations
     */
    var qualityRecommendations: [String] {
        let metrics = DataQualityService.assessDataQuality(self)
        return DataQualityService.getQualityRecommendations(metrics)
    }
} // End of FoodProduct

/**
 * Helper type for decoding arbitrary JSON values
 */
struct AnyCodable: Codable, Equatable, Hashable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
    
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}

// MARK: - NutritionalInfo Extensions (Issue #20)

extension FoodProduct.NutritionalInfo {
    /**
     * Check if basic macronutrients are available
     */
    var hasBasicMacros: Bool {
        proteinPercentage != nil ||
        fatPercentage != nil ||
        fiberPercentage != nil ||
        moisturePercentage != nil ||
        caloriesPer100g != nil
    }
    
    /**
     * Check if extended nutritional values are available (NEW from Issue #20)
     */
    var hasExtendedNutrition: Bool {
        carbohydratesPercentage != nil ||
        sugarsPercentage != nil ||
        saturatedFatPercentage != nil ||
        sodiumPercentage != nil
    }
    
    /**
     * Check if any additives are present
     */
    var hasAdditives: Bool {
        !additives.isEmpty
    }
    
    /**
     * Check if vitamins are listed
     */
    var hasVitamins: Bool {
        !vitamins.isEmpty
    }
    
    /**
     * Check if minerals are listed
     */
    var hasMinerals: Bool {
        !minerals.isEmpty
    }
    
    /**
     * Data quality level classification using enhanced assessment
     */
    var qualityLevel: DataQuality {
        // Use the enhanced DataQualityService for consistent assessment
        // Note: This requires a FoodProduct instance, so we'll use the legacy method for now
        switch dataQualityScore {
        case 0.9...1.0:
            return .excellent
        case 0.7..<0.9:
            return .good
        case 0.5..<0.7:
            return .fair
        default:
            return .poor
        }
    }
    
    /**
     * Format last updated date for display
     */
    var formattedLastUpdated: String {
        guard !lastUpdated.isEmpty else { return "Unknown" }
        
        // Parse ISO 8601 date
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: lastUpdated) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        
        return lastUpdated
    }
}

/**
 * Data quality classification (Issue #20)
 */
enum DataQuality: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Limited"
    
    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .fair:
            return "orange"
        case .poor:
            return "gray"
        }
    }
    
    var icon: String {
        switch self {
        case .excellent:
            return "checkmark.seal.fill"
        case .good:
            return "checkmark.circle.fill"
        case .fair:
            return "exclamationmark.circle"
        case .poor:
            return "info.circle"
        }
    }
}


