//
//  CachedFoodService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import Combine

/**
 * Cached Food Service
 * 
 * Provides cached access to food data with automatic cache management.
 * Implements cache-first pattern for optimal performance.
 * 
 * Follows SOLID principles: Single responsibility for cached food operations
 * Implements DRY by reusing cache patterns from existing cached services
 * Follows KISS by keeping the caching logic simple and transparent
 */
@MainActor
class CachedFoodService: ObservableObject {
    static let shared = CachedFoodService()
    
    @Published var recentFoods: [FoodItem] = []
    @Published var foodDatabase: [FoodItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService: APIService
    private let cacheService = CacheService.shared
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Current user ID for cache scoping
    private var currentUserId: String? {
        authService.currentUser?.id
    }
    
    private init() {
        self.apiService = APIService.shared
        observeAuthChanges()
    }
    
    // MARK: - Authentication Observation
    
    /**
     * Observe authentication changes to manage user-specific cache
     */
    private func observeAuthChanges() {
        authService.$authState
            .sink { [weak self] authState in
                if !authState.isAuthenticated {
                    // Clear cache on logout
                    self?.clearCache()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public API
    
    /**
     * Load recent foods for the user with caching
     */
    func loadRecentFoods() async throws {
        // Try cache first
        if let userId = currentUserId {
            let cacheKey = CacheKey.recentFoods.scoped(forUserId: userId)
            if let cached = cacheService.retrieve([FoodItem].self, forKey: cacheKey) {
                recentFoods = cached
                return
            }
        }
        
        // Fallback to server
        isLoading = true
        error = nil
        
        do {
            let response = try await apiService.get(
                endpoint: "/nutrition/foods/recent",
                responseType: [FoodItem].self
            )
            
            recentFoods = response
            
            // Cache the result
            if let userId = currentUserId {
                let cacheKey = CacheKey.recentFoods.scoped(forUserId: userId)
                cacheService.store(response, forKey: cacheKey)
            }
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Search for food items by name or barcode with caching
     * - Parameter query: Search query
     * - Returns: Array of matching food items
     */
    func searchFoods(query: String) async throws -> [FoodItem] {
        // For search results, we use a shorter cache duration since results can change frequently
        let searchCacheKey = "food_search_\(query.lowercased())"
        
        // Try cache first (with shorter duration)
        if let cached = cacheService.retrieve([FoodItem].self, forKey: searchCacheKey) {
            foodDatabase = cached
            return cached
        }
        
        // Fallback to server
        isLoading = true
        error = nil
        
        do {
            let response = try await apiService.get(
                endpoint: "/nutrition/foods/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                responseType: [FoodItem].self
            )
            
            foodDatabase = response
            
            // Cache search results with shorter duration (15 minutes)
            cacheService.store(response, forKey: searchCacheKey, policy: .timeBased(900))
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
        return foodDatabase
    }
    
    /**
     * Get food item by barcode with caching
     * - Parameter barcode: The barcode to search for
     * - Returns: Food item if found
     */
    func getFoodByBarcode(_ barcode: String) async throws -> FoodItem? {
        // Try cache first
        let barcodeCacheKey = "food_barcode_\(barcode)"
        if let cached = cacheService.retrieve(FoodItem.self, forKey: barcodeCacheKey) {
            // Add to recent foods if found
            if !recentFoods.contains(where: { $0.id == cached.id }) {
                recentFoods.insert(cached, at: 0)
                // Keep only last 20 items
                if recentFoods.count > 20 {
                    recentFoods = Array(recentFoods.prefix(20))
                }
                
                // Update recent foods cache
                if let userId = currentUserId {
                    let cacheKey = CacheKey.recentFoods.scoped(forUserId: userId)
                    cacheService.store(recentFoods, forKey: cacheKey)
                }
            }
            return cached
        }
        
        // Fallback to server
        do {
            let response = try await apiService.get(
                endpoint: "/nutrition/foods/barcode/\(barcode)",
                responseType: FoodItem.self
            )
            
            // Cache the result
            cacheService.store(response, forKey: barcodeCacheKey, policy: .timeBased(86400)) // 24 hours
            
            // Add to recent foods if found
            if !recentFoods.contains(where: { $0.id == response.id }) {
                recentFoods.insert(response, at: 0)
                // Keep only last 20 items
                if recentFoods.count > 20 {
                    recentFoods = Array(recentFoods.prefix(20))
                }
                
                // Update recent foods cache
                if let userId = currentUserId {
                    let cacheKey = CacheKey.recentFoods.scoped(forUserId: userId)
                    cacheService.store(recentFoods, forKey: cacheKey)
                }
            }
            
            return response
            
        } catch {
            if case APIError.serverError(404) = error {
                return nil
            }
            throw error
        }
    }
    
    /**
     * Create a new food item with cache invalidation
     * - Parameter foodItem: The food item to create
     * - Returns: Created food item
     */
    func createFoodItem(_ foodItem: FoodItemRequest) async throws -> FoodItem {
        isLoading = true
        error = nil
        
        do {
            let response = try await apiService.post(
                endpoint: "/nutrition/foods",
                body: foodItem,
                responseType: FoodItem.self
            )
            
            // Add to recent foods
            recentFoods.insert(response, at: 0)
            
            // Update recent foods cache
            if currentUserId != nil {
                let cacheKey = CacheKey.recentFoods.scoped(forUserId: currentUserId!)
                cacheService.store(recentFoods, forKey: cacheKey)
            }
            
            isLoading = false
            return response
            
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    /**
     * Update an existing food item with cache invalidation
     * - Parameter foodItem: The food item to update
     */
    func updateFoodItem(_ foodItem: FoodItem) async throws {
        isLoading = true
        error = nil
        
        do {
            let request = FoodItemRequest(
                name: foodItem.name,
                brand: foodItem.brand,
                barcode: foodItem.barcode,
                nutritionalInfo: foodItem.nutritionalInfo
            )
            
            let response = try await apiService.put(
                endpoint: "/nutrition/foods/\(foodItem.id)",
                body: request,
                responseType: FoodItem.self
            )
            
            // Update in recent foods
            if let index = recentFoods.firstIndex(where: { $0.id == foodItem.id }) {
                recentFoods[index] = response
                
                // Update recent foods cache
                if let userId = currentUserId {
                    let cacheKey = CacheKey.recentFoods.scoped(forUserId: userId)
                    cacheService.store(recentFoods, forKey: cacheKey)
                }
            }
            
            // Invalidate barcode cache if barcode exists
            if let barcode = foodItem.barcode {
                let barcodeCacheKey = "food_barcode_\(barcode)"
                cacheService.invalidate(forKey: barcodeCacheKey)
            }
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Delete a food item with cache invalidation
     * - Parameter foodId: The ID of the food item to delete
     */
    func deleteFoodItem(_ foodId: String) async throws {
        // Get the food item first to invalidate its barcode cache
        let foodItem = recentFoods.first { $0.id == foodId }
        
        isLoading = true
        error = nil
        
        do {
            try await apiService.delete(endpoint: "/nutrition/foods/\(foodId)")
            
            // Remove from recent foods
            recentFoods.removeAll { $0.id == foodId }
            
            // Update recent foods cache
            if let userId = currentUserId {
                let cacheKey = CacheKey.recentFoods.scoped(forUserId: userId)
                cacheService.store(recentFoods, forKey: cacheKey)
            }
            
            // Invalidate barcode cache if barcode exists
            if let barcode = foodItem?.barcode {
                let barcodeCacheKey = "food_barcode_\(barcode)"
                cacheService.invalidate(forKey: barcodeCacheKey)
            }
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Get nutritional analysis for a food item with caching
     * - Parameter foodId: The food item ID
     * - Returns: Food nutritional analysis
     */
    func getNutritionalAnalysis(for foodId: String) async throws -> FoodNutritionalAnalysis {
        // Try cache first
        let analysisCacheKey = "food_analysis_\(foodId)"
        if let cached = cacheService.retrieve(FoodNutritionalAnalysis.self, forKey: analysisCacheKey) {
            return cached
        }
        
        // Fallback to server
        let analysis = try await apiService.get(
            endpoint: "/nutrition/foods/\(foodId)/analysis",
            responseType: FoodNutritionalAnalysis.self
        )
        
        // Cache the result (24 hours)
        cacheService.store(analysis, forKey: analysisCacheKey, policy: .timeBased(86400))
        
        return analysis
    }
    
    /**
     * Calculate calories for a specific amount of food with caching
     * - Parameter foodId: The food item ID
     * - Parameter amountGrams: Amount in grams
     * - Returns: Calculated calories
     */
    func calculateCalories(for foodId: String, amountGrams: Double) async throws -> Double {
        let analysis = try await getNutritionalAnalysis(for: foodId)
        return (analysis.caloriesPer100g / 100.0) * amountGrams
    }
    
    // MARK: - Extensions
    
    /**
     * Get popular food brands
     * - Returns: Array of popular brand names
     */
    func getPopularBrands() -> [String] {
        let brandCounts = recentFoods.compactMap { $0.brand }
            .reduce(into: [String: Int]()) { counts, brand in
                counts[brand, default: 0] += 1
            }
        
        return brandCounts.sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
    }
    
    /**
     * Get food categories based on recent usage
     * - Returns: Array of food categories
     */
    func getFoodCategories() -> [String] {
        // This would be more sophisticated in a real implementation
        // For now, return common pet food categories
        return ["Dry Food", "Wet Food", "Treats", "Supplements", "Raw Food"]
    }
    
    /**
     * Search foods with filters with caching
     * - Parameter query: Search query
     * - Parameter brand: Brand filter
     * - Parameter category: Category filter
     * - Returns: Array of filtered food items
     */
    func searchFoodsWithFilters(query: String, brand: String? = nil, category: String? = nil) async throws -> [FoodItem] {
        var endpoint = "/nutrition/foods/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let brand = brand {
            endpoint += "&brand=\(brand.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        
        if let category = category {
            endpoint += "&category=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        
        // Create cache key based on search parameters
        let searchCacheKey = "food_search_filtered_\(query.lowercased())_\(brand ?? "")_\(category ?? "")"
        
        // Try cache first
        if let cached = cacheService.retrieve([FoodItem].self, forKey: searchCacheKey) {
            return cached
        }
        
        // Fallback to server
        let response = try await apiService.get(
            endpoint: endpoint,
            responseType: [FoodItem].self
        )
        
        // Cache the result (15 minutes for filtered searches)
        cacheService.store(response, forKey: searchCacheKey, policy: .timeBased(900))
        
        return response
    }
    
    // MARK: - Data Management
    
    /**
     * Clear all cached data
     */
    func clearCache() {
        recentFoods.removeAll()
        foodDatabase.removeAll()
    }
    
    /**
     * Warm cache with recent foods
     */
    func warmCache() async {
        do {
            try await loadRecentFoods()
        } catch {
            print("Failed to warm food cache: \(error)")
        }
    }
}
