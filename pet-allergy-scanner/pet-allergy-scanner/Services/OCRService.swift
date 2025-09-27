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

/// OCR service for extracting text from images using Apple's Vision framework
class OCRService: ObservableObject {
    static let shared = OCRService()
    
    @Published var isProcessing = false
    @Published var extractedText = ""
    @Published var errorMessage: String?
    
    private init() {}
    
    /// Extract text from UIImage using Vision framework
    func extractText(from image: UIImage) {
        isProcessing = true
        errorMessage = nil
        extractedText = ""
        
        guard let cgImage = image.cgImage else {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.errorMessage = "Invalid image"
            }
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                if let error = error {
                    self?.errorMessage = "OCR failed: \(error.localizedDescription)"
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    self?.errorMessage = "No text found in image"
                    return
                }
                
                let extractedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                self?.extractedText = extractedText
                self?.errorMessage = nil
            }
        }
        
        // Configure for high accuracy
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.errorMessage = "OCR processing failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Extract text from image data
    func extractText(from imageData: Data) {
        guard let image = UIImage(data: imageData) else {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.errorMessage = "Invalid image data"
            }
            return
        }
        
        extractText(from: image)
    }
    
    /// Process extracted text to find ingredients
    func processIngredients(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var ingredients: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and common non-ingredient text
            if trimmedLine.isEmpty || 
               trimmedLine.lowercased().contains("ingredients") ||
               trimmedLine.lowercased().contains("nutritional") ||
               trimmedLine.lowercased().contains("guaranteed") {
                continue
            }
            
            // Split by common separators
            let potentialIngredients = trimmedLine.components(separatedBy: CharacterSet(charactersIn: ",;"))
            
            for ingredient in potentialIngredients {
                let cleaned = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty && cleaned.count > 2 {
                    ingredients.append(cleaned)
                }
            }
        }
        
        return ingredients
    }
    
    /// Clear extracted text and error
    func clearResults() {
        extractedText = ""
        errorMessage = nil
    }
}
