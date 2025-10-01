//
//  ImageOptimizer.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 10/1/25.
//

import UIKit
import SwiftUI

/// Image optimization utility for compressing and resizing images
/// Ensures images meet size requirements while maintaining quality
struct ImageOptimizer {
    
    /// Maximum file size in bytes (5MB for Supabase free tier)
    static let maxFileSize = 5_242_880 // 5MB
    
    /// Target file size for optimal storage (2MB)
    static let targetFileSize = 2_097_152 // 2MB
    
    /// Maximum image dimension (width or height)
    static let maxDimension: CGFloat = 1024
    
    /// Minimum compression quality (0.0 - 1.0)
    static let minQuality: CGFloat = 0.3
    
    /// Optimize image for upload with smart compression and resizing
    /// - Parameters:
    ///   - image: The source UIImage
    ///   - targetSize: Optional target file size in bytes (defaults to targetFileSize)
    ///   - maxSize: Optional maximum file size in bytes (defaults to maxFileSize)
    /// - Returns: Optimized image data and metadata
    /// - Throws: ImageOptimizationError if optimization fails
    static func optimizeForUpload(
        image: UIImage,
        targetSize: Int = targetFileSize,
        maxSize: Int = maxFileSize
    ) throws -> OptimizedImageResult {
        
        var currentImage = image
        var currentData: Data?
        var currentQuality: CGFloat = 0.85 // Start with high quality
        var compressionAttempts = 0
        let maxAttempts = 8
        
        // Step 1: Resize if image is too large
        if shouldResize(image) {
            currentImage = resizeImage(image, maxDimension: maxDimension)
        }
        
        // Step 2: Initial compression attempt
        currentData = currentImage.jpegData(compressionQuality: currentQuality)
        
        guard var data = currentData else {
            throw ImageOptimizationError.compressionFailed
        }
        
        // Step 3: Progressive compression if needed
        while data.count > targetSize && compressionAttempts < maxAttempts {
            compressionAttempts += 1
            
            // Reduce quality progressively
            currentQuality -= 0.1
            
            // Don't go below minimum quality
            if currentQuality < minQuality {
                currentQuality = minQuality
                
                // If still too large, resize further
                let reductionFactor = sqrt(Double(targetSize) / Double(data.count))
                let newDimension = maxDimension * CGFloat(reductionFactor)
                currentImage = resizeImage(currentImage, maxDimension: newDimension)
            }
            
            guard let compressedData = currentImage.jpegData(compressionQuality: currentQuality) else {
                throw ImageOptimizationError.compressionFailed
            }
            
            data = compressedData
        }
        
        // Step 4: Final size check
        if data.count > maxSize {
            throw ImageOptimizationError.exceedsMaxSize(
                currentSize: data.count,
                maxSize: maxSize
            )
        }
        
        // Calculate compression ratio
        let originalSize = image.jpegData(compressionQuality: 1.0)?.count ?? data.count
        let compressionRatio = Double(data.count) / Double(originalSize)
        
        return OptimizedImageResult(
            data: data,
            finalSize: data.count,
            originalSize: originalSize,
            compressionRatio: compressionRatio,
            finalQuality: currentQuality,
            dimensions: currentImage.size,
            compressionAttempts: compressionAttempts
        )
    }
    
    /// Check if image should be resized based on dimensions
    /// - Parameter image: The image to check
    /// - Returns: True if image exceeds maximum dimensions
    private static func shouldResize(_ image: UIImage) -> Bool {
        return image.size.width > maxDimension || image.size.height > maxDimension
    }
    
    /// Resize image while maintaining aspect ratio
    /// - Parameters:
    ///   - image: The source image
    ///   - maxDimension: Maximum width or height
    /// - Returns: Resized image
    static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            // Landscape
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait or square
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Use high-quality rendering
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    /// Create thumbnail from image
    /// - Parameters:
    ///   - image: Source image
    ///   - size: Thumbnail size (square)
    /// - Returns: Thumbnail image
    static func createThumbnail(from image: UIImage, size: CGFloat = 200) -> UIImage {
        let targetSize = CGSize(width: size, height: size)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { context in
            let aspectWidth = targetSize.width / image.size.width
            let aspectHeight = targetSize.height / image.size.height
            let aspectRatio = max(aspectWidth, aspectHeight)
            
            let scaledImageSize = CGSize(
                width: image.size.width * aspectRatio,
                height: image.size.height * aspectRatio
            )
            
            let x = (targetSize.width - scaledImageSize.width) / 2.0
            let y = (targetSize.height - scaledImageSize.height) / 2.0
            
            let imageRect = CGRect(
                origin: CGPoint(x: x, y: y),
                size: scaledImageSize
            )
            
            image.draw(in: imageRect)
        }
    }
    
    /// Format file size for display
    /// - Parameter bytes: File size in bytes
    /// - Returns: Formatted string (e.g., "2.5 MB")
    static func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

/// Result of image optimization containing data and metadata
struct OptimizedImageResult {
    /// The optimized image data
    let data: Data
    
    /// Final file size in bytes
    let finalSize: Int
    
    /// Original file size in bytes
    let originalSize: Int
    
    /// Compression ratio (0.0 - 1.0)
    let compressionRatio: Double
    
    /// Final compression quality used
    let finalQuality: CGFloat
    
    /// Final image dimensions
    let dimensions: CGSize
    
    /// Number of compression attempts
    let compressionAttempts: Int
    
    /// Formatted final size string
    var finalSizeFormatted: String {
        ImageOptimizer.formatFileSize(finalSize)
    }
    
    /// Formatted original size string
    var originalSizeFormatted: String {
        ImageOptimizer.formatFileSize(originalSize)
    }
    
    /// Size reduction percentage
    var sizeReduction: Double {
        (1.0 - compressionRatio) * 100.0
    }
    
    /// Human-readable summary
    var summary: String {
        """
        Original: \(originalSizeFormatted)
        Optimized: \(finalSizeFormatted)
        Reduced by: \(String(format: "%.1f%%", sizeReduction))
        Quality: \(String(format: "%.0f%%", finalQuality * 100))
        Size: \(Int(dimensions.width))×\(Int(dimensions.height))
        """
    }
}

/// Image optimization errors
enum ImageOptimizationError: LocalizedError {
    case compressionFailed
    case exceedsMaxSize(currentSize: Int, maxSize: Int)
    case invalidImage
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "Failed to compress image"
        case .exceedsMaxSize(let currentSize, let maxSize):
            return "Image size (\(ImageOptimizer.formatFileSize(currentSize))) exceeds maximum allowed (\(ImageOptimizer.formatFileSize(maxSize)))"
        case .invalidImage:
            return "Invalid image format"
        }
    }
}

