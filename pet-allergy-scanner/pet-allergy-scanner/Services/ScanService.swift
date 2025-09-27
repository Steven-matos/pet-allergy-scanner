//
//  ScanService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import Combine

/// Scan service for managing scan operations and history
class ScanService: ObservableObject {
    static let shared = ScanService()
    
    @Published var recentScans: [Scan] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    /// Load recent scans for the current user
    func loadRecentScans() {
        isLoading = true
        errorMessage = nil
        
        apiService.getScans()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] scans in
                    self?.recentScans = scans.sorted { $0.createdAt > $1.createdAt }
                }
            )
            .store(in: &cancellables)
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
        
        apiService.createScan(scanCreate)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] scan in
                    self?.recentScans.insert(scan, at: 0)
                }
            )
            .store(in: &cancellables)
    }
    
    /// Analyze scan text
    func analyzeScan(_ analysisRequest: ScanAnalysisRequest, completion: @escaping (Scan) -> Void) {
        isLoading = true
        errorMessage = nil
        
        apiService.analyzeScan(analysisRequest)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] scan in
                    if let index = self?.recentScans.firstIndex(where: { $0.id == scan.id }) {
                        self?.recentScans[index] = scan
                    } else {
                        self?.recentScans.insert(scan, at: 0)
                    }
                    completion(scan)
                }
            )
            .store(in: &cancellables)
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
