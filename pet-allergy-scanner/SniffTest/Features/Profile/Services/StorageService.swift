//
//  StorageService.swift
//  SniffTest
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
    
    private init() {}
    
    /// Upload image to Supabase Storage with automatic optimization
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user ID for folder organization
    ///   - bucket: The storage bucket name
    ///   - subfolder: Optional subfolder path (e.g., petId for pet images)
    ///   - imageType: Type of image for logging purposes
    /// - Returns: The public URL of the uploaded image
    private func uploadImage(
        image: UIImage, 
        userId: String, 
        bucket: String, 
        subfolder: String? = nil,
        imageType: String = "image"
    ) async throws -> String {
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
            print("📸 \(imageType.capitalized) image optimized: \(optimizedResult.summary)")
        } catch {
            throw StorageError.optimizationFailed(error.localizedDescription)
        }
        
        uploadProgress = 0.3
        
        // Generate unique filename and build file path
        let filename = "\(UUID().uuidString).jpg"
        let filePath: String
        if let subfolder = subfolder {
            filePath = "\(userId)/\(subfolder)/\(filename)"
        } else {
            filePath = "\(userId)/\(filename)"
        }
        
        uploadProgress = 0.5
        
        // Upload optimized image to Supabase Storage
        let uploadedPath = try await uploadFile(
            data: optimizedResult.data,
            path: filePath,
            contentType: "image/jpeg",
            bucket: bucket
        )
        
        uploadProgress = 0.9
        
        // Get public URL
        let publicURL = getPublicURL(path: uploadedPath, bucket: bucket)
        
        uploadProgress = 1.0
        
        return publicURL
    }
    
    /// Upload user profile image to Supabase Storage with automatic optimization
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user ID for folder organization
    /// - Returns: The public URL of the uploaded image
    func uploadUserImage(image: UIImage, userId: String) async throws -> String {
        return try await uploadImage(
            image: image,
            userId: userId,
            bucket: Configuration.userBucketName,
            imageType: "user"
        )
    }
    
    /// Upload pet image to Supabase Storage with automatic optimization
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user ID for folder organization
    ///   - petId: The pet ID for file naming
    /// - Returns: The public URL of the uploaded image
    func uploadPetImage(image: UIImage, userId: String, petId: String) async throws -> String {
        return try await uploadImage(
            image: image,
            userId: userId,
            bucket: Configuration.petBucketName,
            subfolder: petId,
            imageType: "pet"
        )
    }
    
    /// Upload file data to Supabase Storage
    /// - Parameters:
    ///   - data: The file data to upload
    ///   - path: The storage path (folder/filename)
    ///   - contentType: The MIME type of the file
    ///   - bucket: The storage bucket name
    /// - Returns: The storage path of the uploaded file
    private func uploadFile(data: Data, path: String, contentType: String, bucket: String) async throws -> String {
        guard let baseURL = URL(string: Configuration.supabaseURL) else {
            throw StorageError.invalidConfiguration
        }
        
        let uploadURL = baseURL
            .appendingPathComponent("storage")
            .appendingPathComponent("v1")
            .appendingPathComponent("object")
            .appendingPathComponent(bucket)
            .appendingPathComponent(path)
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(await apiService.getAuthToken() ?? "")", forHTTPHeaderField: "Authorization")
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
    /// - Parameters:
    ///   - path: The storage path
    ///   - bucket: The storage bucket name
    /// - Returns: The public URL string
    private func getPublicURL(path: String, bucket: String) -> String {
        return "\(Configuration.supabaseURL)/storage/v1/object/public/\(bucket)/\(path)"
    }
    
    /// Delete image from Supabase Storage
    /// - Parameters:
    ///   - path: The storage path to delete
    ///   - bucket: The storage bucket name
    private func deleteImage(path: String, bucket: String) async throws {
        guard let baseURL = URL(string: Configuration.supabaseURL) else {
            throw StorageError.invalidConfiguration
        }
        
        // Extract path from full URL if needed
        let storagePath = path.contains("/storage/v1/object/public/") 
            ? path.components(separatedBy: "/storage/v1/object/public/\(bucket)/").last ?? path
            : path
        
        let deleteURL = baseURL
            .appendingPathComponent("storage")
            .appendingPathComponent("v1")
            .appendingPathComponent("object")
            .appendingPathComponent(bucket)
            .appendingPathComponent(storagePath)
        
        var request = URLRequest(url: deleteURL)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(await apiService.getAuthToken() ?? "")", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw StorageError.deleteFailed
        }
    }
    
    /// Delete pet image from Supabase Storage
    /// - Parameter path: The storage path to delete
    func deletePetImage(path: String) async throws {
        try await deleteImage(path: path, bucket: Configuration.petBucketName)
    }
    
    /// Replace old image with new one (delete old, upload new)
    /// - Parameters:
    ///   - oldImageUrl: The URL of the old image to delete
    ///   - newImage: The new image to upload
    ///   - userId: The user ID for folder organization
    ///   - bucket: The storage bucket name
    ///   - subfolder: Optional subfolder path (e.g., petId for pet images)
    ///   - imageType: Type of image for logging purposes
    /// - Returns: The public URL of the new uploaded image
    private func replaceImage(
        oldImageUrl: String?,
        newImage: UIImage,
        userId: String,
        bucket: String,
        subfolder: String? = nil,
        imageType: String = "image"
    ) async throws -> String {
        // Delete old image if it exists and is a Supabase URL
        if let oldUrl = oldImageUrl, !oldUrl.isEmpty {
            if oldUrl.contains(Configuration.supabaseURL) {
                do {
                    try await deleteImage(path: oldUrl, bucket: bucket)
                    print("🗑️ Old \(imageType) image deleted: \(oldUrl)")
                } catch {
                    print("⚠️ Failed to delete old image (continuing with upload): \(error)")
                    // Continue with upload even if deletion fails
                }
            } else {
                print("ℹ️ Old image is local file, skipping deletion: \(oldUrl)")
            }
        }
        
        // Upload new image using the generic upload function
        return try await uploadImage(
            image: newImage,
            userId: userId,
            bucket: bucket,
            subfolder: subfolder,
            imageType: imageType
        )
    }
    
    /// Delete old pet image and upload new one
    /// - Parameters:
    ///   - oldImageUrl: The URL of the old image to delete
    ///   - newImage: The new image to upload
    ///   - userId: The user ID for folder organization
    ///   - petId: The pet ID for file naming
    /// - Returns: The public URL of the new uploaded image
    func replacePetImage(
        oldImageUrl: String?,
        newImage: UIImage,
        userId: String,
        petId: String
    ) async throws -> String {
        return try await replaceImage(
            oldImageUrl: oldImageUrl,
            newImage: newImage,
            userId: userId,
            bucket: Configuration.petBucketName,
            subfolder: petId,
            imageType: "pet"
        )
    }
    
    /// Delete old user image and upload new one
    /// - Parameters:
    ///   - oldImageUrl: The URL of the old image to delete
    ///   - newImage: The new image to upload
    ///   - userId: The user ID for folder organization
    /// - Returns: The public URL of the new uploaded image
    func replaceUserImage(
        oldImageUrl: String?,
        newImage: UIImage,
        userId: String
    ) async throws -> String {
        return try await replaceImage(
            oldImageUrl: oldImageUrl,
            newImage: newImage,
            userId: userId,
            bucket: Configuration.userBucketName,
            imageType: "user"
        )
    }
    
    /// Delete user image from Supabase Storage
    /// - Parameter path: The storage path to delete
    func deleteUserImage(path: String) async throws {
        try await deleteImage(path: path, bucket: Configuration.userBucketName)
    }
    
    /// Upload document (PDF or image) for vet paperwork
    /// - Parameters:
    ///   - data: The document data to upload
    ///   - userId: The user ID for folder organization
    ///   - petId: The pet ID for folder organization
    ///   - healthEventId: The health event ID for folder organization
    ///   - contentType: The MIME type of the document (e.g., "application/pdf", "image/jpeg")
    ///   - fileName: Optional custom filename
    /// - Returns: The public URL of the uploaded document
    func uploadVetDocument(
        data: Data,
        userId: String,
        petId: String,
        healthEventId: String,
        contentType: String,
        fileName: String? = nil
    ) async throws -> String {
        isUploading = true
        uploadProgress = 0.0
        errorMessage = nil
        
        defer {
            isUploading = false
            uploadProgress = 0.0
        }
        
        uploadProgress = 0.2
        
        // Generate unique filename
        let fileExtension: String
        let mimeType: String
        if contentType == "application/pdf" {
            fileExtension = "pdf"
            mimeType = contentType
        } else if contentType.hasPrefix("image/") {
            fileExtension = "jpg"
            mimeType = "image/jpeg"
        } else {
            throw StorageError.invalidConfiguration
        }
        
        let finalFileName = fileName ?? "\(UUID().uuidString).\(fileExtension)"
        let filePath = "\(userId)/\(petId)/health-events/\(healthEventId)/\(finalFileName)"
        
        uploadProgress = 0.5
        
        // Upload document - use pet images bucket for now (we'll create a documents bucket later)
        let uploadedPath = try await uploadFile(
            data: data,
            path: filePath,
            contentType: mimeType,
            bucket: Configuration.petBucketName
        )
        
        uploadProgress = 0.9
        
        // Get public URL
        let publicURL = getPublicURL(path: uploadedPath, bucket: Configuration.petBucketName)
        
        uploadProgress = 1.0
        
        return publicURL
    }
    
    /// Upload UIImage as a document (for vet paperwork)
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user ID for folder organization
    ///   - petId: The pet ID for folder organization
    ///   - healthEventId: The health event ID for folder organization
    /// - Returns: The public URL of the uploaded document
    func uploadVetDocumentImage(
        image: UIImage,
        userId: String,
        petId: String,
        healthEventId: String
    ) async throws -> String {
        // Optimize image first
        let optimizedResult = try ImageOptimizer.optimizeForUpload(image: image)
        
        return try await uploadVetDocument(
            data: optimizedResult.data,
            userId: userId,
            petId: petId,
            healthEventId: healthEventId,
            contentType: "image/jpeg"
        )
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

