//
//  OCRService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
@preconcurrency import Vision
import UIKit
import Combine
import Observation
import RegexBuilder

/// Nutritional analysis data structure
struct NutritionalAnalysis: Codable, Equatable, Hashable {
    var servingSizeG: Double?
    var caloriesPerServing: Double?
    var caloriesPer100G: Double?
    var proteinPercent: Double?
    var fatPercent: Double?
    var fiberPercent: Double?
    var moisturePercent: Double?
    var ashPercent: Double?
    var calciumPercent: Double?
    var phosphorusPercent: Double?
}

/// OCR service for extracting text from images using Apple's Vision framework
@Observable
@MainActor
class OCRService: @unchecked Sendable {
    static let shared = OCRService()
    
    var isProcessing = false
    var extractedText = ""
    var errorMessage: String?
    var nutritionalAnalysis: NutritionalAnalysis?
    
    private init() {}
    
    /// Extract text from UIImage using Vision framework with optimized settings
    func extractText(from image: UIImage) {
        isProcessing = true
        errorMessage = nil
        extractedText = ""
        
        // Optimize image for better OCR performance
        guard let optimizedImage = PerformanceOptimizer.optimizeImageForOCR(image),
              let preprocessedImage = PerformanceOptimizer.preprocessImageForOCR(optimizedImage),
              let cgImage = preprocessedImage.cgImage else {
            Task { @MainActor in
                self.isProcessing = false
                self.errorMessage = LocalizationKeys.invalidImage.localized
            }
            return
        }
        
        // Perform OCR asynchronously
        Task {
            do {
                let extractedText = try await performOCR(on: cgImage)
                
                await MainActor.run {
                    self.isProcessing = false
                    
                    if extractedText.isEmpty {
                        self.errorMessage = LocalizationKeys.noTextFound.localized
                    } else {
                        self.extractedText = extractedText
                        self.errorMessage = nil
                        // Extract nutritional information from the text
                        self.nutritionalAnalysis = self.extractNutritionalInfo(from: extractedText)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = LocalizationKeys.ocrFailed.localized(error.localizedDescription)
                }
            }
        }
    }
    
    /// Perform OCR on CGImage asynchronously (nonisolated)
    private nonisolated func performOCR(on cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                // Enhanced text extraction with confidence filtering
                let extractedText = observations.compactMap { observation in
                    // Get multiple candidates and choose the best one
                    let candidates = observation.topCandidates(3)
                    return candidates.first { $0.confidence > 0.5 }?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: extractedText)
            }
            
            // Optimize for ingredient label scanning
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.03 // Minimum text height for better accuracy
            request.customWords = ["ingredients", "chicken", "beef", "salmon", "rice", "wheat", "corn", "soy"] // Common pet food terms
            
            // Enhanced image processing options
            let options: [VNImageOption: Any] = [:]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: options)
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Extract text from image data
    func extractText(from imageData: Data) {
        guard let image = UIImage(data: imageData) else {
            Task { @MainActor in
                self.isProcessing = false
                self.errorMessage = LocalizationKeys.invalidImageData.localized
            }
            return
        }
        
        extractText(from: image)
    }
    
    /**
     * Extract brand name from OCR text
     * Looks for brand indicators like trademark symbols, common brand keywords,
     * and assumes brand is typically in the first few lines
     */
    func extractBrand(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !lines.isEmpty else { return nil }
        
        // Common pet food brands (could be expanded)
        let knownBrands = [
            "purina", "blue buffalo", "hill's", "royal canin", "iams", "pedigree",
            "wellness", "taste of the wild", "orijen", "acana", "nutro", "merrick",
            "natural balance", "canidae", "solid gold", "fromm", "zignature",
            "instinct", "stella & chewy's", "primal", "weruva", "tiki cat",
            "fancy feast", "friskies", "meow mix", "9 lives", "sheba"
        ]
        
        // Look for brand indicators in first 5 lines
        for i in 0..<min(5, lines.count) {
            let line = lines[i]
            let lowercasedLine = line.lowercased()
            
            // Check if line contains trademark symbols (®, ™, ©)
            if line.contains("®") || line.contains("™") || line.contains("©") {
                // Extract brand name (remove trademark symbols and clean up)
                let brandName = line
                    .replacingOccurrences(of: "®", with: "")
                    .replacingOccurrences(of: "™", with: "")
                    .replacingOccurrences(of: "©", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // If it's reasonably short, it's likely a brand
                if brandName.count <= 30 && brandName.count >= 2 {
                    return brandName
                }
            }
            
            // Check for all-caps words (common brand indicator)
            let words = line.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            for word in words {
                // Check if word is all uppercase (excluding punctuation)
                let alphaNumericOnly = word.filter { $0.isLetter || $0.isNumber }
                
                if !alphaNumericOnly.isEmpty &&
                   alphaNumericOnly == alphaNumericOnly.uppercased() &&
                   alphaNumericOnly.count >= 2 &&
                   alphaNumericOnly.count <= 30 {
                    
                    // Exclude common section headers
                    let excludedWords = [
                        "INGREDIENTS", "INGREDIENT", "GUARANTEED", "ANALYSIS",
                        "NUTRITIONAL", "FACTS", "FEEDING", "DIRECTIONS",
                        "CALORIE", "CONTENT", "NET", "WEIGHT", "DISTRIBUTED",
                        "MANUFACTURED", "FOR", "DOGS", "CATS", "FOOD", "TREATS"
                    ]
                    
                    if !excludedWords.contains(alphaNumericOnly.uppercased()) {
                        // Clean up the word (remove special characters from edges)
                        let cleanedWord = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                        
                        // Check if it's part of a multi-word all-caps brand
                        let allCapsWords = words.filter { word in
                            let alphaOnly = word.filter { $0.isLetter || $0.isNumber }
                            return !alphaOnly.isEmpty &&
                                   alphaOnly == alphaOnly.uppercased() &&
                                   alphaOnly.count >= 2 &&
                                   !excludedWords.contains(alphaOnly.uppercased())
                        }.map { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }
                        
                        if allCapsWords.count >= 1 && allCapsWords.count <= 3 {
                            // Return the combined brand name (e.g., "BLUE BUFFALO", "TASTE OF THE WILD")
                            return allCapsWords.joined(separator: " ")
                        } else if !cleanedWord.isEmpty {
                            return cleanedWord
                        }
                    }
                }
            }
            
            // Check against known brands
            for knownBrand in knownBrands {
                if lowercasedLine.contains(knownBrand) {
                    // Extract the brand name from the line
                    let words = line.components(separatedBy: .whitespaces)
                    if let brandIndex = words.firstIndex(where: { $0.lowercased().contains(knownBrand) }) {
                        // Try to get the brand name (might be multiple words)
                        var brandWords = [words[brandIndex]]
                        
                        // Check if it's a multi-word brand (e.g., "Blue Buffalo", "Taste of the Wild")
                        if brandIndex + 1 < words.count && knownBrand.contains(" ") {
                            let nextWord = words[brandIndex + 1]
                            if knownBrand.lowercased().contains(nextWord.lowercased()) {
                                brandWords.append(nextWord)
                            }
                        }
                        
                        return brandWords.joined(separator: " ").capitalized
                    }
                }
            }
            
            // If first line is short and doesn't look like a section header, it might be the brand
            if i == 0 && line.count <= 30 && !line.lowercased().contains("ingredient") &&
               !line.lowercased().contains("guaranteed") && !line.lowercased().contains("analysis") {
                // Remove common non-brand words
                let cleanedLine = line
                    .replacingOccurrences(of: "For Dogs", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "For Cats", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "Dog Food", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "Cat Food", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !cleanedLine.isEmpty && cleanedLine.count >= 2 {
                    return cleanedLine
                }
            }
        }
        
        return nil
    }
    
    /// Process extracted text to find ingredients with section-aware parsing
    /// Looks for section headers (bold labels) like "Ingredients:" to identify what to parse
    func processIngredients(from text: String) -> [String] {
        // Section headers that indicate ingredients follow
        let ingredientHeaders = [
            "ingredients:",
            "ingredients",
            "ingredient list:",
            "ingredient list"
        ]
        
        // Section headers that indicate we've left the ingredients section
        let stopHeaders = [
            "guaranteed analysis",
            "nutritional",
            "feeding",
            "directions",
            "questions",
            "distributed by",
            "manufactured",
            "net weight",
            "calorie content"
        ]
        
        let lines = text.components(separatedBy: .newlines)
        var ingredients: [String] = []
        var inIngredientSection = false
        var ingredientText = ""
        
        // First pass: Find the ingredients section
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedLine = trimmedLine.lowercased()
            
            // Check if we hit an ingredient header
            if ingredientHeaders.contains(where: { lowercasedLine.starts(with: $0) }) {
                inIngredientSection = true
                // Extract any ingredients on the same line as the header
                if let colonIndex = trimmedLine.firstIndex(of: ":") {
                    let afterColon = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                    if !afterColon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ingredientText += afterColon + " "
                    }
                }
                continue
            }
            
            // Check if we've left the ingredients section
            if inIngredientSection && stopHeaders.contains(where: { lowercasedLine.contains($0) }) {
                break
            }
            
            // Collect ingredient lines
            if inIngredientSection && !trimmedLine.isEmpty {
                ingredientText += trimmedLine + " "
            }
        }
        
        // If no section header found, fall back to looking for comma-separated lists
        if ingredientText.isEmpty {
            ingredientText = findLikelyIngredientText(from: text)
        }
        
        // Parse the ingredient text
        ingredients = parseIngredientList(from: ingredientText)
        
        return ingredients
    }
    
    /**
     * Find likely ingredient text when no clear section header exists
     * Looks for lines with lots of commas (typical of ingredient lists)
     */
    private func findLikelyIngredientText(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var bestLine = ""
        var maxCommas = 3 // Ingredient lists typically have 3+ commas
        
        for line in lines {
            let commaCount = line.filter { $0 == "," }.count
            if commaCount > maxCommas {
                maxCommas = commaCount
                bestLine = line
            }
        }
        
        return bestLine
    }
    
    /**
     * Correct common OCR character misreads
     * Fixes typical Vision framework errors
     */
    private func correctOCRErrors(in text: String) -> String {
        var corrected = text
        
        // Common character substitutions
        let corrections: [(pattern: String, replacement: String)] = [
            // Period instead of comma in ingredient lists
            (". ", ", "),
            
            // Common letter misreads in ingredient context
            ("Chickcn", "Chicken"),
            ("Turkcy", "Turkey"),
            ("Bcef", "Beef"),
            ("Bcans", "Beans"),
            ("Swccl", "Sweet"),
            ("Polatocs", "Potatoes"),
            ("Poraloes", "Potatoes"),
            ("Carr.ls", "Carrots"),
            ("Carr0ls", "Carrots"),
            ("Peacl", "Peanut"),
            ("Flarseed", "Flaxseed"),
            ("Flarsecd", "Flaxseed"),
            ("Fl.rseed", "Flaxseed"),
            
            // Common oil/protein misreads
            ("Canola Oil", "Canola Oil"),
            ("Can.la Oil", "Canola Oil"),
            ("Salm.n", "Salmon"),
            ("Salm0n", "Salmon"),
            
            // Vitamin/mineral common errors
            ("Vilamin", "Vitamin"),
            ("Vilarnin", "Vitamin"),
            ("Calciurn", "Calcium"),
            ("Calc.um", "Calcium"),
            ("Phosp", "Phosph")
        ]
        
        for (pattern, replacement) in corrections {
            corrected = corrected.replacingOccurrences(of: pattern, with: replacement, options: .caseInsensitive)
        }
        
        return corrected
    }
    
    /**
     * Apply pattern-based OCR corrections
     * Fixes systematic character substitution errors
     */
    private func applyPatternCorrections(to ingredient: String) -> String {
        var corrected = ingredient
        
        // Fix common systematic errors
        // "r" misread as "x" pattern (e.g., "Exrract" -> "Extract")
        if corrected.lowercased().contains("rx") || corrected.lowercased().contains("xr") {
            corrected = corrected.replacingOccurrences(of: "rx", with: "xt", options: .caseInsensitive)
            corrected = corrected.replacingOccurrences(of: "xr", with: "xt", options: .caseInsensitive)
        }
        
        // "l" misread as "t" pattern (e.g., "Walet" -> "Water")
        if corrected.count > 3 {
            // Check for unlikely "let" at end (should be "ter")
            if corrected.lowercased().hasSuffix("let") {
                let range = corrected.index(corrected.endIndex, offsetBy: -3)..<corrected.endIndex
                corrected.replaceSubrange(range, with: "ter")
            }
            
            // Check for unlikely "tal" (should be "tat")
            corrected = corrected.replacingOccurrences(of: "tal", with: "tat", options: .caseInsensitive)
        }
        
        // Fix period misreads in middle of words
        if corrected.contains(".") && !corrected.hasSuffix(".") {
            // If period is in middle of word, it's likely an OCR error
            let parts = corrected.components(separatedBy: ".")
            if parts.count == 2 && !parts[1].isEmpty {
                corrected = parts.joined()
            }
        }
        
        return corrected
    }
    
    /**
     * Validate against known pet food ingredients
     * Returns corrected version if close match found
     */
    private func matchKnownIngredient(_ ingredient: String) -> String {
        let knownIngredients = [
            // Proteins
            "chicken", "turkey", "beef", "lamb", "salmon", "fish", "duck", "pork",
            "chicken meal", "turkey meal", "beef meal", "fish meal", "salmon meal",
            
            // Grains & Carbs
            "rice", "brown rice", "white rice", "oats", "barley", "wheat",
            "corn", "quinoa", "millet",
            
            // Vegetables
            "peas", "carrots", "sweet potato", "potato", "potatoes",
            "green beans", "broccoli", "spinach", "pumpkin",
            
            // Legumes
            "lentils", "chickpeas", "beans", "pea flour", "pea protein",
            
            // Oils & Fats
            "canola oil", "sunflower oil", "fish oil", "chicken fat",
            "flaxseed", "salmon oil",
            
            // Other common
            "egg", "eggs", "cheese", "yogurt", "cranberries", "blueberries",
            "apples", "kelp", "alfalfa", "rosemary extract"
        ]
        
        let lowercased = ingredient.lowercased()
        
        // Exact match
        if knownIngredients.contains(lowercased) {
            return ingredient
        }
        
        // Fuzzy match (2 character difference tolerance)
        for known in knownIngredients {
            if levenshteinDistance(lowercased, known) <= 2 {
                // Return properly capitalized version
                return known.capitalized
            }
        }
        
        return ingredient
    }
    
    /**
     * Calculate Levenshtein distance between two strings
     * Used for fuzzy matching of ingredient names
     */
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1)
        let s2 = Array(s2)
        var distance = Array(repeating: Array(repeating: 0, count: s2.count + 1), count: s1.count + 1)
        
        for i in 0...s1.count {
            distance[i][0] = i
        }
        
        for j in 0...s2.count {
            distance[0][j] = j
        }
        
        for i in 1...s1.count {
            for j in 1...s2.count {
                if s1[i-1] == s2[j-1] {
                    distance[i][j] = distance[i-1][j-1]
                } else {
                    distance[i][j] = min(
                        distance[i-1][j] + 1,    // deletion
                        distance[i][j-1] + 1,    // insertion
                        distance[i-1][j-1] + 1   // substitution
                    )
                }
            }
        }
        
        return distance[s1.count][s2.count]
    }
    
    /**
     * Parse ingredient list from text
     * Splits by commas and cleans up each ingredient
     */
    private func parseIngredientList(from text: String) -> [String] {
        var ingredients: [String] = []
        
        // Skip words that aren't ingredients
        let skipWords = [
            "min", "max", "crude", "preservatives", "vitamins", "minerals",
            "contains", "derived", "source", "naturally", "occurring",
            "microorganisms", "supplement", "extract", "product"
        ]
        
        // First, apply OCR error corrections to the entire text
        let correctedText = correctOCRErrors(in: text)
        
        // Split by commas first
        let parts = correctedText.components(separatedBy: ",")
        
        for part in parts {
            var cleaned = part.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove parenthetical notes like "(preserved with...)"
            if let openParen = cleaned.firstIndex(of: "("),
               let closeParen = cleaned.lastIndex(of: ")") {
                let beforeParen = cleaned[..<openParen]
                let afterParen = cleaned.index(after: closeParen) < cleaned.endIndex ? cleaned[cleaned.index(after: closeParen)...] : ""
                cleaned = String(beforeParen) + String(afterParen)
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Remove trailing punctuation
            cleaned = cleaned.trimmingCharacters(in: .punctuationCharacters)
            
            // Filter out non-ingredients
            let lowercased = cleaned.lowercased()
            if cleaned.isEmpty ||
               cleaned.count < 3 ||
               cleaned.count > 60 ||
               cleaned.allSatisfy({ $0.isNumber }) ||
               skipWords.contains(where: { lowercased.contains($0) && cleaned.count < 15 }) {
                continue
            }
            
            // Apply pattern-based corrections (fix systematic OCR errors)
            cleaned = applyPatternCorrections(to: cleaned)
            
            // Try to match against known ingredients (fuzzy matching)
            cleaned = matchKnownIngredient(cleaned)
            
            // Final capitalization
            cleaned = cleaned.capitalized
            
            ingredients.append(cleaned)
        }
        
        // Remove duplicates while preserving order
        var uniqueIngredients: [String] = []
        var seen: Set<String> = []
        
        for ingredient in ingredients {
            let lowercased = ingredient.lowercased()
            if !seen.contains(lowercased) {
                seen.insert(lowercased)
                uniqueIngredients.append(ingredient)
            }
        }
        
        return uniqueIngredients
    }
    
    /// Extract nutritional information from OCR text using section-aware parsing
    /// Looks for section headers like "Guaranteed Analysis" or "Calorie Content"
    func extractNutritionalInfo(from text: String) -> NutritionalAnalysis {
        var analysis = NutritionalAnalysis()
        
        // Section headers that indicate nutritional data
        let nutritionalHeaders = [
            "guaranteed analysis",
            "nutritional facts",
            "nutrition facts",
            "calorie content",
            "typical analysis"
        ]
        
        let lines = text.components(separatedBy: .newlines)
        var inNutritionalSection = false
        var linesAfterHeader = 0
        let maxLinesInSection = 15 // Nutritional sections are typically 10-15 lines
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedLine = trimmedLine.lowercased()
            
            // Check if we hit a nutritional header
            if nutritionalHeaders.contains(where: { lowercasedLine.contains($0) }) {
                inNutritionalSection = true
                linesAfterHeader = 0
                continue
            }
            
            // If we're in the nutritional section, extract values
            if inNutritionalSection {
                linesAfterHeader += 1
                
                // Stop if we've gone too far (hit next section)
                if linesAfterHeader > maxLinesInSection {
                    inNutritionalSection = false
                    continue
                }
                
                // Extract serving size (in grams)
                if let servingSize = extractServingSize(from: trimmedLine) {
                    analysis.servingSizeG = servingSize
                }
                
                // Extract calories - check for various formats
                if let calories = extractCalories(from: trimmedLine) {
                    // Per treat/serving patterns
                    if lowercasedLine.contains("per serving") || 
                       lowercasedLine.contains("per cup") || 
                       lowercasedLine.contains("per treat") ||
                       lowercasedLine.contains("/treat") ||
                       lowercasedLine.contains("kcal/treat") {
                        analysis.caloriesPerServing = calories
                    }
                    // Per 100g or per kg patterns
                    else if lowercasedLine.contains("per 100g") || 
                            lowercasedLine.contains("per 100 g") || 
                            lowercasedLine.contains("/kg") ||
                            lowercasedLine.contains("kcal/kg") {
                        // Convert kcal/kg to kcal/100g
                        if lowercasedLine.contains("/kg") || lowercasedLine.contains("kcal/kg") {
                            analysis.caloriesPer100G = calories / 10.0
                        } else {
                            analysis.caloriesPer100G = calories
                        }
                    }
                    // Default: if we have calories but no unit specified, try to be smart
                    else if analysis.caloriesPerServing == nil && analysis.caloriesPer100G == nil {
                        // If it's a small number (< 100), likely per serving/treat
                        // If it's a large number (> 200), likely per 100g or needs conversion
                        if calories < 100 {
                            analysis.caloriesPerServing = calories
                        } else if calories > 1000 {
                            // Likely kcal/kg format
                            analysis.caloriesPer100G = calories / 10.0
                        } else {
                            // Ambiguous - store as per 100g
                            analysis.caloriesPer100G = calories
                        }
                    }
                }
                
                // Extract protein percentage (look for "min" indicator)
                if let protein = extractNutrientValue(from: trimmedLine, patterns: ["protein", "crude protein"]) {
                    analysis.proteinPercent = protein
                }
                
                // Extract fat percentage
                if let fat = extractNutrientValue(from: trimmedLine, patterns: ["fat", "crude fat", "lipid"]) {
                    analysis.fatPercent = fat
                }
                
                // Extract fiber percentage (look for "max" indicator)
                if let fiber = extractNutrientValue(from: trimmedLine, patterns: ["fiber", "crude fiber", "dietary fiber"]) {
                    analysis.fiberPercent = fiber
                }
                
                // Extract moisture percentage
                if let moisture = extractNutrientValue(from: trimmedLine, patterns: ["moisture", "water"]) {
                    analysis.moisturePercent = moisture
                }
                
                // Extract ash percentage
                if let ash = extractNutrientValue(from: trimmedLine, patterns: ["ash", "crude ash"]) {
                    analysis.ashPercent = ash
                }
                
                // Extract calcium percentage
                if let calcium = extractNutrientValue(from: trimmedLine, patterns: ["calcium", "ca"]) {
                    analysis.calciumPercent = calcium
                }
                
                // Extract phosphorus percentage
                if let phosphorus = extractNutrientValue(from: trimmedLine, patterns: ["phosphorus", "phosphorous", "p"]) {
                    analysis.phosphorusPercent = phosphorus
                }
            }
        }
        
        // Calculate calories per 100g if we have serving size and calories per serving
        if let servingSize = analysis.servingSizeG,
           let caloriesPerServing = analysis.caloriesPerServing,
           analysis.caloriesPer100G == nil {
            analysis.caloriesPer100G = (caloriesPerServing / servingSize) * 100
        }
        
        return analysis
    }
    
    /// Extract serving size from text
    private func extractServingSize(from text: String) -> Double? {
        let patterns = [
            #"(\d+(?:\.\d+)?)\s*(?:g|grams?|g\.)"#,
            #"serving size[:\s]*(\d+(?:\.\d+)?)\s*(?:g|grams?|g\.)"#,
            #"(\d+(?:\.\d+)?)\s*(?:oz|ounces?)"# // Convert ounces to grams (1 oz = 28.35g)
        ]
        
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                let numberPattern = #"(\d+(?:\.\d+)?)"#
                if let numberMatch = matchedText.range(of: numberPattern, options: .regularExpression) {
                    let numberString = String(matchedText[numberMatch])
                    if let value = Double(numberString) {
                        // Convert ounces to grams if needed
                        if pattern.contains("oz") {
                            return value * 28.35
                        }
                        return value
                    }
                }
            }
        }
        return nil
    }
    
    /// Extract calories from text
    /**
     * Extract calorie value from text
     * Handles formats like: "16 kcal/treat", "380 kcal per 100g", "3,013 kcal/kg"
     */
    private func extractCalories(from text: String) -> Double? {
        let patterns = [
            // Format: "16 kcal/treat" or "16 kcal / treat"
            #"(\d+(?:,\d{3})*(?:\.\d+)?)\s*(?:kcal|calories?|cal)\s*\/?\s*(?:treat|serving|cup|kg|100\s*g)?"#,
            // Format: "16 kcal per treat"
            #"(\d+(?:,\d{3})*(?:\.\d+)?)\s*(?:kcal|calories?|cal)\s*per"#,
            // Format: "Calorie Content: 16 kcal"
            #"(\d+(?:,\d{3})*(?:\.\d+)?)\s*(?:kcal|calories?|cal)"#
        ]
        
        for pattern in patterns {
            if let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matchedText = String(text[match])
                // Extract just the number (including comma-separated thousands)
                let numberPattern = #"(\d+(?:,\d{3})*(?:\.\d+)?)"#
                if let numberMatch = matchedText.range(of: numberPattern, options: .regularExpression) {
                    var numberString = String(matchedText[numberMatch])
                    // Remove commas from numbers like "3,013"
                    numberString = numberString.replacingOccurrences(of: ",", with: "")
                    return Double(numberString)
                }
            }
        }
        return nil
    }
    
    /// Extract nutrient value from text using multiple patterns
    private func extractNutrientValue(from text: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            let regexPattern = #"(\d+(?:\.\d+)?)\s*(?:%|percent|percentages?)\s*(?:"# + pattern + #")"#
            if let match = text.range(of: regexPattern, options: .regularExpression) {
                let matchedText = String(text[match])
                let numberPattern = #"(\d+(?:\.\d+)?)"#
                if let numberMatch = matchedText.range(of: numberPattern, options: .regularExpression) {
                    let numberString = String(matchedText[numberMatch])
                    return Double(numberString)
                }
            }
        }
        return nil
    }
    
    /// Clear extracted text and error
    func clearResults() {
        extractedText = ""
        errorMessage = nil
        nutritionalAnalysis = nil
    }
}
