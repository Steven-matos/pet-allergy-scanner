//
//  FoodService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import Combine

/**
 * Food Service
 * 
 * Handles food item operations including:
 * - Managing food database
 * - Barcode scanning integration
 * - Recent foods tracking
 * - Food nutritional data
 * 
 * Follows SOLID principles with single responsibility for food data
 * Implements DRY by reusing common API patterns
 * Follows KISS by keeping the API simple and focused
 */
@MainActor
class FoodService: ObservableObject {
    static let shared = FoodService()
    
    @Published var recentFoods: [FoodItem] = []
    @Published var foodDatabase: [FoodItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        self.apiService = APIService.shared
    }
    
    // MARK: - Public API
    
    /**
     * Load recent foods for the user
     */
    func loadRecentFoods() async throws {
        isLoading = true
        error = nil
        
        do {
            let response = try await apiService.get(
                endpoint: "/nutrition/foods/recent",
                responseType: [FoodItem].self
            )
            
            recentFoods = response
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Search for food items by name or barcode
     * - Parameter query: Search query
     */
    func searchFoods(query: String) async throws -> [FoodItem] {
        isLoading = true
        error = nil
        
        do {
            let response = try await apiService.get(
                endpoint: "/nutrition/foods/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                responseType: [FoodItem].self
            )
            
            foodDatabase = response
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
        return foodDatabase
    }
    
    /**
     * Get food item by barcode
     * - Parameter barcode: The barcode to search for
     */
    func getFoodByBarcode(_ barcode: String) async throws -> FoodItem? {
        do {
            let response = try await apiService.get(
                endpoint: "/nutrition/foods/barcode/\(barcode)",
                responseType: FoodItem.self
            )
            
            // Add to recent foods if found
            if !recentFoods.contains(where: { $0.id == response.id }) {
                recentFoods.insert(response, at: 0)
                // Keep only last 20 items
                if recentFoods.count > 20 {
                    recentFoods = Array(recentFoods.prefix(20))
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
     * Create a new food item (for manual entry)
     * - Parameter foodItem: The food item to create
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
            
            return response
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    /**
     * Update an existing food item
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
            }
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Delete a food item
     * - Parameter foodId: The ID of the food item to delete
     */
    func deleteFoodItem(_ foodId: String) async throws {
        isLoading = true
        error = nil
        
        do {
            try await apiService.delete(endpoint: "/nutrition/foods/\(foodId)")
            
            // Remove from recent foods
            recentFoods.removeAll { $0.id == foodId }
            
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    /**
     * Get nutritional analysis for a food item
     * - Parameter foodId: The food item ID
     */
    func getNutritionalAnalysis(for foodId: String) async throws -> FoodNutritionalAnalysis {
        return try await apiService.get(
            endpoint: "/nutrition/foods/\(foodId)/analysis",
            responseType: FoodNutritionalAnalysis.self
        )
    }
    
    /**
     * Calculate calories for a specific amount of food
     * - Parameter foodId: The food item ID
     * - Parameter amountGrams: Amount in grams
     */
    func calculateCalories(for foodId: String, amountGrams: Double) async throws -> Double {
        let analysis = try await getNutritionalAnalysis(for: foodId)
        return (analysis.caloriesPer100g / 100.0) * amountGrams
    }
}

// MARK: - Data Models

/**
 * Food Item
 * Represents a pet food product
 */
struct FoodItem: Codable, Identifiable {
    let id: String
    let name: String
    let brand: String?
    let barcode: String?
    let nutritionalInfo: NutritionalInfo?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case barcode
        case nutritionalInfo = "nutritional_info"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/**
 * Food Item Request
 * For creating/updating food items
 */
struct FoodItemRequest: Codable {
    let name: String
    let brand: String?
    let barcode: String?
    let nutritionalInfo: NutritionalInfo?
    
    enum CodingKeys: String, CodingKey {
        case name
        case brand
        case barcode
        case nutritionalInfo = "nutritional_info"
    }
}



// MARK: - Extensions

extension FoodService {
    /**
     * Get popular food brands
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
     */
    func getFoodCategories() -> [String] {
        // This would be more sophisticated in a real implementation
        // For now, return common pet food categories
        return ["Dry Food", "Wet Food", "Treats", "Supplements", "Raw Food"]
    }
    
    /**
     * Search foods with filters
     * - Parameter query: Search query
     * - Parameter brand: Brand filter
     * - Parameter category: Category filter
     */
    func searchFoodsWithFilters(query: String, brand: String? = nil, category: String? = nil) async throws -> [FoodItem] {
        var endpoint = "/nutrition/foods/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let brand = brand {
            endpoint += "&brand=\(brand.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        
        if let category = category {
            endpoint += "&category=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }
        
        return try await apiService.get(
            endpoint: endpoint,
            responseType: [FoodItem].self
        )
    }
}
