//
//  PetService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation

/// Pet service for managing pet profiles
@MainActor
class PetService: ObservableObject, @unchecked Sendable {
    static let shared = PetService()
    
    @Published var pets: [Pet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    
    private init() {}
    
    /// Load all pets for the current user
    /// - Note: Only loads pets if user is authenticated to avoid 403 errors during logout
    func loadPets() {
        Task {
            // Don't attempt to load pets if not authenticated
            guard await apiService.hasAuthToken else {
                await MainActor.run {
                    self.pets = []
                    self.isLoading = false
                    self.errorMessage = nil
                }
                return
            }
            
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let pets = try await apiService.getPets()
                await MainActor.run {
                    self.pets = pets
                    self.isLoading = false
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    self.isLoading = false
                    // Silently ignore auth errors (user might be logging out)
                    if case .authenticationError = apiError {
                        self.pets = []
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = apiError.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Create a new pet profile
    func createPet(_ pet: PetCreate) {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let newPet = try await apiService.createPet(pet)
                await MainActor.run {
                    self.pets.append(newPet)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Update an existing pet profile
    func updatePet(id: String, petUpdate: PetUpdate) {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                let updatedPet = try await apiService.updatePet(id: id, petUpdate: petUpdate)
                await MainActor.run {
                    if let index = self.pets.firstIndex(where: { $0.id == updatedPet.id }) {
                        self.pets[index] = updatedPet
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Delete a pet profile
    func deletePet(id: String) {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            do {
                // Find the pet to get its image URL
                let pet = await MainActor.run { pets.first(where: { $0.id == id }) }
                if let pet = pet,
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
                await MainActor.run {
                    self.pets.removeAll { $0.id == id }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
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
        Task { @MainActor in
            errorMessage = nil
        }
    }
    
    /// Clear all pets (called during logout)
    func clearPets() {
        Task { @MainActor in
            pets = []
            errorMessage = nil
            isLoading = false
        }
    }
}
