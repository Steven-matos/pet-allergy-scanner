//
//  GDPRService.swift
//  SniffTest
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
        guard await apiService.hasAuthToken else {
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
        guard await apiService.hasAuthToken else {
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
        guard await apiService.hasAuthToken else {
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
    
    /// Anonymize user data
    func anonymizeUserData() async -> Bool {
        guard await apiService.hasAuthToken else {
            errorMessage = "Authentication required"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await apiService.anonymizeUserData()
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    /// Delete user data including all images from storage
    func deleteUserData() async -> Bool {
        guard await apiService.hasAuthToken else {
            errorMessage = "Authentication required"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Get current user data to access image URLs before deletion
            if let currentUser = AuthService.shared.currentUser {
                // Delete user profile image if it exists
                if let imageUrl = currentUser.imageUrl, 
                   imageUrl.contains(Configuration.supabaseURL) {
                    do {
                        try await StorageService.shared.deleteUserImage(path: imageUrl)
                        print("🗑️ User profile image deleted from Supabase: \(imageUrl)")
                    } catch {
                        print("⚠️ Failed to delete user profile image: \(error)")
                        // Continue with account deletion even if image deletion fails
                    }
                }
                
                // Delete all pet images for this user
                for pet in PetService.shared.pets {
                    if let imageUrl = pet.imageUrl,
                       imageUrl.contains(Configuration.supabaseURL) {
                        do {
                            try await StorageService.shared.deletePetImage(path: imageUrl)
                            print("🗑️ Pet image deleted from Supabase: \(imageUrl)")
                        } catch {
                            print("⚠️ Failed to delete pet image: \(error)")
                            // Continue with account deletion even if image deletion fails
                        }
                    }
                }
            }
            
            // Delete user data from backend (this will also delete images from backend)
            try await apiService.deleteUserData()
            
            // Clear local auth state
            await AuthService.shared.logout()
            
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
