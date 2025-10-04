//
//  MockData.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Mock data for SwiftUI previews and testing
struct MockData {
    
    // MARK: - Mock Pets
    
    static let mockPet1 = Pet(
        id: "pet-1",
        userId: "user-1",
        name: "Buddy",
        species: .dog,
        breed: "Golden Retriever",
        birthday: Calendar.current.date(from: DateComponents(year: 2022, month: 6, day: 1)),
        weightKg: 25.5,
        activityLevel: .moderate,
        imageUrl: nil,
        knownSensitivities: ["chicken", "wheat"],
        vetName: "Dr. Smith",
        vetPhone: "(555) 123-4567",
        createdAt: Date().addingTimeInterval(-86400 * 30), // 30 days ago
        updatedAt: Date().addingTimeInterval(-86400 * 5)    // 5 days ago
    )
    
    static let mockPet2 = Pet(
        id: "pet-2",
        userId: "user-1",
        name: "Whiskers",
        species: .cat,
        breed: "Persian",
        birthday: Calendar.current.date(from: DateComponents(year: 2023, month: 3, day: 1)),
        weightKg: 4.2,
        activityLevel: .low,
        imageUrl: nil,
        knownSensitivities: ["fish", "dairy"],
        vetName: "Dr. Johnson",
        vetPhone: "(555) 987-6543",
        createdAt: Date().addingTimeInterval(-86400 * 15), // 15 days ago
        updatedAt: Date().addingTimeInterval(-86400 * 2)    // 2 days ago
    )
    
    static let mockPets = [mockPet1, mockPet2]
    
    // MARK: - Mock Scans
    
    static let mockScan1 = Scan(
        id: "scan-1",
        userId: "user-1",
        petId: "pet-1",
        imageUrl: nil,
        rawText: "Chicken, Rice, Carrots, Peas, Chicken Fat, Natural Flavor",
        status: .completed,
        result: mockScanResult1,
        nutritionalAnalysis: nil,
        createdAt: Date().addingTimeInterval(-3600), // 1 hour ago
        updatedAt: Date().addingTimeInterval(-3600)
    )
    
    static let mockScan2 = Scan(
        id: "scan-2",
        userId: "user-1",
        petId: "pet-2",
        imageUrl: nil,
        rawText: "Salmon, Sweet Potato, Fish Oil, Vitamins",
        status: .completed,
        result: mockScanResult2,
        nutritionalAnalysis: nil,
        createdAt: Date().addingTimeInterval(-7200), // 2 hours ago
        updatedAt: Date().addingTimeInterval(-7200)
    )
    
    static let mockScan3 = Scan(
        id: "scan-3",
        userId: "user-1",
        petId: "pet-1",
        imageUrl: nil,
        rawText: "Beef, Brown Rice, Vegetables, Natural Preservatives",
        status: .processing,
        result: nil,
        nutritionalAnalysis: nil,
        createdAt: Date().addingTimeInterval(-1800), // 30 minutes ago
        updatedAt: Date().addingTimeInterval(-1800)
    )
    
    static let mockScans = [mockScan1, mockScan2, mockScan3]
    
    // MARK: - Mock Scan Results
    
    static let mockScanResult1 = ScanResult(
        productName: "Premium Dog Food",
        brand: "Healthy Paws",
        ingredientsFound: ["chicken", "rice", "carrots", "peas", "chicken fat", "natural flavor"],
        unsafeIngredients: ["chicken"],
        safeIngredients: ["rice", "carrots", "peas", "chicken fat", "natural flavor"],
        overallSafety: "caution",
        confidenceScore: 0.85,
        analysisDetails: [
            "chicken": "Known allergen for this pet",
            "rice": "Safe ingredient",
            "carrots": "Safe ingredient"
        ]
    )
    
    static let mockScanResult2 = ScanResult(
        productName: "Ocean Delight Cat Food",
        brand: "Feline Fresh",
        ingredientsFound: ["salmon", "sweet potato", "fish oil", "vitamins"],
        unsafeIngredients: ["salmon"],
        safeIngredients: ["sweet potato", "fish oil", "vitamins"],
        overallSafety: "unsafe",
        confidenceScore: 0.92,
        analysisDetails: [
            "salmon": "Known allergen for this pet",
            "sweet potato": "Safe ingredient",
            "fish oil": "Safe ingredient"
        ]
    )
    
    // MARK: - Mock User
    
    static let mockUser = User(
        id: "user-1",
        email: "john.doe@example.com",
        username: "johndoe",
        firstName: "John",
        lastName: "Doe",
        imageUrl: nil,
        role: .premium,
        onboarded: true,
        createdAt: Date().addingTimeInterval(-86400 * 90), // 90 days ago
        updatedAt: Date().addingTimeInterval(-86400 * 7)    // 7 days ago
    )
    
    // MARK: - Mock Services
    
    /// Note: Mock service creation methods removed as services use singleton pattern.
    /// Use shared instances (PetService.shared, AuthService.shared, ScanService.shared) 
    /// in SwiftUI previews instead of creating new instances.
}
