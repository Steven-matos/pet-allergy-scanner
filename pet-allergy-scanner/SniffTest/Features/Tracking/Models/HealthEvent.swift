//
//  HealthEvent.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import SwiftUI

/**
 * Health Event Model
 * 
 * Represents a health event for a pet including vomiting, shedding, vaccinations, etc.
 * Follows SOLID principles with single responsibility for health event data
 * Implements DRY by reusing common patterns from other models
 * Follows KISS by keeping the model simple and focused
 */
struct HealthEvent: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let petId: String
    let userId: String
    let eventType: HealthEventType
    let eventCategory: HealthEventCategory
    let title: String
    let notes: String?
    let severityLevel: Int
    let eventDate: Date
    let createdAt: Date
    let updatedAt: Date
    
    /// Validation for health event data
    var isValid: Bool {
        return !id.isEmpty && !petId.isEmpty && !userId.isEmpty && !title.isEmpty && title.count >= 1
    }
    
    /// Display severity level as text
    var severityDescription: String {
        switch severityLevel {
        case 1: return "Mild"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "High"
        case 5: return "Severe"
        default: return "Unknown"
        }
    }
    
    /// Color for severity level
    var severityColor: String {
        switch severityLevel {
        case 1: return "#4CAF50" // Green
        case 2: return "#8BC34A" // Light Green
        case 3: return "#FF9800" // Orange
        case 4: return "#FF5722" // Deep Orange
        case 5: return "#F44336" // Red
        default: return "#9E9E9E" // Grey
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case petId = "pet_id"
        case userId = "user_id"
        case eventType = "event_type"
        case eventCategory = "event_category"
        case title
        case notes
        case severityLevel = "severity_level"
        case eventDate = "event_date"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/**
 * Health Event Type Enumeration
 * 
 * Defines the types of health events that can be tracked
 * Simplified to 8 core types plus "Other" for custom events
 */
enum HealthEventType: String, Codable, CaseIterable {
    case vomiting = "vomiting"
    case diarrhea = "diarrhea"
    case shedding = "shedding"
    case lowEnergy = "low_energy"
    case vaccination = "vaccination"
    case vetVisit = "vet_visit"
    case medication = "medication"
    case anxiety = "anxiety"
    case other = "other"
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .vomiting: return "Vomiting"
        case .diarrhea: return "Diarrhea"
        case .shedding: return "Shedding"
        case .lowEnergy: return "Low Energy"
        case .vaccination: return "Vaccination"
        case .vetVisit: return "Vet Visit"
        case .medication: return "Medication"
        case .anxiety: return "Anxiety"
        case .other: return "Other"
        }
    }
    
    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .vomiting: return "exclamationmark.triangle"
        case .diarrhea: return "toilet"
        case .shedding: return "leaf"
        case .lowEnergy: return "battery.25"
        case .vaccination: return "syringe"
        case .vetVisit: return "cross.case"
        case .medication: return "pills"
        case .anxiety: return "heart"
        case .other: return "plus.circle"
        }
    }
    
    /// Category this event type belongs to
    var category: HealthEventCategory {
        switch self {
        case .vomiting, .diarrhea:
            return .digestive
        case .shedding, .lowEnergy:
            return .physical
        case .vaccination, .vetVisit, .medication:
            return .medical
        case .anxiety:
            return .behavioral
        case .other:
            return .physical // Default for custom events
        }
    }
    
    /// Color code for this event type
    var colorCode: String {
        return category.colorCode
    }
}

/**
 * Health Event Category Enumeration
 * 
 * Groups health events into logical categories for filtering and organization
 */
enum HealthEventCategory: String, Codable, CaseIterable {
    case digestive = "digestive"
    case physical = "physical"
    case medical = "medical"
    case behavioral = "behavioral"
    
    /// Display name for UI
    var displayName: String {
        switch self {
        case .digestive: return "Digestive"
        case .physical: return "Physical"
        case .medical: return "Medical"
        case .behavioral: return "Behavioral"
        }
    }
    
    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .digestive: return "stomach"
        case .physical: return "figure.walk"
        case .medical: return "cross.case"
        case .behavioral: return "heart"
        }
    }
    
    /// Color code for this category
    var colorCode: String {
        switch self {
        case .digestive: return "#FF6B6B" // Red
        case .physical: return "#4ECDC4" // Teal
        case .medical: return "#FECA57" // Yellow
        case .behavioral: return "#A8E6CF" // Light Green
        }
    }
    
    /// SwiftUI Color for this category
    var color: Color {
        return Color(hex: colorCode)
    }
}

/**
 * Health Event Creation Model
 * 
 * Used for creating new health events
 */
struct HealthEventCreate: Codable {
    let petId: String
    let eventType: HealthEventType
    let title: String
    let notes: String?
    let severityLevel: Int
    let eventDate: Date
    
    /// Validation for health event creation
    var isValid: Bool {
        return !petId.isEmpty && !title.isEmpty && title.count >= 1 && severityLevel >= 1 && severityLevel <= 5
    }
    
    /// Validation errors for health event creation
    var validationErrors: [String] {
        var errors: [String] = []
        
        if petId.isEmpty {
            errors.append("Pet ID is required")
        }
        
        if title.isEmpty {
            errors.append("Title is required")
        } else if title.count < 1 {
            errors.append("Title must be at least 1 character")
        }
        
        if severityLevel < 1 || severityLevel > 5 {
            errors.append("Severity level must be between 1 and 5")
        }
        
        return errors
    }
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case eventType = "event_type"
        case title
        case notes
        case severityLevel = "severity_level"
        case eventDate = "event_date"
    }
}

/**
 * Health Event Update Model
 * 
 * Used for updating existing health events
 */
struct HealthEventUpdate: Codable {
    let title: String?
    let notes: String?
    let severityLevel: Int?
    let eventDate: Date?
    
    /// Check if any fields are being updated
    var hasUpdates: Bool {
        return title != nil || notes != nil || severityLevel != nil || eventDate != nil
    }
    
    enum CodingKeys: String, CodingKey {
        case title
        case notes
        case severityLevel = "severity_level"
        case eventDate = "event_date"
    }
}

/**
 * Health Event List Response
 * 
 * Response model for paginated health event lists
 */
struct HealthEventListResponse: Codable {
    let events: [HealthEvent]
    let total: Int
    let limit: Int
    let offset: Int
    
    /// Check if there are more events to load
    var hasMore: Bool {
        return offset + events.count < total
    }
    
    /// Get next page offset
    var nextOffset: Int {
        return offset + events.count
    }
}
