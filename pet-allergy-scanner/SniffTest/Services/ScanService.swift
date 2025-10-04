//
//  ScanService.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import UIKit
import Combine

/// Scan service for managing scan operations and history
/// Respects user settings for auto-save and analysis behavior
@MainActor
class ScanService: ObservableObject {
    static let shared = ScanService()
    
    @Published var recentScans: [Scan] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAnalyzing = false
    
    private let apiService = APIService.shared
    private let settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentAnalysisTask: Task<Void, Never>?
    
    private init() {}
    
    /// Load recent scans for the current user
    /// - Note: Only loads scans if user is authenticated to avoid 403 errors during logout
    func loadRecentScans() {
        // Don't attempt to load scans if not authenticated
        guard apiService.hasAuthToken else {
            self.recentScans = []
            self.isLoading = false
            self.errorMessage = nil
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let scans = try await apiService.getScans()
                recentScans = scans.sorted { $0.createdAt > $1.createdAt }
                isLoading = false
            } catch let apiError as APIError {
                self.isLoading = false
                // Silently ignore auth errors (user might be logging out)
                if case .authenticationError = apiError {
                    self.recentScans = []
                    self.errorMessage = nil
                } else {
                    self.errorMessage = apiError.localizedDescription
                }
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Create a new scan
    /// Respects the auto-save setting to determine if scan should be saved to server
    /// - Parameters:
    ///   - petId: Pet ID for the scan
    ///   - image: Captured image (optional)
    ///   - extractedText: Text extracted from image (optional)
    func createScan(petId: String, image: UIImage?, extractedText: String?) {
        isLoading = true
        errorMessage = nil
        
        // Check if auto-save is enabled
        guard settingsManager.shouldAutoSaveScans else {
            // If auto-save is disabled, just create a local scan without saving to server
            let localScan = Scan(
                id: UUID().uuidString,
                userId: "local",
                petId: petId,
                imageUrl: nil,
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
            imageUrl: nil, // In a real app, you would upload the image first
            rawText: extractedText,
            status: .pending
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
    
    /// Analyze scan text with proper task management
    func analyzeScan(_ analysisRequest: ScanAnalysisRequest, completion: @escaping (Scan) -> Void) {
        // Cancel any existing analysis task
        currentAnalysisTask?.cancel()
        
        isAnalyzing = true
        errorMessage = nil
        
        // Use Task to handle async API call
        currentAnalysisTask = Task { @MainActor in
            do {
                let analyzedScan = try await apiService.analyzeScan(analysisRequest)
                
                // Update the scan in our list
                if let index = recentScans.firstIndex(where: { $0.id == analyzedScan.id }) {
                    recentScans[index] = analyzedScan
                } else {
                    recentScans.insert(analyzedScan, at: 0)
                }
                
                isAnalyzing = false
                
                // Notify notification manager of scan completion
                NotificationManager.shared.handleScanCompleted()
                
                completion(analyzedScan)
            } catch {
                isAnalyzing = false
                errorMessage = error.localizedDescription
            }
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
        errorMessage = nil
    }
    
    /// Clear all scans (called during logout)
    func clearScans() {
        recentScans = []
        errorMessage = nil
        isLoading = false
        isAnalyzing = false
        currentAnalysisTask?.cancel()
    }
    
    /// Manually save a scan to the server
    /// Used when auto-save is disabled but user wants to save a specific scan
    /// - Parameter scan: The scan to save
    func saveScanToServer(_ scan: Scan) {
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
