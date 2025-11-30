//
//  CachedPetService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine
import UIKit

/// Enhanced pet service with intelligent caching - Modernized for SwiftUI 5.0
/// 
/// Modern SwiftUI 5.0 Features:
/// - Uses @Observable macro for better performance
/// - Leverages Swift Concurrency for async operations
/// - Implements modern state management patterns
/// 
/// Implements DRY principle by extending PetService functionality
/// Implements KISS principle with simple, clear caching logic
@MainActor
@Observable
final class CachedPetService {
    static let shared = CachedPetService()
    
    // MARK: - Properties
    
    var pets: [Pet] = []
    var isLoading = false
    var errorMessage: String?
    var isRefreshing = false
    
    private let apiService = APIService.shared
    private let cacheService = CacheService.shared
    
    /// Current user ID for cache scoping
    private var currentUserId: String? {
        return AuthService.shared.currentUser?.id
    }
    
    /// Cache refresh timer for background updates
    private var refreshTimer: Timer?
    
    /// Cancellable subscriptions for Combine observers
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupCacheRefreshTimer()
        observeAuthChanges()
        observeAppLifecycle()
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
        
        // If pets are already loaded in memory and not forcing refresh, skip
        if !forceRefresh && !pets.isEmpty {
            // Still trigger background refresh if cache is stale
            refreshPetsInBackground()
            return
        }
        
        // Try cache first unless force refresh is requested
        if !forceRefresh {
            if let cachedPets = cacheService.retrieveUserData([Pet].self, forKey: .pets, userId: userId) {
                // Only update if we got pets from cache
                if !cachedPets.isEmpty {
                    self.pets = cachedPets
                    self.isLoading = false
                    self.errorMessage = nil
                    
                    print("✅ Loaded \(cachedPets.count) pet(s) from cache")
                    
                    // Trigger background refresh if cache is stale
                    refreshPetsInBackground()
                    return
                }
            }
        }
        
        // Load from server
        loadPetsFromServer()
    }
    
    /// Load pets asynchronously - use this when you need to await the result
    /// - Parameter forceRefresh: Whether to bypass cache and force server refresh
    /// - Returns: The loaded pets array
    @discardableResult
    func loadPetsAsync(forceRefresh: Bool = false) async throws -> [Pet] {
        guard let userId = currentUserId else {
            await MainActor.run {
                self.pets = []
                self.isLoading = false
                self.errorMessage = nil
            }
            return []
        }
        
        // If not forcing refresh and pets are already loaded, return them
        if !forceRefresh && !pets.isEmpty {
            // Still trigger background refresh if cache is stale
            refreshPetsInBackground()
            return pets
        }
        
        // Try cache first unless force refresh is requested
        if !forceRefresh {
            if let cachedPets = cacheService.retrieveUserData([Pet].self, forKey: .pets, userId: userId) {
                if !cachedPets.isEmpty {
                    await MainActor.run {
                        self.pets = cachedPets
                        self.isLoading = false
                        self.errorMessage = nil
                    }
                    print("✅ Loaded \(cachedPets.count) pet(s) from cache")
                    
                    // Trigger background refresh if cache is stale
                    refreshPetsInBackground()
                    return cachedPets
                }
            }
        }
        
        // Load from server and wait for completion
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let loadedPets = try await apiService.getPets()
            
            await MainActor.run {
                self.pets = loadedPets
                self.isLoading = false
            }
            
            // Update cache
            await updatePetsCache()
            
            print("✅ Loaded \(loadedPets.count) pet(s) from server")
            return loadedPets
            
        } catch let apiError as APIError {
            await MainActor.run {
                self.isLoading = false
                
                // Handle auth errors silently
                if case .authenticationError = apiError {
                    self.pets = []
                    self.errorMessage = nil
                } else {
                    self.errorMessage = apiError.localizedDescription
                }
            }
            throw apiError
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
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
                // CRITICAL: Create new array to ensure @Observable detects the change
                await MainActor.run {
                    self.pets.append(newPet)
                    self.isLoading = false
                }
                
                // Track pet creation
                PostHogAnalytics.trackPetCreated(petId: newPet.id, species: newPet.species.rawValue)
                PostHogAnalytics.updatePetCount(self.pets.count)
                
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
                await MainActor.run {
                    if let index = self.pets.firstIndex(where: { $0.id == updatedPet.id }) {
                        // CRITICAL FIX: @Observable doesn't detect in-place array element mutations
                        // Create a new array instance to trigger observation
                        var updatedPets = self.pets
                        updatedPets[index] = updatedPet
                        self.pets = updatedPets  // Reassign entire array to trigger observation
                        print("✅ [updatePet] Updated pet in array - weight: \(updatedPet.weightKg ?? 0) kg")
                    }
                    self.isLoading = false
                }
                
                // Track pet update
                PostHogAnalytics.trackPetUpdated(petId: updatedPet.id, species: updatedPet.species.rawValue)
                
                // Update cache
                await updatePetsCache()
                
                // Invalidate pet-specific caches
                invalidatePetSpecificCaches(petId: id)
                
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Refresh a specific pet from server (useful after weight/event updates)
    /// - Parameter petId: The pet ID to refresh
    func refreshPet(petId: String) async throws {
        // Invalidate pet cache
        let petDetailCacheKey = CacheKey.petDetails.scoped(forPetId: petId)
        cacheService.invalidate(forKey: petDetailCacheKey)
        
        // Fetch fresh pet data from server
        let updatedPet = try await apiService.getPet(id: petId)
        
        // CRITICAL FIX: @Observable doesn't detect in-place array element mutations
        // We need to create a new array instance to trigger observation
        await MainActor.run {
            if let index = self.pets.firstIndex(where: { $0.id == petId }) {
                // Create a new array with the updated pet to trigger @Observable
                var updatedPets = self.pets
                updatedPets[index] = updatedPet
                self.pets = updatedPets  // Reassign entire array to trigger observation
                print("✅ [refreshPet] Refreshed pet from server - weight: \(updatedPet.weightKg ?? 0) kg")
                print("   Old weight in array: \(self.pets[index].weightKg ?? 0) kg")
            } else {
                // Pet not in array, add it
                self.pets.append(updatedPet)
                print("✅ [refreshPet] Added pet to array - weight: \(updatedPet.weightKg ?? 0) kg")
            }
        }
        
        // Update cache
        await updatePetsCache()
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
                
                // Get pet info before deletion for tracking
                let deletedPet = pets.first(where: { $0.id == id })
                let petSpecies = deletedPet?.species.rawValue ?? "unknown"
                
                // Delete from server
                try await apiService.deletePet(id: id)
                
                // Update local state
                // CRITICAL: Create new array to ensure @Observable detects the change
                await MainActor.run {
                    self.pets.removeAll { $0.id == id }
                    self.isLoading = false
                }
                
                // Track pet deletion
                PostHogAnalytics.trackPetDeleted(petId: id, species: petSpecies)
                PostHogAnalytics.updatePetCount(self.pets.count)
                
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
                
                // Track onboarding completion
                PostHogAnalytics.trackOnboardingCompleted(petsCount: self.pets.count)
                
                // Refresh user data
                await AuthService.shared.refreshCurrentUser()
                
                // Invalidate user-related caches
                invalidateUserCaches()
                
                print("✅ Onboarding completed successfully")
                
            } catch APIError.authenticationError {
                // Authentication error during onboarding completion
                // This could happen if the token is invalid or expired
                // Don't fail the entire flow - the pet was created successfully
                print("⚠️ Authentication error during onboarding completion - pet was created successfully")
                
                // Try to refresh the user data anyway to get the latest state
                await AuthService.shared.refreshCurrentUser()
                
            } catch {
                print("❌ Failed to update onboarded status: \(error)")
                
                // Try to refresh the user data anyway to get the latest state
                await AuthService.shared.refreshCurrentUser()
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
    
    /// Observe authentication changes to clear data on logout
    private func observeAuthChanges() {
        // Observe logout notifications to clear pet data
        NotificationCenter.default.publisher(for: .userDidLogout)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.clearPets()
                    print("🔄 Cleared pets data after logout")
                }
            }
            .store(in: &cancellables)
        
        // Observe login notifications to reload pet data
        NotificationCenter.default.publisher(for: .userDidLogin)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadPets(forceRefresh: false)
                    print("🔄 Reloading pets after login")
                }
            }
            .store(in: &cancellables)
    }
    
    /// Observe app lifecycle to handle background/foreground transitions
    private func observeAppLifecycle() {
        // Reload pets when app becomes active after being in background
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    // Only reload if we have a user and no pets in memory
                    guard let self = self else { return }
                    
                    if self.currentUserId != nil && self.pets.isEmpty {
                        print("🔄 App became active with no pets in memory - loading from cache")
                        self.loadPets(forceRefresh: false)
                    }
                }
            }
            .store(in: &cancellables)
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
