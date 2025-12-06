//
//  DevicePerformanceHelper.swift
//  SniffTest
//
//  Device performance detection and optimization helpers
//

import UIKit
import Foundation

/**
 * Device Performance Helper
 * 
 * Detects device capabilities and provides performance optimizations
 * for older devices that may struggle with complex rendering.
 */
@MainActor
enum DevicePerformanceHelper {
    
    /**
     * Check if device is an older model that may need performance optimizations
     * iPhone 14 Pro Max and older devices may struggle with complex charts
     */
    static var isOlderDevice: Bool {
        // Check device model identifier
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0)
            }
        } ?? ""
        
        // iPhone 14 Pro Max and older (iPhone14,3 = iPhone 14 Pro Max)
        // iPhone 15 and newer have better performance
        let olderDeviceIdentifiers = [
            "iPhone14,3", // iPhone 14 Pro Max
            "iPhone14,2", // iPhone 14 Pro
            "iPhone14,1", // iPhone 14 Plus
            "iPhone14,0", // iPhone 14
            "iPhone13,4", // iPhone 13 Pro Max
            "iPhone13,3", // iPhone 13 Pro
            "iPhone13,2", // iPhone 13
            "iPhone13,1", // iPhone 13 mini
            "iPhone12,8", // iPhone SE (2nd gen)
            "iPhone12,5", // iPhone 11 Pro Max
            "iPhone12,3", // iPhone 11 Pro
            "iPhone12,1", // iPhone 11
        ]
        
        return olderDeviceIdentifiers.contains { modelCode.contains($0) }
    }
    
    /**
     * Get maximum data points for charts on this device
     * Older devices get fewer points to prevent freezing
     */
    static var maxChartDataPoints: Int {
        if isOlderDevice {
            return 15 // Reduced from 30 for older devices
        }
        return 30
    }
    
    /**
     * Check if chart background images should be disabled
     * Background images add rendering complexity
     */
    static var shouldDisableChartBackgrounds: Bool {
        return isOlderDevice
    }
    
    /**
     * Check if chart should use simplified rendering
     * Older devices get simpler charts (no AreaMark, fewer PointMarks)
     */
    static var shouldUseSimplifiedCharts: Bool {
        return isOlderDevice
    }
    
    /**
     * Check if chart rendering should be deferred
     * Defer complex rendering until after initial view load
     */
    static var shouldDeferChartRendering: Bool {
        return isOlderDevice
    }
    
    /**
     * Get memory pressure threshold for this device
     * Older devices have less memory
     */
    static var memoryPressureThresholdMB: Int {
        if isOlderDevice {
            return 100 // Lower threshold for older devices
        }
        return 150
    }
}
