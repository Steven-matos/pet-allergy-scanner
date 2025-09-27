//
//  PetService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/// Pet service for managing pet profiles
class PetService: ObservableObject {
    static let shared = PetService()
    
    @Published var pets: [Pet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    /// Load all pets for the current user
    func loadPets() {
        isLoading = true
        errorMessage = nil
        
        apiService.getPets()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] pets in
                    self?.pets = pets
                }
            )
            .store(in: &cancellables)
    }
    
    /// Create a new pet profile
    func createPet(_ pet: PetCreate) {
        isLoading = true
        errorMessage = nil
        
        apiService.createPet(pet)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] newPet in
                    self?.pets.append(newPet)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Update an existing pet profile
    func updatePet(id: String, petUpdate: PetUpdate) {
        isLoading = true
        errorMessage = nil
        
        apiService.updatePet(id: id, petUpdate: petUpdate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] updatedPet in
                    if let index = self?.pets.firstIndex(where: { $0.id == updatedPet.id }) {
                        self?.pets[index] = updatedPet
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// Delete a pet profile
    func deletePet(id: String) {
        isLoading = true
        errorMessage = nil
        
        apiService.deletePet(id: id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.pets.removeAll { $0.id == id }
                }
            )
            .store(in: &cancellables)
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
