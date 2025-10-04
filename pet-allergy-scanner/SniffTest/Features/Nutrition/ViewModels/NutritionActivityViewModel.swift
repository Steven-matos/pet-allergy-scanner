//
//  NutritionActivityViewModel.swift
//  SniffTest
//
//  Created by Steven Matos on 10/4/25.
//

import Foundation
import Combine

/**
 * ViewModel for managing nutrition activity data
 * 
 * This class follows the MVVM pattern and implements:
 * - SOLID principles with single responsibility for nutrition activity management
 * - DRY principle by reusing existing services
 * - KISS principle with simple, clear data management
 */
@MainActor
class NutritionActivityViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var recentScans: [Scan] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let scanService = ScanService.shared
    private let cachedScanService = CachedScanService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /**
     * Load recent nutrition activity for a specific pet
     * - Parameter petId: The ID of the pet to load activity for
     */
    func loadRecentActivity(for petId: String) {
        print("🔍 NutritionActivityViewModel: Loading recent activity for pet: \(petId)")
        isLoading = true
        errorMessage = nil
        
        Task {
            // Get recent scans for the pet with error handling
            let scans = await getScansSafely(petId: petId)
            
            // Filter to only completed scans with results (nutrition-related)
            let nutritionScans = scans
                .filter { $0.hasResult && $0.result != nil }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(10) // Limit to 10 most recent
            
            await MainActor.run {
                self.recentScans = Array(nutritionScans)
                self.isLoading = false
                print("🔍 NutritionActivityViewModel: Loaded \(self.recentScans.count) recent scans")
            }
        }
    }
    
    /**
     * Safely get scans with error handling for cache issues
     */
    private func getScansSafely(petId: String) async -> [Scan] {
        // Try cached service first
        let cachedScans = await cachedScanService.getScansForPetWithFallback(petId: petId)
        
        // If we got results, return them
        if !cachedScans.isEmpty {
            return cachedScans
        }
        
        // Fallback to direct API call if cache is empty
        do {
            print("🔍 NutritionActivityViewModel: Cache empty, trying direct API call")
            return try await APIService.shared.getScans(petId: petId)
        } catch {
            print("🔍 NutritionActivityViewModel: API call failed: \(error)")
            return []
        }
    }
    
    /**
     * Refresh nutrition activity data
     * - Parameter petId: The ID of the pet to refresh activity for
     */
    func refreshActivity(for petId: String) {
        print("🔍 NutritionActivityViewModel: Refreshing activity for pet: \(petId)")
        loadRecentActivity(for: petId)
    }
    
    /**
     * Clear cache and refresh nutrition activity data
     * - Parameter petId: The ID of the pet to refresh activity for
     */
    func clearCacheAndRefresh(for petId: String) {
        print("🔍 NutritionActivityViewModel: Clearing cache and refreshing activity for pet: \(petId)")
        
        // Clear the cache
        cachedScanService.clearScans()
        
        // Refresh the data
        loadRecentActivity(for: petId)
    }
    
    // MARK: - Private Methods
    
    /**
     * Setup reactive bindings to scan service updates
     */
    private func setupBindings() {
        // Listen for scan service updates
        scanService.$recentScans
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Trigger refresh when scans are updated
                if let petId = self?.getCurrentPetId() {
                    self?.loadRecentActivity(for: petId)
                }
            }
            .store(in: &cancellables)
    }
    
    /**
     * Get current pet ID from the selected pet context
     * This would typically come from a parent view or service
     */
    private func getCurrentPetId() -> String? {
        // For now, return nil - this will be set by the parent view
        // In a more complex app, this might come from a pet selection service
        return nil
    }
}

// MARK: - Helper Extensions

extension NutritionActivityViewModel {
    /**
     * Get formatted date string for display
     * - Parameter date: The date to format
     * - Returns: Formatted date string
     */
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    /**
     * Get nutrition activity description from scan result
     * - Parameter scan: The scan to get description for
     * - Returns: Formatted activity description
     */
    func getActivityDescription(for scan: Scan) -> String {
        guard let result = scan.result else {
            return "Scanned product"
        }
        
        return "Scanned \(result.productName ?? "Unknown Product")"
    }
    
    /**
     * Get nutrition result description from scan
     * - Parameter scan: The scan to get result for
     * - Returns: Formatted result description
     */
    func getResultDescription(for scan: Scan) -> String {
        guard let result = scan.result else {
            return "Analysis pending"
        }
        
        switch result.overallSafety.lowercased() {
        case "safe":
            return "Safe for your pet"
        case "caution", "warning":
            return "Contains potential allergens"
        case "unsafe":
            return "Contains known allergens"
        default:
            return "Analysis incomplete"
        }
    }
    
    /**
     * Get color for nutrition result
     * - Parameter scan: The scan to get color for
     * - Returns: Color for the result
     */
    func getResultColor(for scan: Scan) -> String {
        guard let result = scan.result else {
            return "gray"
        }
        
        switch result.overallSafety.lowercased() {
        case "safe":
            return "green"
        case "caution", "warning":
            return "orange"
        case "unsafe":
            return "red"
        default:
            return "gray"
        }
    }
}
