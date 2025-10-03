//
//  OCRService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Vision
import UIKit
import Combine
import Observation
import RegexBuilder

/// Nutritional analysis data structure
struct NutritionalAnalysis {
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
class OCRService {
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
            DispatchQueue.main.async {
                self.isProcessing = false
                self.errorMessage = LocalizationKeys.invalidImage.localized
            }
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                if let error = error {
                    self?.errorMessage = LocalizationKeys.ocrFailed.localized(error.localizedDescription)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    self?.errorMessage = LocalizationKeys.noTextFound.localized
                    return
                }
                
                // Enhanced text extraction with confidence filtering
                let extractedText = observations.compactMap { observation in
                    // Get multiple candidates and choose the best one
                    let candidates = observation.topCandidates(3)
                    return candidates.first { $0.confidence > 0.5 }?.string
                }.joined(separator: "\n")
                
                if extractedText.isEmpty {
                    self?.errorMessage = LocalizationKeys.noTextFound.localized
                } else {
                    self?.extractedText = extractedText
                    self?.errorMessage = nil
                    // Extract nutritional information from the text
                    self?.nutritionalAnalysis = self?.extractNutritionalInfo(from: extractedText)
                }
            }
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
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = LocalizationKeys.ocrProcessingFailed.localized(error.localizedDescription)
                }
            }
        }
    }
    
    /// Extract text from image data
    func extractText(from imageData: Data) {
        guard let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.errorMessage = LocalizationKeys.invalidImageData.localized
            }
            return
        }
        
        extractText(from: image)
    }
    
    /// Process extracted text to find ingredients with enhanced parsing
    func processIngredients(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var ingredients: [String] = []
        
        // Common non-ingredient keywords to skip
        let skipKeywords = [
            "ingredients", "nutritional", "guaranteed", "analysis", "crude",
            "protein", "fat", "fiber", "moisture", "ash", "calcium", "phosphorus",
            "vitamins", "minerals", "preservatives", "natural", "artificial",
            "calories", "kcal", "feeding", "instructions", "directions",
            "net", "weight", "oz", "lb", "kg", "g", "mg"
        ]
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and lines with common non-ingredient text
            if trimmedLine.isEmpty || 
               skipKeywords.contains(where: { trimmedLine.lowercased().contains($0) }) {
                continue
            }
            
            // Enhanced splitting by multiple separators
            let separators = CharacterSet(charactersIn: ",;()[]")
            let potentialIngredients = trimmedLine.components(separatedBy: separators)
            
            for ingredient in potentialIngredients {
                let cleaned = ingredient
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: .punctuationCharacters)
                
                // More sophisticated filtering
                if !cleaned.isEmpty && 
                   cleaned.count > 2 && 
                   cleaned.count < 50 && // Avoid overly long text
                   !cleaned.allSatisfy({ $0.isNumber }) && // Skip pure numbers
                   !skipKeywords.contains(where: { cleaned.lowercased().contains($0) }) {
                    ingredients.append(cleaned)
                }
            }
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
    
    /// Extract nutritional information from OCR text using regex patterns
    func extractNutritionalInfo(from text: String) -> NutritionalAnalysis {
        var analysis = NutritionalAnalysis()
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercasedLine = trimmedLine.lowercased()
            
            // Extract serving size (in grams)
            if let servingSize = extractServingSize(from: trimmedLine) {
                analysis.servingSizeG = servingSize
            }
            
            // Extract calories
            if let calories = extractCalories(from: trimmedLine) {
                if lowercasedLine.contains("per serving") || lowercasedLine.contains("per cup") {
                    analysis.caloriesPerServing = calories
                } else if lowercasedLine.contains("per 100g") || lowercasedLine.contains("per 100 g") {
                    analysis.caloriesPer100G = calories
                }
            }
            
            // Extract protein percentage
            if let protein = extractNutrientValue(from: trimmedLine, patterns: ["protein", "crude protein"]) {
                analysis.proteinPercent = protein
            }
            
            // Extract fat percentage
            if let fat = extractNutrientValue(from: trimmedLine, patterns: ["fat", "crude fat", "lipid"]) {
                analysis.fatPercent = fat
            }
            
            // Extract fiber percentage
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
    private func extractCalories(from text: String) -> Double? {
        let patterns = [
            #"(\d+(?:\.\d+)?)\s*(?:kcal|calories?|cal)"#,
            #"(\d+(?:\.\d+)?)\s*(?:kcal|calories?|cal)\s*per"#
        ]
        
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
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
