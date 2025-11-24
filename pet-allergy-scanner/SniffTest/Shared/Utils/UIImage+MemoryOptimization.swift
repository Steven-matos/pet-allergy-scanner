//
//  UIImage+MemoryOptimization.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import UIKit

/**
 * UIImage memory optimization extensions
 * 
 * Provides memory-efficient image processing methods to prevent memory issues
 * Implements SOLID principles with single responsibility for image optimization
 * Follows DRY by centralizing image processing logic
 * Follows KISS by providing simple, focused methods
 */
extension UIImage {
    
    /**
     * Create a memory-efficient thumbnail from the image
     * 
     * - Parameter size: Target thumbnail size (square)
     * - Returns: Optimized thumbnail image
     */
    func createThumbnail(size: CGFloat) -> UIImage {
        let targetSize = CGSize(width: size, height: size)
        
        // Use UIGraphicsImageRenderer for memory efficiency
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { context in
            // Calculate aspect ratio to maintain proportions
            let aspectWidth = targetSize.width / self.size.width
            let aspectHeight = targetSize.height / self.size.height
            let aspectRatio = min(aspectWidth, aspectHeight)
            
            let scaledSize = CGSize(
                width: self.size.width * aspectRatio,
                height: self.size.height * aspectRatio
            )
            
            // Center the image in the target size
            let x = (targetSize.width - scaledSize.width) / 2.0
            let y = (targetSize.height - scaledSize.height) / 2.0
            
            let imageRect = CGRect(
                origin: CGPoint(x: x, y: y),
                size: scaledSize
            )
            
            self.draw(in: imageRect)
        }
    }
    
    /**
     * Create a memory-efficient resized image
     * 
     * - Parameter maxDimension: Maximum width or height
     * - Returns: Resized image maintaining aspect ratio
     */
    func resizedImage(maxDimension: CGFloat) -> UIImage {
        let size = self.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            // Landscape
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait or square
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Use UIGraphicsImageRenderer for memory efficiency
        let renderer = UIGraphicsImageRenderer(size: newSize)
        
        return renderer.image { context in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /**
     * Get memory usage estimate for the image
     * 
     * - Returns: Estimated memory usage in bytes
     */
    var memoryUsage: Int {
        let width = Int(self.size.width * self.scale)
        let height = Int(self.size.height * self.scale)
        let bytesPerPixel = 4 // RGBA
        return width * height * bytesPerPixel
    }
    
    /**
     * Check if image exceeds memory threshold
     * 
     * - Parameter threshold: Memory threshold in bytes (default: 10MB)
     * - Returns: True if image exceeds threshold
     */
    func exceedsMemoryThreshold(threshold: Int = 10_485_760) -> Bool {
        return memoryUsage > threshold
    }
    
    /**
     * Create a memory-optimized version of the image
     * 
     * - Parameter maxMemoryUsage: Maximum memory usage in bytes
     * - Returns: Optimized image that fits within memory constraints
     */
    func optimizeForMemory(maxMemoryUsage: Int = 5_242_880) -> UIImage {
        // If already within limits, return self
        if memoryUsage <= maxMemoryUsage {
            return self
        }
        
        // Calculate required scale factor
        let currentMemory = memoryUsage
        let scaleFactor = sqrt(Double(maxMemoryUsage) / Double(currentMemory))
        let maxDimension = min(size.width, size.height) * CGFloat(scaleFactor)
        
        // Ensure minimum size
        let finalMaxDimension = max(maxDimension, 200)
        
        return resizedImage(maxDimension: finalMaxDimension)
    }
}

/**
 * Memory-efficient image cache with size limits
 * 
 * Implements LRU (Least Recently Used) eviction policy
 * Automatically manages memory usage to prevent memory pressure
 */
@MainActor
class MemoryEfficientImageCache {
    static let shared = MemoryEfficientImageCache()
    
    // MARK: - Properties
    
    nonisolated(unsafe) private var cache: [String: UIImage] = [:]
    nonisolated(unsafe) private var accessOrder: [String] = []
    private let maxCacheSize: Int
    private let maxMemoryUsage: Int
    
    // MARK: - Initialization
    
    // MEMORY OPTIMIZATION: Reduced cache limits to prevent memory pressure
    private init(maxCacheSize: Int = 30, maxMemoryUsage: Int = 30_000_000) { // 30MB (reduced from 50MB)
        self.maxCacheSize = maxCacheSize
        self.maxMemoryUsage = maxMemoryUsage
        setupMemoryWarningObserver()
    }
    
    // MARK: - Public Interface
    
    /**
     * Store image in cache with automatic memory management
     * 
     * - Parameters:
     *   - image: Image to cache
     *   - key: Unique cache key
     */
    func setImage(_ image: UIImage, forKey key: String) {
        // Remove existing entry if present
        removeImage(forKey: key)
        
        // Check if we need to evict items
        evictIfNeeded()
        
        // Add new image
        cache[key] = image
        accessOrder.append(key)
        
        // Update access order
        updateAccessOrder(for: key)
    }
    
    /**
     * Retrieve image from cache
     * 
     * - Parameter key: Cache key
     * - Returns: Cached image or nil
     */
    func image(forKey key: String) -> UIImage? {
        guard let image = cache[key] else { return nil }
        
        // Update access order
        updateAccessOrder(for: key)
        
        return image
    }
    
    /**
     * Remove image from cache
     * 
     * - Parameter key: Cache key
     */
    func removeImage(forKey key: String) {
        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }
    
    /**
     * Clear all cached images
     */
    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
    }
    
    /**
     * Get current cache statistics
     * 
     * - Returns: Cache statistics
     */
    func getCacheStats() -> (count: Int, memoryUsage: Int) {
        let totalMemory = cache.values.reduce(0) { $0 + $1.memoryUsage }
        return (count: cache.count, memoryUsage: totalMemory)
    }
    
    // MARK: - Private Methods
    
    private func evictIfNeeded() {
        // Check cache size limit
        while cache.count >= maxCacheSize {
            evictLeastRecentlyUsed()
        }
        
        // Check memory usage limit
        while getCacheStats().memoryUsage > maxMemoryUsage {
            evictLeastRecentlyUsed()
        }
    }
    
    nonisolated private func evictLeastRecentlyUsed() {
        guard !accessOrder.isEmpty else { return }
        
        let keyToRemove = accessOrder.removeFirst()
        cache.removeValue(forKey: keyToRemove)
    }
    
    private func updateAccessOrder(for key: String) {
        // Remove from current position
        accessOrder.removeAll { $0 == key }
        // Add to end (most recently used)
        accessOrder.append(key)
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    nonisolated private func handleMemoryWarning() {
        // MEMORY OPTIMIZATION: Aggressively clear cache on memory warning
        // Clear 75% of cache to free up more memory
        let targetCount = max(1, cache.count / 4) // Keep only 25%
        while cache.count > targetCount {
            evictLeastRecentlyUsed()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
