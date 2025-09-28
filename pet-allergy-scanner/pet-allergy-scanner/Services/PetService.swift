//
//  PetService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Pet service for managing pet profiles
class PetService: ObservableObject {
    static let shared = PetService()
    
    @Published var pets: [Pet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    private init() {}
    
    /// Load all pets for the current user
    func loadPets() {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let pets = try await apiService.getPets()
                self.pets = pets
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Create a new pet profile
    func createPet(_ pet: PetCreate) {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let newPet = try await apiService.createPet(pet)
                self.pets.append(newPet)
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Update an existing pet profile
    func updatePet(id: String, petUpdate: PetUpdate) {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let updatedPet = try await apiService.updatePet(id: id, petUpdate: petUpdate)
                if let index = self.pets.firstIndex(where: { $0.id == updatedPet.id }) {
                    self.pets[index] = updatedPet
                }
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Delete a pet profile
    func deletePet(id: String) {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                try await apiService.deletePet(id: id)
                self.pets.removeAll { $0.id == id }
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Get pet by ID
    func getPet(id: String) -> Pet? {
        return pets.first { $0.id == id }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}
