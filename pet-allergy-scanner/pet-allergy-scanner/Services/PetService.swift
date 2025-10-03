//
//  PetService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Pet service for managing pet profiles
@MainActor
class PetService: ObservableObject {
    static let shared = PetService()
    
    @Published var pets: [Pet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    private init() {}
    
    /// Load all pets for the current user
    /// - Note: Only loads pets if user is authenticated to avoid 403 errors during logout
    func loadPets() {
        // Don't attempt to load pets if not authenticated
        guard apiService.hasAuthToken else {
            self.pets = []
            self.isLoading = false
            self.errorMessage = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let pets = try await apiService.getPets()
                self.pets = pets
                self.isLoading = false
            } catch let apiError as APIError {
                self.isLoading = false
                // Silently ignore auth errors (user might be logging out)
                if case .authenticationError = apiError {
                    self.pets = []
                    self.errorMessage = nil
                } else {
                    self.errorMessage = apiError.localizedDescription
                }
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
        
        Task {
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
        
        Task {
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
        
        Task {
            do {
                // Find the pet to get its image URL
                if let pet = pets.first(where: { $0.id == id }),
                   let imageUrl = pet.imageUrl,
                   imageUrl.contains(Configuration.supabaseURL) {
                    // Delete the pet's image from Supabase Storage
                    do {
                        try await StorageService.shared.deletePetImage(path: imageUrl)
                        print("🗑️ Pet image deleted from Supabase: \(imageUrl)")
                    } catch {
                        print("⚠️ Failed to delete pet image: \(error)")
                        // Continue with pet deletion even if image deletion fails
                    }
                }
                
                // Delete the pet from the database
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
    
    /// Check if user has any pets
    var hasPets: Bool {
        return !pets.isEmpty
    }
    
    /// Complete onboarding by updating the user's onboarded status
    func completeOnboarding() {
        Task {
            do {
                let userUpdate = UserUpdate(
                    username: nil,
                    firstName: nil,
                    lastName: nil,
                    imageUrl: nil,
                    role: nil,
                    onboarded: true
                )
                _ = try await apiService.updateUser(userUpdate)
                
                // Refresh user data to get updated onboarded status
                await AuthService.shared.refreshCurrentUser()
            } catch {
                print("Failed to update onboarded status: \(error)")
            }
        }
    }
    
    /// Reset onboarding (for testing purposes)
    func resetOnboarding() {
        Task {
            do {
                let userUpdate = UserUpdate(
                    username: nil,
                    firstName: nil,
                    lastName: nil,
                    imageUrl: nil,
                    role: nil,
                    onboarded: false
                )
                _ = try await apiService.updateUser(userUpdate)
                
                // Refresh user data to get updated onboarded status
                await AuthService.shared.refreshCurrentUser()
            } catch {
                print("Failed to reset onboarded status: \(error)")
            }
        }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Clear all pets (called during logout)
    func clearPets() {
        pets = []
        errorMessage = nil
        isLoading = false
    }
}
