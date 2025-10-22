//
//  ScanService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import UIKit
import Combine

/**
 * Scan-related errors
 */
enum ScanError: Error, LocalizedError {
    case analysisInProgress
    case invalidRequest
    case networkError
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .analysisInProgress:
            return "Analysis is already in progress"
        case .invalidRequest:
            return "Invalid analysis request"
        case .networkError:
            return "Network connection error"
        case .parsingError:
            return "Failed to parse scan results"
        }
    }
}

/// Scan service for managing scan operations and history
/// Respects user settings for auto-save and analysis behavior
@MainActor
class ScanService: ObservableObject, @unchecked Sendable {
    static let shared = ScanService()
    
    @Published var recentScans: [Scan] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAnalyzing = false
    
    private let apiService = APIService.shared
    private let settingsManager: SettingsManager
    private var cancellables = Set<AnyCancellable>()
    private var currentAnalysisTask: Task<Void, Never>?
    
    private init() {
        // Access SettingsManager.shared on the main actor
        self.settingsManager = MainActor.assumeIsolated {
            SettingsManager.shared
        }
    }
    
    /// Load recent scans for the current user
    /// - Note: Only loads scans if user is authenticated to avoid 403 errors during logout
    func loadRecentScans() {
        Task {
            // Don't attempt to load scans if not authenticated
            guard await apiService.hasAuthToken else {
                await MainActor.run {
                    self.recentScans = []
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
                let scans = try await apiService.getScans()
                await MainActor.run {
                    recentScans = scans.sorted { $0.createdAt > $1.createdAt }
                    isLoading = false
                }
            } catch let apiError as APIError {
                await MainActor.run {
                    self.isLoading = false
                    // Silently ignore auth errors (user might be logging out)
                    if case .authenticationError = apiError {
                        self.recentScans = []
                        self.errorMessage = nil
                    } else {
                        self.errorMessage = apiError.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Create a new scan
    /// Respects the auto-save setting to determine if scan should be saved to server
    /// - Parameters:
    ///   - petId: Pet ID for the scan
    ///   - image: Captured image (optional)
    ///   - extractedText: Text extracted from image (optional)
    @MainActor func createScan(petId: String, image: UIImage?, extractedText: String?) {
        isLoading = true
        errorMessage = nil
        
        // Check if auto-save is enabled
        guard settingsManager.shouldAutoSaveScans else {
            // If auto-save is disabled, just create a local scan without saving to server
            let localScan = Scan(
                id: UUID().uuidString,
                userId: "local",
                petId: petId,
                imageUrl: nil,  // Local scans don't save images
                rawText: extractedText,
                status: .pending,
                result: nil,
                nutritionalAnalysis: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            recentScans.insert(localScan, at: 0)
            isLoading = false
            return
        }
        
        let scanCreate = ScanCreate(
            petId: petId,
            imageUrl: nil,  // Image uploaded server-side for OCR scans
            rawText: extractedText,
            status: .pending,
            scanMethod: .ocr  // Default to OCR
        )
        
        Task { @MainActor in
            do {
                let scan = try await apiService.createScan(scanCreate)
                recentScans.insert(scan, at: 0)
                isLoading = false
                
                // Notify notification manager of scan completion
                NotificationManager.shared.handleScanCompleted()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Analyze scan text with proper task management (legacy callback-based)
    func analyzeScan(_ analysisRequest: ScanAnalysisRequest, completion: @escaping (Scan) -> Void) {
        // Cancel any existing analysis task
        currentAnalysisTask?.cancel()
        
        isAnalyzing = true
        errorMessage = nil
        
        print("🔍 [SCAN_SERVICE] Starting analysis with request: \(analysisRequest)")
        
        // Use Task to handle async API call
        currentAnalysisTask = Task { @MainActor in
            do {
                print("🔍 [SCAN_SERVICE] Calling apiService.analyzeScan...")
                let analyzedScan = try await apiService.analyzeScan(analysisRequest)
                print("🔍 [SCAN_SERVICE] ✅ API call successful, received scan: \(analyzedScan.id)")
                
                // Update the scan in our list
                if let index = recentScans.firstIndex(where: { $0.id == analyzedScan.id }) {
                    recentScans[index] = analyzedScan
                } else {
                    recentScans.insert(analyzedScan, at: 0)
                }
                
                isAnalyzing = false
                
                // Notify notification manager of scan completion
                NotificationManager.shared.handleScanCompleted()
                
                print("🔍 [SCAN_SERVICE] Calling completion handler...")
                completion(analyzedScan)
                print("🔍 [SCAN_SERVICE] ✅ Completion handler called successfully")
               } catch {
                   print("🔍 [SCAN_SERVICE] ❌ Error during analysis: \(error.localizedDescription)")
                   print("🔍 [SCAN_SERVICE] ❌ Error type: \(type(of: error))")
                   isAnalyzing = false
                   errorMessage = error.localizedDescription
                   
                   // Create a more informative error scan based on the error type
                   let errorDetails: [String: String]
                   let overallSafety: String
                   
                   if error.localizedDescription.contains("500") || error.localizedDescription.contains("Server error") {
                       // Perform client-side fallback analysis
                       print("🔍 [SCAN_SERVICE] 🔄 Server error detected, performing client-side fallback analysis...")
                       let fallbackAnalysis = performClientSideAnalysis(analysisRequest.extractedText)
                       print("🔍 [SCAN_SERVICE] ✅ Fallback analysis complete:")
                       print("🔍 [SCAN_SERVICE] - Overall Safety: \(fallbackAnalysis.overallSafety)")
                       print("🔍 [SCAN_SERVICE] - Safe Ingredients: \(fallbackAnalysis.safeIngredients)")
                       print("🔍 [SCAN_SERVICE] - Unsafe Ingredients: \(fallbackAnalysis.unsafeIngredients)")
                       print("🔍 [SCAN_SERVICE] - Caution Ingredients: \(fallbackAnalysis.cautionIngredients)")
                       
                       errorDetails = [
                           "error": "Server temporarily unavailable",
                           "message": "Using offline analysis while server is being fixed.",
                           "ingredients": analysisRequest.extractedText,
                           "analysis_type": "client_side_fallback"
                       ]
                       overallSafety = fallbackAnalysis.overallSafety
                   } else {
                       errorDetails = [
                           "error": "Analysis failed",
                           "message": error.localizedDescription,
                           "ingredients": analysisRequest.extractedText
                       ]
                       overallSafety = "unknown"
                   }
                   
                   // Create error scan with fallback analysis if available
                   let fallbackAnalysis = error.localizedDescription.contains("500") || error.localizedDescription.contains("Server error") 
                       ? performClientSideAnalysis(analysisRequest.extractedText) 
                       : (overallSafety, [], [], [])
                   
                   let errorScan = Scan(
                       id: UUID().uuidString,
                       userId: "error-user",
                       petId: analysisRequest.petId,
                       imageUrl: nil,
                       rawText: analysisRequest.extractedText,
                       status: .failed,
                       result: ScanResult(
                           productName: analysisRequest.productName,
                           brand: nil,
                           ingredientsFound: fallbackAnalysis.1 + fallbackAnalysis.2 + fallbackAnalysis.3,
                           unsafeIngredients: fallbackAnalysis.3,
                           safeIngredients: fallbackAnalysis.1,
                           overallSafety: fallbackAnalysis.0,
                           confidenceScore: 0.7, // Higher confidence for client-side analysis
                           analysisDetails: errorDetails
                       ),
                       nutritionalAnalysis: nil,
                       createdAt: Date(),
                       updatedAt: Date()
                   )
                   
                   print("🔍 [SCAN_SERVICE] Creating error scan and calling completion...")
                   completion(errorScan)
               }
        }
    }
    
    /// Perform client-side fallback analysis when server is unavailable
    private func performClientSideAnalysis(_ ingredientText: String) -> (overallSafety: String, safeIngredients: [String], unsafeIngredients: [String], cautionIngredients: [String]) {
        let ingredients = ingredientText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        var safeIngredients: [String] = []
        var unsafeIngredients: [String] = []
        var cautionIngredients: [String] = []
        
        // Known dangerous ingredients for pets
        let dangerousIngredients = [
            "chocolate", "cocoa", "xylitol", "grapes", "raisins", "onions", "garlic", "avocado",
            "macadamia nuts", "walnuts", "alcohol", "caffeine", "artificial sweeteners",
            "xylitol", "sorbitol", "mannitol", "erythritol", "stevia", "saccharin", "aspartame"
        ]
        
        // Known caution ingredients
        let cautionIngredientsList = [
            "salt", "sodium", "sugar", "corn syrup", "high fructose", "preservatives",
            "artificial colors", "artificial flavors", "bha", "bht", "ethoxyquin"
        ]
        
        // Known safe ingredients
        let safeIngredientsList = [
            "chicken", "beef", "turkey", "fish", "salmon", "rice", "brown rice",
            "oats", "barley", "sweet potato", "carrots", "peas", "blueberries",
            "cranberries", "pumpkin", "spinach", "broccoli", "flaxseed", "omega-3"
        ]
        
        for ingredient in ingredients {
            let lowercased = ingredient.lowercased()
            
            if dangerousIngredients.contains(where: { lowercased.contains($0) }) {
                unsafeIngredients.append(ingredient)
            } else if cautionIngredientsList.contains(where: { lowercased.contains($0) }) {
                cautionIngredients.append(ingredient)
            } else if safeIngredientsList.contains(where: { lowercased.contains($0) }) {
                safeIngredients.append(ingredient)
            } else {
                // Unknown ingredients go to caution
                cautionIngredients.append(ingredient)
            }
        }
        
        // Determine overall safety
        let overallSafety: String
        if !unsafeIngredients.isEmpty {
            overallSafety = "dangerous"
        } else if !cautionIngredients.isEmpty {
            overallSafety = "caution"
        } else if !safeIngredients.isEmpty {
            overallSafety = "safe"
        } else {
            overallSafety = "unknown"
        }
        
        return (overallSafety, safeIngredients, unsafeIngredients, cautionIngredients)
    }
    
    /// Analyze scan with Swift 6 concurrency optimization
    /// - Parameter analysisRequest: Analysis request with pet and scan data
    /// - Returns: Scan result
    func analyzeScanAsync(_ analysisRequest: ScanAnalysisRequest) async throws -> Scan {
        // Cancel any existing analysis task
        currentAnalysisTask?.cancel()
        
        guard !isAnalyzing else {
            throw ScanError.analysisInProgress
        }
        
        isAnalyzing = true
        errorMessage = nil
        
        defer {
            isAnalyzing = false
        }
        
        do {
            let analyzedScan = try await apiService.analyzeScan(analysisRequest)
            
            // Update the scan in our list
            if let index = recentScans.firstIndex(where: { $0.id == analyzedScan.id }) {
                recentScans[index] = analyzedScan
            } else {
                recentScans.insert(analyzedScan, at: 0)
            }
            
            // Notify notification manager of scan completion
            NotificationManager.shared.handleScanCompleted()
            
            return analyzedScan
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Cancel current analysis task
    func cancelAnalysis() {
        currentAnalysisTask?.cancel()
        isAnalyzing = false
    }
    
    /// Get scan by ID
    func getScan(id: String) -> Scan? {
        return recentScans.first { $0.id == id }
    }
    
    /// Clear error message
    func clearError() {
        Task { @MainActor in
            errorMessage = nil
        }
    }
    
    /// Clear all scans (called during logout)
    func clearScans() {
        Task { @MainActor in
            recentScans = []
            errorMessage = nil
            isLoading = false
            isAnalyzing = false
            currentAnalysisTask?.cancel()
        }
    }
    
    /// Clear all scans from server and local storage
    func clearAllScans() async throws {
        // Clear from server
        try await apiService.clearAllScans()
        
        // Clear local storage
        await MainActor.run {
            recentScans = []
            errorMessage = nil
            isLoading = false
            isAnalyzing = false
            currentAnalysisTask?.cancel()
        }
    }
    
    /// Manually save a scan to the server
    /// Used when auto-save is disabled but user wants to save a specific scan
    /// - Parameter scan: The scan to save
    @MainActor func saveScanToServer(_ scan: Scan) {
        guard settingsManager.shouldAutoSaveScans == false else { return }
        
        let scanCreate = ScanCreate(
            petId: scan.petId,
            imageUrl: scan.imageUrl,
            rawText: scan.rawText,
            status: scan.status
        )
        
        Task { @MainActor in
            do {
                let savedScan = try await apiService.createScan(scanCreate)
                // Update the local scan with server data
                if let index = recentScans.firstIndex(where: { $0.id == scan.id }) {
                    recentScans[index] = savedScan
                }
            } catch {
                errorMessage = "Failed to save scan: \(error.localizedDescription)"
            }
        }
    }
}
