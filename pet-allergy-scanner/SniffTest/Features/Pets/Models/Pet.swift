//
//  Pet.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Pet data model representing a pet profile
struct Pet: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let userId: String
    let name: String
    let species: PetSpecies
    let breed: String?
    let birthday: Date?
    var weightKg: Double?
    let activityLevel: PetActivityLevel?
    let imageUrl: String?
    let knownSensitivities: [String]
    let vetName: String?
    let vetPhone: String?
    let createdAt: Date
    let updatedAt: Date
    
    /// Validation for pet data
    var isValid: Bool {
        return !id.isEmpty && !userId.isEmpty && !name.isEmpty && name.count >= 2
    }
    
    /// Display name for the pet
    var displayName: String {
        if let breed = breed, !breed.isEmpty {
            return "\(name) (\(breed))"
        }
        return name
    }
    
    /// Calculate age in months from birthday
    var ageMonths: Int? {
        guard let birthday = birthday else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: birthday, to: now)
        
        guard let years = components.year, let months = components.month else { return nil }
        return years * 12 + months
    }
    
    /// Calculate age in years from birthday
    var ageYears: Double? {
        guard let birthday = birthday else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: birthday, to: now)
        
        guard let years = components.year, let months = components.month else { return nil }
        return Double(years) + (Double(months) / 12.0)
    }
    
    /// Age description in human-readable format
    var ageDescription: String? {
        guard let ageMonths = ageMonths else { return nil }
        
        if ageMonths < 12 {
            return "\(ageMonths) month\(ageMonths == 1 ? "" : "s") old"
        } else {
            let years = ageMonths / 12
            let remainingMonths = ageMonths % 12
            if remainingMonths == 0 {
                return "\(years) year\(years == 1 ? "" : "s") old"
            } else {
                return "\(years) year\(years == 1 ? "" : "s"), \(remainingMonths) month\(remainingMonths == 1 ? "" : "s") old"
            }
        }
    }
    
    /// Calculate life stage based on age and species
    var lifeStage: PetLifeStage {
        guard let ageMonths = ageMonths else { return .adult }
        
        switch species {
        case .dog:
            if ageMonths < 12 {
                return .puppy
            } else if ageMonths >= 84 { // 7 years for dogs
                return .senior
            } else {
                return .adult
            }
        case .cat:
            if ageMonths < 12 {
                return .puppy
            } else if ageMonths >= 84 { // 7 years for cats
                return .senior
            } else {
                return .adult
            }
        }
    }
    
    /// Get default activity level if not set
    var effectiveActivityLevel: PetActivityLevel {
        return activityLevel ?? .moderate
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case species
        case breed
        case birthday
        case weightKg = "weight_kg"
        case activityLevel = "activity_level"
        case imageUrl = "image_url"
        case knownSensitivities = "known_sensitivities"
        case vetName = "vet_name"
        case vetPhone = "vet_phone"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Pet species enumeration
enum PetSpecies: String, Codable, CaseIterable {
    case dog = "dog"
    case cat = "cat"
    
    var displayName: String {
        switch self {
        case .dog:
            return "Dog"
        case .cat:
            return "Cat"
        }
    }
    
    var icon: String {
        switch self {
        case .dog:
            return "dog.fill"
        case .cat:
            return "cat.fill"
        }
    }
}

/// Pet activity level enumeration
enum PetActivityLevel: String, Codable, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low Activity"
        case .moderate:
            return "Moderate Activity"
        case .high:
            return "High Activity"
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "Indoor, minimal exercise"
        case .moderate:
            return "Regular walks, some play"
        case .high:
            return "Very active, lots of exercise"
        }
    }
}

/// Pet life stage enumeration
enum PetLifeStage: String, Codable, CaseIterable {
    case puppy = "puppy"
    case adult = "adult"
    case senior = "senior"
    case pregnant = "pregnant"
    case lactating = "lactating"
    
    var displayName: String {
        switch self {
        case .puppy:
            return "Puppy/Kitten"
        case .adult:
            return "Adult"
        case .senior:
            return "Senior"
        case .pregnant:
            return "Pregnant"
        case .lactating:
            return "Lactating"
        }
    }
}

/// Pet creation model for new pet profiles
struct PetCreate: Codable {
    let name: String
    let species: PetSpecies
    let breed: String?
    let birthday: Date?
    let weightKg: Double?
    let activityLevel: PetActivityLevel?
    let imageUrl: String?
    let knownSensitivities: [String]
    let vetName: String?
    let vetPhone: String?
    
    /// Validation for pet creation data
    var isValid: Bool {
        return !name.isEmpty && name.count >= 2 && name.count <= 50
    }
    
    /// Validation errors for pet creation
    var validationErrors: [String] {
        var errors: [String] = []
        
        if name.isEmpty {
            errors.append("Pet name is required")
        } else if name.count < 2 {
            errors.append("Pet name must be at least 2 characters")
        } else if name.count > 50 {
            errors.append("Pet name must be less than 50 characters")
        }
        
        if let birthday = birthday, birthday > Date() {
            errors.append("Birthday cannot be in the future")
        }
        
        if let weightKg = weightKg, weightKg <= 0 {
            errors.append("Weight must be positive")
        }
        
        return errors
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case species
        case breed
        case birthday
        case weightKg = "weight_kg"
        case activityLevel = "activity_level"
        case imageUrl = "image_url"
        case knownSensitivities = "known_sensitivities"
        case vetName = "vet_name"
        case vetPhone = "vet_phone"
    }
}

/// Pet update model for profile updates
struct PetUpdate: Codable {
    let name: String?
    let breed: String?
    let birthday: Date?
    let weightKg: Double?
    let activityLevel: PetActivityLevel?
    let imageUrl: String?
    let knownSensitivities: [String]?
    let vetName: String?
    let vetPhone: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case breed
        case birthday
        case weightKg = "weight_kg"
        case activityLevel = "activity_level"
        case imageUrl = "image_url"
        case knownSensitivities = "known_sensitivities"
        case vetName = "vet_name"
        case vetPhone = "vet_phone"
    }
}
