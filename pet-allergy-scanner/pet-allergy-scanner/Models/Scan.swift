//
//  Scan.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Scan data model representing a scan record
struct Scan: Codable, Identifiable {
    let id: String
    let userId: String
    let petId: String
    let imageUrl: String?
    let rawText: String?
    let status: ScanStatus
    let result: ScanResult?
    let createdAt: Date
    let updatedAt: Date
    
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
struct ScanResult: Codable {
    let productName: String?
    let brand: String?
    let ingredientsFound: [String]
    let unsafeIngredients: [String]
    let safeIngredients: [String]
    let overallSafety: String
    let confidenceScore: Double
    let analysisDetails: [String: String]
    
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
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case extractedText = "extracted_text"
        case productName = "product_name"
    }
}
