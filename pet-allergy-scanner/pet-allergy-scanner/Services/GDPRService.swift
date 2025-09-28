//
//  GDPRService.swift
//  pet-allergy-scanner
//
//  Created by Code Assistant, 2025.
//

import Foundation
import Combine

/// GDPR compliance service for managing user data rights and privacy
@MainActor
class GDPRService: ObservableObject {
    static let shared = GDPRService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dataRetentionInfo: DataRetentionInfo?
    @Published var dataSubjectRights: DataSubjectRights?
    @Published var userData: Data?
    
    private let apiService = APIService.shared
    
    private init() {}
    
    /// Get data retention information
    func getDataRetentionInfo() async {
        guard apiService.hasAuthToken else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            dataRetentionInfo = try await apiService.getDataRetentionInfo()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Get data subject rights information
    func getDataSubjectRights() async {
        guard apiService.hasAuthToken else {
            errorMessage = "Authentication required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            dataSubjectRights = try await apiService.getDataSubjectRights()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Export user data
    func exportUserData() async -> Data? {
        guard apiService.hasAuthToken else {
            errorMessage = "Authentication required"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await apiService.exportUserData()
            userData = data
            isLoading = false
            return data
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
    
    /// Delete user data
    func deleteUserData() async -> Bool {
        guard apiService.hasAuthToken else {
            errorMessage = "Authentication required"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiService.deleteUserData()
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    /// Save exported data to file
    func saveExportedDataToFile() -> URL? {
        guard let data = userData else { return nil }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "user_data_export_\(Date().timeIntervalSince1970).json"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            errorMessage = "Failed to save exported data: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    /// Reset service state
    func reset() {
        dataRetentionInfo = nil
        dataSubjectRights = nil
        userData = nil
        errorMessage = nil
    }
}
