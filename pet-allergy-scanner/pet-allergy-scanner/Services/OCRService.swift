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

/// OCR service for extracting text from images using Apple's Vision framework
@Observable
class OCRService {
    static let shared = OCRService()
    
    var isProcessing = false
    var extractedText = ""
    var errorMessage: String?
    
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
                }
            }
        }
        
        // Optimize for ingredient label scanning
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.03 // Minimum text height for better accuracy
        request.customWords = ["ingredients", "chicken", "beef", "salmon", "rice", "wheat", "corn", "soy"] // Common pet food terms
        
        // Enhanced image processing options
        let options: [VNImageOption: Any] = [
            .cameraIntrinsics: image.cameraIntrinsics as Any
        ]
        
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
    
    /// Clear extracted text and error
    func clearResults() {
        extractedText = ""
        errorMessage = nil
    }
}
