//
//  OCRSpellChecker.swift
//  SniffTest
//
//  Created on 2025-10-15
//  Spell checker and correction utility for OCR-scanned pet food labels
//

import Foundation

/**
 * OCR Spell Checker for Pet Food Labels
 * 
 * Automatically corrects common OCR errors in pet food nutritional labels
 * Focuses on ingredient names, nutritional terms, and common misspellings
 * 
 * Uses dictionary-based correction with confidence scoring to prevent
 * over-correction of legitimate brand names or specialized terms
 */
struct OCRSpellChecker {
    
    // MARK: - Common OCR Corrections
    
    /// Dictionary mapping common OCR errors to correct spellings
    /// Organized by category for maintainability
    private static let corrections: [String: String] = {
        var dict: [String: String] = [:]
        
        // Protein sources (most common in pet food)
        dict.merge(proteinCorrections) { _, new in new }
        
        // Grains and carbohydrates
        dict.merge(grainCorrections) { _, new in new }
        
        // Vitamins and minerals
        dict.merge(vitaminCorrections) { _, new in new }
        
        // Fats and oils
        dict.merge(fatCorrections) { _, new in new }
        
        // Vegetables and fruits
        dict.merge(vegetableCorrections) { _, new in new }
        
        // Nutritional terms
        dict.merge(nutritionalTermCorrections) { _, new in new }
        
        // Common OCR character mistakes
        dict.merge(characterCorrections) { _, new in new }
        
        return dict
    }()
    
    // MARK: - Protein Sources
    
    private static let proteinCorrections: [String: String] = [
        // Poultry
        "chlcken": "chicken",
        "chlken": "chicken",
        "chickan": "chicken",
        "chiken": "chicken",
        "ch1cken": "chicken",
        "turky": "turkey",
        "turkay": "turkey",
        "turk3y": "turkey",
        
        // Beef and lamb
        "b3ef": "beef",
        "beaf": "beef",
        "lamh": "lamb",
        "1amb": "lamb",
        "Iamb": "lamb",
        
        // Fish and seafood
        "sa1mon": "salmon",
        "salmom": "salmon",
        "sahmon": "salmon",
        "tuma": "tuna",
        "tun4": "tuna",
        "sardmes": "sardines",
        "sardlnes": "sardines",
        "mackerel": "mackerel",
        
        // Other proteins
        "pork": "pork",
        "p0rk": "pork",
        "duck": "duck",
        "duek": "duck",
        "venls0n": "venison",
        "venlson": "venison",
        "bison": "bison",
        "bis0n": "bison",
        
        // Protein meals
        "mea1": "meal",
        "meel": "meal",
        "byproduct": "by-product",
        "bypr0duct": "by-product",
    ]
    
    // MARK: - Grains and Carbohydrates
    
    private static let grainCorrections: [String: String] = [
        "r1ce": "rice",
        "rlce": "rice",
        "wh3at": "wheat",
        "whent": "wheat",
        "c0rn": "corn",
        "com": "corn",
        "barley": "barley",
        "bar1ey": "barley",
        "0ats": "oats",
        "oatmeal": "oatmeal",
        "0atmeal": "oatmeal",
        "s0rghum": "sorghum",
        "mlllo": "millo",
        "tapl0ca": "tapioca",
        "tap1oca": "tapioca",
        "p0tato": "potato",
        "pot4to": "potato",
        "potat0": "potato",
        "sw3et": "sweet",
        "swe3t": "sweet",
        "peas": "peas",
        "p3as": "peas",
        "lent1ls": "lentils",
        "lentl1s": "lentils",
        "chlckpeas": "chickpeas",
        "chlck": "chick",
    ]
    
    // MARK: - Vitamins and Minerals
    
    private static let vitaminCorrections: [String: String] = [
        "v1tamin": "vitamin",
        "vltamin": "vitamin",
        "vitam1n": "vitamin",
        "calc1um": "calcium",
        "calclum": "calcium",
        "phosphorus": "phosphorus",
        "phosph0rus": "phosphorus",
        "magnes1um": "magnesium",
        "magneslum": "magnesium",
        "z1nc": "zinc",
        "zlnc": "zinc",
        "ir0n": "iron",
        "1ron": "iron",
        "copper": "copper",
        "c0pper": "copper",
        "manganese": "manganese",
        "mangan3se": "manganese",
        "s3lenium": "selenium",
        "selenlum": "selenium",
        "i0dine": "iodine",
        "lodine": "iodine",
        "th1amine": "thiamine",
        "thlamine": "thiamine",
        "r1boflavin": "riboflavin",
        "riboflavln": "riboflavin",
        "n1acin": "niacin",
        "nlacin": "niacin",
        "pantothenic": "pantothenic",
        "pant0thenic": "pantothenic",
        "pyr1doxine": "pyridoxine",
        "pyridoxlne": "pyridoxine",
        "b10tin": "biotin",
        "biot1n": "biotin",
        "f0lic": "folic",
        "follc": "folic",
        "cobalamin": "cobalamin",
        "cobalarnin": "cobalamin",
        "ch0line": "choline",
        "chollne": "choline",
        "taurlne": "taurine",
        "taur1ne": "taurine",
    ]
    
    // MARK: - Fats and Oils
    
    private static let fatCorrections: [String: String] = [
        "chlcken": "chicken",
        "ch1cken": "chicken",
        "f1sh": "fish",
        "flsh": "fish",
        "canola": "canola",
        "can0la": "canola",
        "sunfl0wer": "sunflower",
        "sunflower": "sunflower",
        "flaxse3d": "flaxseed",
        "flaxseed": "flaxseed",
        "fl4xseed": "flaxseed",
        "coconut": "coconut",
        "coc0nut": "coconut",
        "0mega": "omega",
        "omeg4": "omega",
        "llnoleic": "linoleic",
        "linole1c": "linoleic",
    ]
    
    // MARK: - Vegetables and Fruits
    
    private static let vegetableCorrections: [String: String] = [
        "carr0t": "carrot",
        "carrot": "carrot",
        "sp1nach": "spinach",
        "spinach": "spinach",
        "kale": "kale",
        "ka1e": "kale",
        "broccol1": "broccoli",
        "brocco1i": "broccoli",
        "blueb3rry": "blueberry",
        "blueberry": "blueberry",
        "cranb3rry": "cranberry",
        "cranberry": "cranberry",
        "apple": "apple",
        "app1e": "apple",
        "pumpk1n": "pumpkin",
        "pumpkln": "pumpkin",
        "squ4sh": "squash",
        "squ4ash": "squash",
    ]
    
    // MARK: - Nutritional Terms
    
    private static let nutritionalTermCorrections: [String: String] = [
        "prot3in": "protein",
        "proteln": "protein",
        "prote1n": "protein",
        "c4rbohydrate": "carbohydrate",
        "carb0hydrate": "carbohydrate",
        "f1ber": "fiber",
        "flber": "fiber",
        "molsture": "moisture",
        "mo1sture": "moisture",
        "4sh": "ash",
        "calor1e": "calorie",
        "cal0rie": "calorie",
        "kcal": "kcal",
        "kca1": "kcal",
        "guarante3d": "guaranteed",
        "guaranteed": "guaranteed",
        "analys1s": "analysis",
        "analysls": "analysis",
        "min1mum": "minimum",
        "mlnimum": "minimum",
        "max1mum": "maximum",
        "maxlmum": "maximum",
        "ingredlents": "ingredients",
        "ingred1ents": "ingredients",
        "preserv3d": "preserved",
        "preserved": "preserved",
        "art1ficial": "artificial",
        "artiflcial": "artificial",
        "natur4l": "natural",
        "natura1": "natural",
    ]
    
    // MARK: - Common OCR Character Mistakes
    
    private static let characterCorrections: [String: String] = [
        // Numbers that should be letters
        "0il": "oil",
        "0x": "ox",
        "b0ne": "bone",
        "m1lk": "milk",
        "sa1t": "salt",
        "sug4r": "sugar",
        "wh3y": "whey",
        "3gg": "egg",
        "s0y": "soy",
        "s0ya": "soya",
        "s0dium": "sodium",
        "potas51um": "potassium",
        "chlor1de": "chloride",
        
        // l/I confusion
        "Iamb": "lamb",
        "Iver": "liver",
        "Iow": "low",
        "Iess": "less",
        
        // O/0 confusion
        "pr0tein": "protein",
        "pr0duct": "product",
        "f00d": "food",
        "d0g": "dog",
        "cat": "cat",
        "c0ntains": "contains",
        
        // S/5 confusion
        "5odium": "sodium",
        "5alt": "salt",
        "5ugar": "sugar",
    ]
    
    // MARK: - Public Methods
    
    /**
     * Corrects common OCR errors in text
     * 
     * - Parameter text: Raw OCR text from nutritional label
     * - Returns: Corrected text with spelling errors fixed
     * 
     * Process:
     * 1. Split text into words
     * 2. Check each word against correction dictionary
     * 3. Apply corrections while preserving case
     * 4. Reassemble text
     */
    static func correctText(_ text: String) -> String {
        var correctedText = text
        
        // Sort corrections by length (longest first) to avoid partial replacements
        let sortedCorrections = corrections.sorted { $0.key.count > $1.key.count }
        
        for (incorrect, correct) in sortedCorrections {
            // Case-insensitive replacement while preserving original case
            correctedText = replacePreservingCase(
                in: correctedText,
                target: incorrect,
                replacement: correct
            )
        }
        
        // Additional cleanup: fix common patterns
        correctedText = fixCommonPatterns(correctedText)
        
        return correctedText
    }
    
    /**
     * Corrects an array of ingredient strings
     * 
     * - Parameter ingredients: Array of ingredient strings
     * - Returns: Array with corrected ingredient spellings
     */
    static func correctIngredients(_ ingredients: [String]) -> [String] {
        return ingredients.map { ingredient in
            correctText(ingredient)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /**
     * Replace text while preserving original case
     * 
     * - Parameters:
     *   - text: Original text
     *   - target: String to find and replace
     *   - replacement: Replacement string
     * - Returns: Text with replacements made, preserving case
     */
    private static func replacePreservingCase(
        in text: String,
        target: String,
        replacement: String
    ) -> String {
        var result = text
        
        // Try exact match (case-sensitive)
        result = result.replacingOccurrences(of: target, with: replacement)
        
        // Try lowercase match
        let lowercaseTarget = target.lowercased()
        let regex = try? NSRegularExpression(
            pattern: "\\b\(NSRegularExpression.escapedPattern(for: lowercaseTarget))\\b",
            options: .caseInsensitive
        )
        
        if let regex = regex {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range)
            
            // Process matches in reverse to maintain indices
            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: result) {
                    let originalCase = result[matchRange]
                    let corrected = preserveCase(
                        original: String(originalCase),
                        correction: replacement
                    )
                    result.replaceSubrange(matchRange, with: corrected)
                }
            }
        }
        
        return result
    }
    
    /**
     * Preserve original capitalization pattern
     * 
     * - Parameters:
     *   - original: Original string with case pattern
     *   - correction: Correction to apply
     * - Returns: Correction with original case pattern applied
     */
    private static func preserveCase(original: String, correction: String) -> String {
        // If original is all uppercase, return correction in uppercase
        if original == original.uppercased() {
            return correction.uppercased()
        }
        
        // If original starts with uppercase, capitalize correction
        if original.first?.isUppercase == true {
            return correction.prefix(1).uppercased() + correction.dropFirst().lowercased()
        }
        
        // Otherwise, return lowercase
        return correction.lowercased()
    }
    
    /**
     * Fix common OCR patterns that aren't single-word replacements
     * 
     * - Parameter text: Text to fix
     * - Returns: Text with pattern-based corrections
     */
    private static func fixCommonPatterns(_ text: String) -> String {
        var result = text
        
        // Fix spacing around parentheses (common OCR issue)
        result = result.replacingOccurrences(of: "( ", with: "(")
        result = result.replacingOccurrences(of: " )", with: ")")
        
        // Fix spacing around commas
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: ",(?! )", with: ", ", options: .regularExpression)
        
        // Fix double spaces
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        // Fix common percent sign issues
        result = result.replacingOccurrences(of: "°/°", with: "%")
        result = result.replacingOccurrences(of: "℅", with: "%")
        
        // Fix common weight unit issues
        result = result.replacingOccurrences(of: "rng", with: "mg")
        result = result.replacingOccurrences(of: "rnl", with: "ml")
        result = result.replacingOccurrences(of: "k9", with: "kg")
        
        return result
    }
    
    /**
     * Calculate confidence score for correction
     * 
     * - Parameters:
     *   - original: Original word
     *   - corrected: Corrected word
     * - Returns: Confidence score (0.0 to 1.0)
     * 
     * Higher confidence = more similar strings = likely correct
     */
    private static func correctionConfidence(original: String, corrected: String) -> Double {
        let distance = levenshteinDistance(original.lowercased(), corrected.lowercased())
        let maxLength = max(original.count, corrected.count)
        
        guard maxLength > 0 else { return 0.0 }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /**
     * Calculate Levenshtein distance between two strings
     * 
     * - Parameters:
     *   - s1: First string
     *   - s2: Second string
     * - Returns: Edit distance between strings
     */
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let empty = [Int](repeating: 0, count: s2.count)
        var last = [Int](0...s2.count)
        
        for (i, char1) in s1.enumerated() {
            var current = [i + 1] + empty
            for (j, char2) in s2.enumerated() {
                current[j + 1] = char1 == char2 ?
                    last[j] :
                    Swift.min(last[j], last[j + 1], current[j]) + 1
            }
            last = current
        }
        
        return last.last ?? 0
    }
}

// MARK: - Public Extensions

extension OCRSpellChecker {
    /**
     * Get list of all known correct ingredient terms
     * Useful for validation and autocomplete
     */
    static var knownIngredients: Set<String> {
        let allCorrections = Set(corrections.values)
        return allCorrections
    }
    
    /**
     * Check if a word is likely misspelled
     * 
     * - Parameter word: Word to check
     * - Returns: True if word matches a known misspelling pattern
     */
    static func isLikelyMisspelled(_ word: String) -> Bool {
        return corrections.keys.contains(word.lowercased())
    }
    
    /**
     * Get suggestion for a potentially misspelled word
     * 
     * - Parameter word: Word to get suggestion for
     * - Returns: Suggested correction, or nil if no correction needed
     */
    static func suggestion(for word: String) -> String? {
        return corrections[word.lowercased()]
    }
}

