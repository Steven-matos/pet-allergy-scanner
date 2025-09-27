//
//  PetModelTests.swift
//  pet-allergy-scannerTests
//
//  Created by Steven Matos on 9/26/25.
//

import Testing
import Foundation
@testable import pet_allergy_scanner

/// Unit tests for Pet model validation and business logic
@Suite("Pet Model Tests")
struct PetModelTests {
    
    /// Test valid pet creation
    @Test("Valid pet creation")
    func testValidPetCreation() {
        let petCreate = PetCreate(
            name: "Buddy",
            species: .dog,
            breed: "Golden Retriever",
            ageMonths: 24,
            weightKg: 25.5,
            knownAllergies: ["chicken", "wheat"],
            vetName: "Dr. Smith",
            vetPhone: "555-0123"
        )
        
        #expect(petCreate.isValid == true)
        #expect(petCreate.validationErrors.isEmpty)
    }
    
    /// Test pet creation with minimum required fields
    @Test("Minimum required fields")
    func testMinimumRequiredFields() {
        let petCreate = PetCreate(
            name: "Fluffy",
            species: .cat,
            breed: nil,
            ageMonths: nil,
            weightKg: nil,
            knownAllergies: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(petCreate.isValid == true)
        #expect(petCreate.validationErrors.isEmpty)
    }
    
    /// Test invalid pet name validation
    @Test("Invalid pet name validation")
    func testInvalidPetName() {
        let emptyName = PetCreate(
            name: "",
            species: .dog,
            breed: nil,
            ageMonths: nil,
            weightKg: nil,
            knownAllergies: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(emptyName.isValid == false)
        #expect(emptyName.validationErrors.contains { $0.contains("required") })
        
        let shortName = PetCreate(
            name: "A",
            species: .dog,
            breed: nil,
            ageMonths: nil,
            weightKg: nil,
            knownAllergies: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(shortName.isValid == false)
        #expect(shortName.validationErrors.contains { $0.contains("at least 2 characters") })
        
        let longName = PetCreate(
            name: String(repeating: "A", count: 51),
            species: .dog,
            breed: nil,
            ageMonths: nil,
            weightKg: nil,
            knownAllergies: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(longName.isValid == false)
        #expect(longName.validationErrors.contains { $0.contains("less than 50 characters") })
    }
    
    /// Test invalid age validation
    @Test("Invalid age validation")
    func testInvalidAge() {
        let negativeAge = PetCreate(
            name: "Buddy",
            species: .dog,
            breed: nil,
            ageMonths: -1,
            weightKg: nil,
            knownAllergies: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(negativeAge.isValid == false)
        #expect(negativeAge.validationErrors.contains { $0.contains("Age cannot be negative") })
    }
    
    /// Test invalid weight validation
    @Test("Invalid weight validation")
    func testInvalidWeight() {
        let zeroWeight = PetCreate(
            name: "Buddy",
            species: .dog,
            breed: nil,
            ageMonths: nil,
            weightKg: 0,
            knownAllergies: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(zeroWeight.isValid == false)
        #expect(zeroWeight.validationErrors.contains { $0.contains("Weight must be positive") })
        
        let negativeWeight = PetCreate(
            name: "Buddy",
            species: .dog,
            breed: nil,
            ageMonths: nil,
            weightKg: -5.0,
            knownAllergies: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(negativeWeight.isValid == false)
        #expect(negativeWeight.validationErrors.contains { $0.contains("Weight must be positive") })
    }
    
    /// Test Pet model display properties
    @Test("Pet display properties")
    func testPetDisplayProperties() {
        let pet = Pet(
            id: "1",
            userId: "user1",
            name: "Buddy",
            species: .dog,
            breed: "Golden Retriever",
            ageMonths: 24,
            weightKg: 25.5,
            knownAllergies: ["chicken"],
            vetName: "Dr. Smith",
            vetPhone: "555-0123",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        #expect(pet.displayName == "Buddy (Golden Retriever)")
        #expect(pet.ageDescription == "2 years old")
        #expect(pet.isValid == true)
    }
    
    /// Test Pet model without breed
    @Test("Pet without breed")
    func testPetWithoutBreed() {
        let pet = Pet(
            id: "1",
            userId: "user1",
            name: "Fluffy",
            species: .cat,
            breed: nil,
            ageMonths: 6,
            weightKg: 4.2,
            knownAllergies: [],
            vetName: nil,
            vetPhone: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        #expect(pet.displayName == "Fluffy")
        #expect(pet.ageDescription == "6 months old")
    }
    
    /// Test age description edge cases
    @Test("Age description edge cases")
    func testAgeDescriptionEdgeCases() {
        let oneMonth = Pet(
            id: "1",
            userId: "user1",
            name: "Puppy",
            species: .dog,
            breed: nil,
            ageMonths: 1,
            weightKg: 2.0,
            knownAllergies: [],
            vetName: nil,
            vetPhone: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        #expect(oneMonth.ageDescription == "1 month old")
        
        let oneYear = Pet(
            id: "2",
            userId: "user1",
            name: "Dog",
            species: .dog,
            breed: nil,
            ageMonths: 12,
            weightKg: 10.0,
            knownAllergies: [],
            vetName: nil,
            vetPhone: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        #expect(oneYear.ageDescription == "1 year old")
        
        let mixedAge = Pet(
            id: "3",
            userId: "user1",
            name: "Cat",
            species: .cat,
            breed: nil,
            ageMonths: 18,
            weightKg: 5.0,
            knownAllergies: [],
            vetName: nil,
            vetPhone: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        #expect(mixedAge.ageDescription == "1 year, 6 months old")
    }
}
