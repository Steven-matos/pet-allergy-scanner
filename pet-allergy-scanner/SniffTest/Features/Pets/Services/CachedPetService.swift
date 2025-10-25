//
//  CachedPetService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/// Enhanced pet service with intelligent caching
/// Implements DRY principle by extending PetService functionality
/// Implements KISS principle with simple, clear caching logic
@MainActor
class CachedPetService: ObservableObject {
    static let shared = CachedPetService()
    
    // MARK: - Properties
    
    @Published var pets: [Pet] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRefreshing = false
    
    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    
    /// Current user ID for cache scoping
    private var currentUserId: String? {
        return AuthService.shared.currentUser?.id
    }
    
    /// Cache refresh timer for background updates
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        setupCacheRefreshTimer()
        observeAuthChanges()
    }
    
    // MARK: - Public Interface
    
    /// Load all pets with intelligent caching
    /// - Parameter forceRefresh: Force refresh from server, bypassing cache
    func loadPets(forceRefresh: Bool = false) {
        guard let userId = currentUserId else {
            self.pets = []
            self.isLoading = false
            self.errorMessage = nil
            return
        }
        
        // Try cache first unless force refresh is requested
        if !forceRefresh {
            if let cachedPets = cacheService.retrieveUserData([Pet].self, forKey: .pets, userId: userId) {
                self.pets = cachedPets
                self.isLoading = false
                self.errorMessage = nil
                
                // Trigger background refresh if cache is stale
                refreshPetsInBackground()
                return
            }
        }
        
        // Load from server
        loadPetsFromServer()
    }
    
    /// Create a new pet with cache invalidation
    /// - Parameter pet: Pet creation data
    func createPet(_ pet: PetCreate) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let newPet = try await apiService.createPet(pet)
                
                // Update local state
                self.pets.append(newPet)
                self.isLoading = false
                
                // Update cache
                await updatePetsCache()
                
                // Invalidate related caches
                invalidateRelatedCaches()
                
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Update an existing pet with cache invalidation
    /// - Parameters:
    ///   - id: Pet ID
    ///   - petUpdate: Pet update data
    func updatePet(id: String, petUpdate: PetUpdate) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let updatedPet = try await apiService.updatePet(id: id, petUpdate: petUpdate)
                
                // Update local state
                if let index = self.pets.firstIndex(where: { $0.id == updatedPet.id }) {
                    self.pets[index] = updatedPet
                }
                self.isLoading = false
                
                // Update cache
                await updatePetsCache()
                
                // Invalidate pet-specific caches
                invalidatePetSpecificCaches(petId: id)
                
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Delete a pet with cache invalidation
    /// - Parameter id: Pet ID
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
                
                // Delete from server
                try await apiService.deletePet(id: id)
                
                // Update local state
                self.pets.removeAll { $0.id == id }
                self.isLoading = false
                
                // Update cache
                await updatePetsCache()
                
                // Invalidate pet-specific caches
                invalidatePetSpecificCaches(petId: id)
                
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Get pet by ID with caching
    /// - Parameter id: Pet ID
    /// - Returns: Pet if found, nil otherwise
    func getPet(id: String) -> Pet? {
        // Try local state first
        if let pet = pets.first(where: { $0.id == id }) {
            return pet
        }
        
        // Try cache
        if let _ = currentUserId,
           let cachedPet = cacheService.retrievePetData(Pet.self, forKey: .petDetails, petId: id) {
            return cachedPet
        }
        
        return nil
    }
    
    /// Get pet by ID with server fallback
    /// - Parameter id: Pet ID
    /// - Returns: Pet from server or cache
    func getPetWithFallback(id: String) async -> Pet? {
        // Try local state first
        if let pet = pets.first(where: { $0.id == id }) {
            return pet
        }
        
        // Try cache
        if let _ = currentUserId,
           let cachedPet = cacheService.retrievePetData(Pet.self, forKey: .petDetails, petId: id) {
            return cachedPet
        }
        
        // Fallback to server
        do {
            let pet = try await apiService.getPet(id: id)
            
            // Cache the result
            if currentUserId != nil {
                cacheService.storePetData(pet, forKey: .petDetails, petId: id)
            }
            
            return pet
        } catch {
            print("❌ Failed to fetch pet from server: \(error)")
            return nil
        }
    }
    
    /// Refresh pets data from server
    func refreshPets() {
        loadPets(forceRefresh: true)
    }
    
    /// Check if user has any pets
    var hasPets: Bool {
        return !pets.isEmpty
    }
    
    /// Complete onboarding with cache invalidation
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
                
                // Refresh user data
                await AuthService.shared.refreshCurrentUser()
                
                // Invalidate user-related caches
                invalidateUserCaches()
                
            } catch {
                print("Failed to update onboarded status: \(error)")
            }
        }
    }
    
    /// Reset onboarding with cache invalidation
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
                
                // Refresh user data
                await AuthService.shared.refreshCurrentUser()
                
                // Invalidate user-related caches
                invalidateUserCaches()
                
            } catch {
                print("Failed to reset onboarded status: \(error)")
            }
        }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Clear all pets and cache (called during logout)
    func clearPets() {
        pets = []
        errorMessage = nil
        isLoading = false
        isRefreshing = false
        
        // Clear user-specific cache
        if let userId = currentUserId {
            cacheService.clearUserCache(userId: userId)
        }
        
        // Stop refresh timer
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Private Methods
    
    /// Load pets from server
    private func loadPetsFromServer() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let pets = try await apiService.getPets()
                
                // Update local state
                self.pets = pets
                self.isLoading = false
                
                // Update cache
                await updatePetsCache()
                
            } catch let apiError as APIError {
                self.isLoading = false
                
                // Handle auth errors silently
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
    
    /// Update pets cache
    private func updatePetsCache() async {
        guard let userId = currentUserId else { return }
        
        // Cache the pets list
        cacheService.storeUserData(pets, forKey: .pets, userId: userId)
        
        // Cache individual pet details
        for pet in pets {
            cacheService.storePetData(pet, forKey: .petDetails, petId: pet.id)
        }
    }
    
    /// Refresh pets in background if cache is stale
    private func refreshPetsInBackground() {
        guard let userId = currentUserId else { return }
        
        // Check if cache is stale
        let cacheKey = CacheKey.pets.scoped(forUserId: userId)
        if !cacheService.exists(forKey: cacheKey) {
            isRefreshing = true
            
            Task {
                do {
                    let pets = try await apiService.getPets()
                    
                    // Update local state only if it's different
                    if self.pets != pets {
                        self.pets = pets
                        await updatePetsCache()
                    }
                    
                    self.isRefreshing = false
                } catch {
                    print("❌ Background refresh failed: \(error)")
                    self.isRefreshing = false
                }
            }
        }
    }
    
    /// Setup cache refresh timer
    private func setupCacheRefreshTimer() {
        // Refresh cache every 10 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPetsInBackground()
            }
        }
    }
    
    /// Observe authentication changes
    private func observeAuthChanges() {
        // This would typically use Combine or NotificationCenter
        // For now, we'll handle it in the loadPets method
    }
    
    /// Invalidate related caches when pets change
    private func invalidateRelatedCaches() {
        guard currentUserId != nil else { return }
        
        // Invalidate scan-related caches since they depend on pets
        cacheService.invalidateMatching(pattern: ".*scans.*")
        cacheService.invalidateMatching(pattern: ".*scan_history.*")
    }
    
    /// Invalidate pet-specific caches
    private func invalidatePetSpecificCaches(petId: String) {
        // Invalidate pet details cache
        cacheService.invalidate(forKey: CacheKey.petDetails.scoped(forPetId: petId))
        
        // Invalidate pet-specific scan caches
        cacheService.invalidateMatching(pattern: ".*scans.*\(petId).*")
    }
    
    /// Invalidate user-related caches
    private func invalidateUserCaches() {
        guard let userId = currentUserId else { return }
        
        // Invalidate user profile cache
        cacheService.invalidate(forKey: CacheKey.userProfile.scoped(forUserId: userId))
        
        // Invalidate current user cache
        cacheService.invalidate(forKey: CacheKey.currentUser.scoped(forUserId: userId))
    }
}

// MARK: - Cache Analytics Extension

extension CachedPetService {
    /// Get cache statistics for pets
    func getCacheStats() -> [String: Any] {
        var stats = cacheService.getCacheStats()
        
        // Add pet-specific stats
        stats["pets_count"] = pets.count
        stats["is_loading"] = isLoading
        stats["is_refreshing"] = isRefreshing
        stats["has_error"] = errorMessage != nil
        
        return stats
    }
    
    /// Get cache hit rate for pets
    func getCacheHitRate() -> Double {
        // This would require tracking hits/misses in the cache service
        // For now, return a placeholder
        return 0.0
    }
}
