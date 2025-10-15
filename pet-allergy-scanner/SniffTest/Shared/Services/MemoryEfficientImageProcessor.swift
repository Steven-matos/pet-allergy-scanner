//
//  MemoryEfficientImageProcessor.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import UIKit
import Foundation

/**
 * Memory-efficient image processing service
 * 
 * Handles image processing operations with memory optimization to prevent
 * memory pressure and app termination. Implements SOLID principles with
 * single responsibility for image processing.
 */
@MainActor
class MemoryEfficientImageProcessor: ObservableObject {
    static let shared = MemoryEfficientImageProcessor()
    
    // MARK: - Properties
    
    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var errorMessage: String?
    
    private let memoryMonitor = MemoryMonitor.shared
    private let imageCache = MemoryEfficientImageCache.shared
    
    // Processing limits
    private let maxConcurrentOperations = 2
    private let maxImageSize: Int = 5_000_000 // 5MB
    private let targetImageSize: Int = 2_000_000 // 2MB
    
    private init() {}
    
    // MARK: - Public Interface
    
    /**
     * Process image with memory optimization
     * 
     * - Parameters:
     *   - image: Source image
     *   - operation: Processing operation to perform
     *   - completion: Completion handler with processed image
     */
    func processImage(
        _ image: UIImage,
        operation: ImageProcessingOperation,
        completion: @escaping (UIImage?) -> Void
    ) {
        // Check memory pressure before processing
        guard !memoryMonitor.isMemoryPressureHigh else {
            errorMessage = "Memory pressure too high for image processing"
            completion(nil)
            return
        }
        
        // Check if image is too large
        guard image.memoryUsage <= maxImageSize else {
            errorMessage = "Image too large for processing"
            completion(nil)
            return
        }
        
        isProcessing = true
        processingProgress = 0.0
        errorMessage = nil
        
        Task {
            do {
                let processedImage = try await performImageProcessing(image, operation: operation)
                
                await MainActor.run {
                    self.isProcessing = false
                    self.processingProgress = 1.0
                    completion(processedImage)
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    completion(nil)
                }
            }
        }
    }
    
    /**
     * Process image for scanning with optimization
     * 
     * - Parameter image: Source image
     * - Returns: Optimized image for scanning
     */
    func processImageForScanning(_ image: UIImage) async -> UIImage? {
        // Check memory pressure
        guard !memoryMonitor.isMemoryPressureHigh else {
            return nil
        }
        
        // Create thumbnail for scanning (smaller memory footprint)
        let thumbnail = image.createThumbnail(size: 800)
        
        // Further optimize if still too large
        if thumbnail.memoryUsage > targetImageSize {
            return thumbnail.optimizeForMemory(maxMemoryUsage: targetImageSize)
        }
        
        return thumbnail
    }
    
    /**
     * Process image for storage with compression
     * 
     * - Parameter image: Source image
     * - Returns: Compressed image data
     */
    func processImageForStorage(_ image: UIImage) async -> Data? {
        // Check memory pressure
        guard !memoryMonitor.isMemoryPressureHigh else {
            return nil
        }
        
        // Optimize image for storage
        let optimizedImage = image.optimizeForMemory(maxMemoryUsage: targetImageSize)
        
        // Compress to JPEG with quality based on image size
        let quality: CGFloat = optimizedImage.memoryUsage > 1_000_000 ? 0.7 : 0.8
        
        return optimizedImage.jpegData(compressionQuality: quality)
    }
    
    /**
     * Clear processing cache and free memory
     */
    func clearCache() {
        imageCache.clearCache()
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    func performImageProcessing(
        _ image: UIImage,
        operation: ImageProcessingOperation
    ) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let processedImage: UIImage
                    
                    switch operation {
                    case .resize(let maxDimension):
                        processedImage = image.resizedImage(maxDimension: maxDimension)
                        
                    case .thumbnail(let size):
                        processedImage = image.createThumbnail(size: size)
                        
                    case .optimize(let maxMemoryUsage):
                        processedImage = image.optimizeForMemory(maxMemoryUsage: maxMemoryUsage)
                        
                    case .compress(let quality):
                        guard let data = image.jpegData(compressionQuality: quality),
                              let compressedImage = UIImage(data: data) else {
                            throw ImageProcessingError.compressionFailed
                        }
                        processedImage = compressedImage
                    }
                    
                    continuation.resume(returning: processedImage)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

/**
 * Image processing operations
 */
enum ImageProcessingOperation {
    case resize(maxDimension: CGFloat)
    case thumbnail(size: CGFloat)
    case optimize(maxMemoryUsage: Int)
    case compress(quality: CGFloat)
}

/**
 * Image processing errors
 */
enum ImageProcessingError: LocalizedError {
    case compressionFailed
    case memoryPressureTooHigh
    case imageTooLarge
    case processingTimeout
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .memoryPressureTooHigh:
            return "Memory pressure too high for processing"
        case .imageTooLarge:
            return "Image too large for processing"
        case .processingTimeout:
            return "Image processing timed out"
        }
    }
}

/**
 * Memory-efficient image batch processor
 * 
 * Processes multiple images with memory management
 */
@MainActor
class MemoryEfficientBatchProcessor: ObservableObject {
    static let shared = MemoryEfficientBatchProcessor()
    
    @Published var isProcessing = false
    @Published var processedCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var errorMessage: String?
    
    private let imageProcessor = MemoryEfficientImageProcessor.shared
    private let memoryMonitor = MemoryMonitor.shared
    
    private init() {}
    
    /**
     * Process multiple images with memory management
     * 
     * - Parameters:
     *   - images: Array of images to process
     *   - operation: Processing operation
     *   - completion: Completion handler with processed images
     */
    func processImages(
        _ images: [UIImage],
        operation: ImageProcessingOperation,
        completion: @escaping ([UIImage]) -> Void
    ) {
        guard !images.isEmpty else {
            completion([])
            return
        }
        
        isProcessing = true
        processedCount = 0
        totalCount = images.count
        errorMessage = nil
        
        Task {
            var processedImages: [UIImage] = []
            
            for (index, image) in images.enumerated() {
                // Check memory pressure before each image
                if memoryMonitor.isMemoryPressureHigh {
                    await MainActor.run {
                        self.errorMessage = "Memory pressure too high, stopping batch processing"
                        self.isProcessing = false
                    }
                    break
                }
                
                do {
                    let processedImage = try await imageProcessor.performImageProcessing(
                        image,
                        operation: operation
                    )
                    processedImages.append(processedImage)
                    
                    await MainActor.run {
                        self.processedCount = index + 1
                    }
                    
                    // Small delay to prevent overwhelming the system
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to process image \(index + 1): \(error.localizedDescription)"
                    }
                }
            }
            
            await MainActor.run {
                self.isProcessing = false
                completion(processedImages)
            }
        }
    }
}
