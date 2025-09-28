//
//  ScanService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import UIKit
import Combine

/// Scan service for managing scan operations and history
@MainActor
class ScanService: ObservableObject {
    static let shared = ScanService()
    
    @Published var recentScans: [Scan] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAnalyzing = false
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentAnalysisTask: Task<Void, Never>?
    
    private init() {}
    
    /// Load recent scans for the current user
    func loadRecentScans() {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let scans = try await apiService.getScans()
                recentScans = scans.sorted { $0.createdAt > $1.createdAt }
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Create a new scan
    func createScan(petId: String, image: UIImage?, extractedText: String?) {
        isLoading = true
        errorMessage = nil
        
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
}
