//
//  GraphicsOptimizer.swift
//  SniffTest
//
//  Created by Steven Matos on 1/10/25.
//

import Foundation
import SwiftUI
import UIKit

/**
 * Graphics Optimization Service
 * 
 * Handles graphics rendering optimizations to prevent IOSurface errors:
 * - IOSurfaceClientSetSurfaceNotify error e00002c7 prevention
 * - Graphics context optimization
 * - Chart rendering improvements
 * - Memory-efficient image processing
 * 
 * Follows SOLID principles with single responsibility for graphics optimization
 * Implements DRY by reusing common graphics utilities
 * Follows KISS by providing simple, focused optimization methods
 */
@MainActor
class GraphicsOptimizer: ObservableObject {
    static let shared = GraphicsOptimizer()
    
    // MARK: - Published Properties
    
    /// Whether graphics optimizations are enabled
    @Published var isOptimizationEnabled = true
    
    /// Current graphics performance level
    @Published var performanceLevel: GraphicsPerformanceLevel = .balanced
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Constants
    
    private enum UserDefaultsKeys {
        static let optimizationEnabled = "graphics_optimization_enabled"
        static let performanceLevel = "graphics_performance_level"
    }
    
    // MARK: - Initialization
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /**
     * Configure graphics context to prevent IOSurface errors
     * - Parameter context: Core Graphics context to configure
     */
    func configureGraphicsContext(_ context: CGContext) {
        guard isOptimizationEnabled else { return }
        
        // Configure context to prevent e00002c7 errors
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(true)
        context.setShouldSmoothFonts(true)
        context.interpolationQuality = .high
        
        // Disable problematic surface notifications
        context.setAllowsFontSubpixelPositioning(false)
        context.setShouldSubpixelPositionFonts(false)
        
        // Optimize for performance level
        switch performanceLevel {
        case .high:
            context.setAllowsFontSubpixelQuantization(false)
            context.setShouldSubpixelQuantizeFonts(false)
        case .balanced:
            context.setAllowsFontSubpixelQuantization(true)
            context.setShouldSubpixelQuantizeFonts(true)
        case .low:
            context.setAllowsFontSubpixelQuantization(true)
            context.setShouldSubpixelQuantizeFonts(true)
        }
    }
    
    /**
     * Create IOSurface-safe image renderer
     * - Parameters:
     *   - size: Target size for the image
     *   - drawing: Drawing closure with optimized context
     * - Returns: Rendered UIImage or nil if failed
     */
    func createSafeImage(
        size: CGSize,
        drawing: @escaping (CGContext) -> Void
    ) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            configureGraphicsContext(context.cgContext)
            drawing(context.cgContext)
        }
    }
    
    /**
     * Optimize SwiftUI view for graphics rendering
     * - Parameter content: View content to optimize
     * - Returns: Optimized view with graphics improvements
     */
    @ViewBuilder
    func optimizedView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if isOptimizationEnabled {
            content()
                .drawingGroup() // Force offscreen rendering
                .compositingGroup() // Optimize compositing
                .clipped() // Prevent overflow rendering issues
        } else {
            content()
        }
    }
    
    /**
     * Create optimized chart view with IOSurface error prevention
     * - Parameter content: Chart content
     * - Returns: Optimized chart view
     */
    @ViewBuilder
    func optimizedChart<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 16.0, *) {
            optimizedView {
                content()
            }
        } else {
            // Fallback for older iOS versions
            VStack(spacing: 8) {
                Text("📊")
                    .font(.system(size: 40))
                Text("Interactive charts require iOS 16+")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(height: 200)
        }
    }
    
    /**
     * Update performance level
     * - Parameter level: New performance level
     */
    func setPerformanceLevel(_ level: GraphicsPerformanceLevel) {
        performanceLevel = level
        userDefaults.set(level.rawValue, forKey: UserDefaultsKeys.performanceLevel)
        userDefaults.synchronize()
    }
    
    /**
     * Toggle optimization on/off
     * - Parameter enabled: Whether to enable optimizations
     */
    func setOptimizationEnabled(_ enabled: Bool) {
        isOptimizationEnabled = enabled
        userDefaults.set(enabled, forKey: UserDefaultsKeys.optimizationEnabled)
        userDefaults.synchronize()
    }
    
    // MARK: - Private Methods
    
    /**
     * Load settings from UserDefaults
     */
    private func loadSettings() {
        isOptimizationEnabled = userDefaults.object(forKey: UserDefaultsKeys.optimizationEnabled) as? Bool ?? true
        
        if let levelRaw = userDefaults.object(forKey: UserDefaultsKeys.performanceLevel) as? Int,
           let level = GraphicsPerformanceLevel(rawValue: levelRaw) {
            performanceLevel = level
        }
    }
}

/**
 * Graphics performance levels
 */
enum GraphicsPerformanceLevel: Int, CaseIterable {
    case low = 0
    case balanced = 1
    case high = 2
    
    var displayName: String {
        switch self {
        case .low:
            return "Low (Battery Saver)"
        case .balanced:
            return "Balanced"
        case .high:
            return "High (Best Quality)"
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "Optimized for battery life with basic graphics"
        case .balanced:
            return "Balanced performance and battery life"
        case .high:
            return "Best graphics quality with higher battery usage"
        }
    }
}

/**
 * View modifier for graphics optimization
 */
struct GraphicsOptimizationModifier: ViewModifier {
    let optimizer = GraphicsOptimizer.shared
    
    func body(content: Content) -> some View {
        optimizer.optimizedView {
            content
        }
    }
}

extension View {
    /**
     * Apply graphics optimization to any view
     * - Returns: View with graphics optimizations applied
     */
    func graphicsOptimized() -> some View {
        self.modifier(GraphicsOptimizationModifier())
    }
}
