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
        let birthday = Calendar.current.date(from: DateComponents(year: 2022, month: 6, day: 1))
        let petCreate = PetCreate(
            name: "Buddy",
            species: .dog,
            breed: "Golden Retriever",
            birthday: birthday,
            weightKg: 25.5,
            imageUrl: nil,
            knownSensitivities: ["chicken", "wheat"],
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
            birthday: nil,
            weightKg: nil,
            imageUrl: nil,
            knownSensitivities: [],
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
            birthday: nil,
            weightKg: nil,
            imageUrl: nil,
            knownSensitivities: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(emptyName.isValid == false)
        #expect(emptyName.validationErrors.contains { $0.contains("required") })
        
        let shortName = PetCreate(
            name: "A",
            species: .dog,
            breed: nil,
            birthday: nil,
            weightKg: nil,
            imageUrl: nil,
            knownSensitivities: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(shortName.isValid == false)
        #expect(shortName.validationErrors.contains { $0.contains("at least 2 characters") })
        
        let longName = PetCreate(
            name: String(repeating: "A", count: 51),
            species: .dog,
            breed: nil,
            birthday: nil,
            weightKg: nil,
            imageUrl: nil,
            knownSensitivities: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(longName.isValid == false)
        #expect(longName.validationErrors.contains { $0.contains("less than 50 characters") })
    }
    
    /// Test invalid birthday validation
    @Test("Invalid birthday validation")
    func testInvalidBirthday() {
        let futureDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())
        let futureBirthday = PetCreate(
            name: "Buddy",
            species: .dog,
            breed: nil,
            birthday: futureDate,
            weightKg: nil,
            imageUrl: nil,
            knownSensitivities: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(futureBirthday.isValid == false)
        #expect(futureBirthday.validationErrors.contains { $0.contains("Birthday cannot be in the future") })
    }
    
    /// Test invalid weight validation
    @Test("Invalid weight validation")
    func testInvalidWeight() {
        let zeroWeight = PetCreate(
            name: "Buddy",
            species: .dog,
            breed: nil,
            birthday: nil,
            weightKg: 0,
            imageUrl: nil,
            knownSensitivities: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(zeroWeight.isValid == false)
        #expect(zeroWeight.validationErrors.contains { $0.contains("Weight must be positive") })
        
        let negativeWeight = PetCreate(
            name: "Buddy",
            species: .dog,
            breed: nil,
            birthday: nil,
            weightKg: -5.0,
            imageUrl: nil,
            knownSensitivities: [],
            vetName: nil,
            vetPhone: nil
        )
        
        #expect(negativeWeight.isValid == false)
        #expect(negativeWeight.validationErrors.contains { $0.contains("Weight must be positive") })
    }
    
    /// Test Pet model display properties
    @Test("Pet display properties")
    func testPetDisplayProperties() {
        let birthday = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let pet = Pet(
            id: "1",
            userId: "user1",
            name: "Buddy",
            species: .dog,
            breed: "Golden Retriever",
            birthday: birthday,
            weightKg: 25.5,
            imageUrl: nil,
            knownSensitivities: ["chicken"],
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
        let birthday = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let pet = Pet(
            id: "1",
            userId: "user1",
            name: "Fluffy",
            species: .cat,
            breed: nil,
            birthday: birthday,
            weightKg: 4.2,
            imageUrl: nil,
            knownSensitivities: [],
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
        let oneMonthBirthday = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let oneMonth = Pet(
            id: "1",
            userId: "user1",
            name: "Puppy",
            species: .dog,
            breed: nil,
            birthday: oneMonthBirthday,
            weightKg: 2.0,
            imageUrl: nil,
            knownSensitivities: [],
            vetName: nil,
            vetPhone: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        #expect(oneMonth.ageDescription == "1 month old")
        
        let oneYearBirthday = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        let oneYear = Pet(
            id: "2",
            userId: "user1",
            name: "Dog",
            species: .dog,
            breed: nil,
            birthday: oneYearBirthday,
            weightKg: 10.0,
            imageUrl: nil,
            knownSensitivities: [],
            vetName: nil,
            vetPhone: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        #expect(oneYear.ageDescription == "1 year old")
        
        let mixedAgeBirthday = Calendar.current.date(byAdding: .month, value: -18, to: Date())!
        let mixedAge = Pet(
            id: "3",
            userId: "user1",
            name: "Cat",
            species: .cat,
            breed: nil,
            birthday: mixedAgeBirthday,
            weightKg: 5.0,
            imageUrl: nil,
            knownSensitivities: [],
            vetName: nil,
            vetPhone: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        #expect(mixedAge.ageDescription == "1 year, 6 months old")
    }
}
