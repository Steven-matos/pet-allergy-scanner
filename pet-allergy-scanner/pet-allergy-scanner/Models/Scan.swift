//
//  Scan.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Scan data model representing a scan record
struct Scan: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let userId: String
    let petId: String
    let imageUrl: String?
    let rawText: String?
    let status: ScanStatus
    let result: ScanResult?
    let createdAt: Date
    let updatedAt: Date
    
    /// Validation for scan data
    var isValid: Bool {
        return !id.isEmpty && !userId.isEmpty && !petId.isEmpty
    }
    
    /// Check if scan has completed analysis
    var hasResult: Bool {
        return result != nil && status == .completed
    }
    
    /// Check if scan is currently processing
    var isProcessing: Bool {
        return status == .processing || status == .pending
    }
    
    /// Check if scan failed
    var hasFailed: Bool {
        return status == .failed
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case petId = "pet_id"
        case imageUrl = "image_url"
        case rawText = "raw_text"
        case status
        case result
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Scan status enumeration
enum ScanStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending"
        case .processing:
            return "Processing"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
}

/// Scan result model containing analysis results
struct ScanResult: Codable, Equatable, Hashable {
    let productName: String?
    let brand: String?
    let ingredientsFound: [String]
    let unsafeIngredients: [String]
    let safeIngredients: [String]
    let overallSafety: String
    let confidenceScore: Double
    let analysisDetails: [String: String]
    
    /// Validation for scan result data
    var isValid: Bool {
        return confidenceScore >= 0.0 && confidenceScore <= 1.0
    }
    
    /// Check if result indicates safety concerns
    var hasSafetyConcerns: Bool {
        return !unsafeIngredients.isEmpty || overallSafety == "unsafe" || overallSafety == "caution"
    }
    
    /// Get primary safety concern message
    var primarySafetyMessage: String? {
        if !unsafeIngredients.isEmpty {
            return "Contains \(unsafeIngredients.count) potentially unsafe ingredient\(unsafeIngredients.count == 1 ? "" : "s")"
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brand
        case ingredientsFound = "ingredients_found"
        case unsafeIngredients = "unsafe_ingredients"
        case safeIngredients = "safe_ingredients"
        case overallSafety = "overall_safety"
        case confidenceScore = "confidence_score"
        case analysisDetails = "analysis_details"
    }
    
    /// Computed property for overall safety color
    var safetyColor: String {
        switch overallSafety {
        case "safe":
            return "green"
        case "caution":
            return "yellow"
        case "unsafe":
            return "red"
        default:
            return "gray"
        }
    }
    
    /// Computed property for overall safety display name
    var safetyDisplayName: String {
        switch overallSafety {
        case "safe":
            return "Safe"
        case "caution":
            return "Caution"
        case "unsafe":
            return "Unsafe"
        default:
            return "Unknown"
        }
    }
}

/// Scan creation model for new scans
struct ScanCreate: Codable {
    let petId: String
    let imageUrl: String?
    let rawText: String?
    let status: ScanStatus
    
    /// Validation for scan creation data
    var isValid: Bool {
        return !petId.isEmpty
    }
    
    /// Validation errors for scan creation
    var validationErrors: [String] {
        var errors: [String] = []
        
        if petId.isEmpty {
            errors.append("Pet ID is required")
        }
        
        if rawText?.isEmpty ?? true && imageUrl?.isEmpty ?? true {
            errors.append("Either image or text data is required")
        }
        
        return errors
    }
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case imageUrl = "image_url"
        case rawText = "raw_text"
        case status
    }
}

/// Scan analysis request model
struct ScanAnalysisRequest: Codable {
    let petId: String
    let extractedText: String
    let productName: String?
    
    /// Validation for analysis request data
    var isValid: Bool {
        return !petId.isEmpty && !extractedText.isEmpty
    }
    
    /// Validation errors for analysis request
    var validationErrors: [String] {
        var errors: [String] = []
        
        if petId.isEmpty {
            errors.append("Pet ID is required")
        }
        
        if extractedText.isEmpty {
            errors.append("Extracted text is required")
        }
        
        return errors
    }
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case extractedText = "extracted_text"
        case productName = "product_name"
    }
}
