//
//  PerformanceOptimizer.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import Foundation
import UIKit
import SwiftUI

/// Performance optimization utilities for the app
struct PerformanceOptimizer {
    
    /// Optimize image for OCR processing
    /// - Parameter image: Original UIImage
    /// - Returns: Optimized UIImage for better OCR accuracy
    static func optimizeImageForOCR(_ image: UIImage) -> UIImage? {
        // Target size for optimal OCR performance (balance between accuracy and speed)
        let targetSize = CGSize(width: 1024, height: 1024)
        
        // Calculate scale factor to maintain aspect ratio
        let widthScale = targetSize.width / image.size.width
        let heightScale = targetSize.height / image.size.height
        let scale = min(widthScale, heightScale)
        
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        // Use high-quality rendering for better OCR results
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let optimizedImage = renderer.image { context in
            // Set interpolation quality for better text recognition
            context.cgContext.interpolationQuality = .high
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return optimizedImage
    }
    
    /// Preprocess image for better OCR accuracy
    /// - Parameter image: Input UIImage
    /// - Returns: Preprocessed UIImage
    static func preprocessImageForOCR(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Create a grayscale version for better text contrast
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )
        
        guard let grayscaleContext = context else { return image }
        
        grayscaleContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        guard let grayscaleCGImage = grayscaleContext.makeImage() else { return image }
        
        return UIImage(cgImage: grayscaleCGImage)
    }
    
    /// Debounce function for reducing API calls
    /// - Parameters:
    ///   - delay: Delay in seconds
    ///   - action: Action to execute
    /// - Returns: Debounced function
    static func debounce(delay: TimeInterval, action: @escaping () -> Void) -> () -> Void {
        // Use a class to maintain state across calls
        class DebounceState {
            var workItem: DispatchWorkItem?
        }
        
        let state = DebounceState()
        
        return {
            state.workItem?.cancel()
            state.workItem = DispatchWorkItem(block: action)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: state.workItem!)
        }
    }
    
    /// Memory-efficient image loading
    /// - Parameter url: Image URL
    /// - Returns: AsyncImage view
    @ViewBuilder
    static func efficientAsyncImage(url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 50, height: 50)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure(_):
                Image(systemName: "photo")
                    .foregroundColor(.gray)
            @unknown default:
                EmptyView()
            }
        }
    }
    
    /// Lazy loading container for large lists
    /// - Parameters:
    ///   - items: Array of items
    ///   - content: Content builder
    /// - Returns: LazyVStack with optimized performance
    @ViewBuilder
    static func lazyContainer<T: Identifiable, Content: View>(
        items: [T],
        @ViewBuilder content: @escaping (T) -> Content
    ) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(items) { item in
                content(item)
                    .id(item.id)
            }
        }
    }
}

/// View modifier for performance monitoring
struct PerformanceMonitor: ViewModifier {
    let identifier: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                #if DEBUG
                print("⚡ View appeared: \(identifier)")
                #endif
            }
            .onDisappear {
                #if DEBUG
                print("⚡ View disappeared: \(identifier)")
                #endif
            }
    }
}

extension View {
    /// Add performance monitoring to any view
    /// - Parameter identifier: Unique identifier for the view
    /// - Returns: Modified view with performance monitoring
    func performanceMonitor(_ identifier: String) -> some View {
        self.modifier(PerformanceMonitor(identifier: identifier))
    }
}
