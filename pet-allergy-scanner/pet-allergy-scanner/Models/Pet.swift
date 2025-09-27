//
//  Pet.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Pet data model representing a pet profile
struct Pet: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let species: PetSpecies
    let breed: String?
    let ageMonths: Int?
    let weightKg: Double?
    let knownAllergies: [String]
    let vetName: String?
    let vetPhone: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case species
        case breed
        case ageMonths = "age_months"
        case weightKg = "weight_kg"
        case knownAllergies = "known_allergies"
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

/// Pet creation model for new pet profiles
struct PetCreate: Codable {
    let name: String
    let species: PetSpecies
    let breed: String?
    let ageMonths: Int?
    let weightKg: Double?
    let knownAllergies: [String]
    let vetName: String?
    let vetPhone: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case species
        case breed
        case ageMonths = "age_months"
        case weightKg = "weight_kg"
        case knownAllergies = "known_allergies"
        case vetName = "vet_name"
        case vetPhone = "vet_phone"
    }
}

/// Pet update model for profile updates
struct PetUpdate: Codable {
    let name: String?
    let breed: String?
    let ageMonths: Int?
    let weightKg: Double?
    let knownAllergies: [String]?
    let vetName: String?
    let vetPhone: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case breed
        case ageMonths = "age_months"
        case weightKg = "weight_kg"
        case knownAllergies = "known_allergies"
        case vetName = "vet_name"
        case vetPhone = "vet_phone"
    }
}
