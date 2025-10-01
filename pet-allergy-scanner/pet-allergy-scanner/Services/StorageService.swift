//
//  StorageService.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 10/1/25.
//

import Foundation
import UIKit

/// Service for managing file uploads to Supabase Storage
@MainActor
class StorageService: ObservableObject {
    static let shared = StorageService()
    
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private let bucketName = "pet-images"
    
    private init() {}
    
    /// Upload pet image to Supabase Storage with automatic optimization
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user ID for folder organization
    ///   - petId: The pet ID for file naming
    /// - Returns: The public URL of the uploaded image
    func uploadPetImage(image: UIImage, userId: String, petId: String) async throws -> String {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        defer {
            isUploading = false
            uploadProgress = 0.0
        }
        
        // Optimize image with smart compression and resizing
        uploadProgress = 0.1
        
        let optimizedResult: OptimizedImageResult
        do {
            optimizedResult = try ImageOptimizer.optimizeForUpload(image: image)
            print("📸 Image optimized: \(optimizedResult.summary)")
        } catch {
            throw StorageError.optimizationFailed(error.localizedDescription)
        }
        
        uploadProgress = 0.3
        
        // Generate unique filename
        let filename = "\(UUID().uuidString).jpg"
        let filePath = "\(userId)/\(petId)/\(filename)"
        
        uploadProgress = 0.5
        
        // Upload optimized image to Supabase Storage
        let uploadedPath = try await uploadFile(
            data: optimizedResult.data,
            path: filePath,
            contentType: "image/jpeg"
        )
        
        uploadProgress = 0.9
        
        // Get public URL
        let publicURL = getPublicURL(path: uploadedPath)
        
        uploadProgress = 1.0
        
        return publicURL
    }
    
    /// Upload file data to Supabase Storage
    /// - Parameters:
    ///   - data: The file data to upload
    ///   - path: The storage path (folder/filename)
    ///   - contentType: The MIME type of the file
    /// - Returns: The storage path of the uploaded file
    private func uploadFile(data: Data, path: String, contentType: String) async throws -> String {
        guard let baseURL = URL(string: Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "") else {
            throw StorageError.invalidConfiguration
        }
        
        let uploadURL = baseURL
            .appendingPathComponent("storage")
            .appendingPathComponent("v1")
            .appendingPathComponent("object")
            .appendingPathComponent(bucketName)
            .appendingPathComponent(path)
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiService.getAuthToken() ?? "")", forHTTPHeaderField: "Authorization")
        request.httpBody = data
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw StorageError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: responseData, encoding: .utf8) ?? "Upload failed"
            throw StorageError.uploadFailed(errorMessage)
        }
        
        return path
    }
    
    /// Get public URL for a storage path
    /// - Parameter path: The storage path
    /// - Returns: The public URL string
    private func getPublicURL(path: String) -> String {
        guard let baseURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
            return ""
        }
        
        return "\(baseURL)/storage/v1/object/public/\(bucketName)/\(path)"
    }
    
    /// Delete pet image from Supabase Storage
    /// - Parameter path: The storage path to delete
    func deletePetImage(path: String) async throws {
        guard let baseURL = URL(string: Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String ?? "") else {
            throw StorageError.invalidConfiguration
        }
        
        // Extract path from full URL if needed
        let storagePath = path.contains("/storage/v1/object/public/") 
            ? path.components(separatedBy: "/storage/v1/object/public/\(bucketName)/").last ?? path
            : path
        
        let deleteURL = baseURL
            .appendingPathComponent("storage")
            .appendingPathComponent("v1")
            .appendingPathComponent("object")
            .appendingPathComponent(bucketName)
            .appendingPathComponent(storagePath)
        
        var request = URLRequest(url: deleteURL)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiService.getAuthToken() ?? "")", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StorageError.deleteFailed
        }
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

/// Storage-related errors
enum StorageError: LocalizedError {
    case invalidImage
    case invalidConfiguration
    case invalidResponse
    case uploadFailed(String)
    case deleteFailed
    case optimizationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .invalidConfiguration:
            return "Storage configuration error"
        case .invalidResponse:
            return "Invalid response from storage"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .deleteFailed:
            return "Failed to delete image"
        case .optimizationFailed(let message):
            return "Image optimization failed: \(message)"
        }
    }
}

