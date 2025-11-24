//
//  MemoryMonitor.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import UIKit
import os.log

/**
 * Memory monitoring service for tracking and managing app memory usage
 * 
 * Implements SOLID principles with single responsibility for memory management
 * Follows DRY by centralizing memory monitoring logic
 * Follows KISS by providing simple, focused memory management
 */
@MainActor
class MemoryMonitor: ObservableObject {
    static let shared = MemoryMonitor()
    
    // MARK: - Properties
    
    @Published var currentMemoryUsage: Int = 0
    @Published var peakMemoryUsage: Int = 0
    @Published var memoryWarningCount: Int = 0
    @Published var isMemoryPressureHigh: Bool = false
    
    private let logger = Logger(subsystem: "com.snifftest.app", category: "MemoryMonitor")
    nonisolated(unsafe) private var memoryWarningObserver: NSObjectProtocol?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // Memory thresholds
    private let warningThreshold: Int = 100_000_000 // 100MB
    private let criticalThreshold: Int = 150_000_000 // 150MB
    private let maxMemoryUsage: Int = 200_000_000 // 200MB
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryMonitoring()
        startMemoryTracking()
    }
    
    deinit {
        stopMemoryTracking()
    }
    
    // MARK: - Public Interface
    
    /**
     * Get current memory usage in bytes
     * 
     * - Returns: Current memory usage
     */
    func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        }
        
        return 0
    }
    
    /**
     * Check if memory usage is within acceptable limits
     * 
     * - Returns: True if memory usage is acceptable
     */
    func isMemoryUsageAcceptable() -> Bool {
        let currentUsage = getCurrentMemoryUsage()
        return currentUsage < warningThreshold
    }
    
    /**
     * Force memory cleanup when under pressure
     */
    func performMemoryCleanup() {
        
        // Clear image cache
        MemoryEfficientImageCache.shared.clearCache()
        
        // Clear other caches - using MemoryEfficientImageCache for now
        // TODO: Add other cache services as they become available
        
        // Force garbage collection
        autoreleasepool {
            // This will help release autoreleased objects
        }
        
        // Update memory stats
        updateMemoryStats()
        
    }
    
    /**
     * Get memory usage statistics
     * 
     * - Returns: Memory usage statistics
     */
    func getMemoryStats() -> MemoryStats {
        let current = getCurrentMemoryUsage()
        let peak = max(current, peakMemoryUsage)
        
        return MemoryStats(
            currentUsage: current,
            peakUsage: peak,
            warningCount: memoryWarningCount,
            isHighPressure: isMemoryPressureHigh
        )
    }
    
    // MARK: - Private Methods
    
    private func setupMemoryMonitoring() {
        // Monitor memory warnings
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
    }
    
    private func startMemoryTracking() {
        // Start periodic memory monitoring
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryStats()
            }
        }
    }
    
    nonisolated private func stopMemoryTracking() {
        memoryWarningObserver = nil
    }
    
    private func updateMemoryStats() {
        let currentUsage = getCurrentMemoryUsage()
        currentMemoryUsage = currentUsage
        
        if currentUsage > peakMemoryUsage {
            peakMemoryUsage = currentUsage
        }
        
        // Check memory pressure
        isMemoryPressureHigh = currentUsage > warningThreshold
        
        // Log memory usage if high
        if currentUsage > warningThreshold {
            logger.warning("High memory usage: \(currentUsage / 1024 / 1024)MB")
        }
        
        // Perform cleanup if memory usage is critical
        if currentUsage > criticalThreshold {
            logger.error("Critical memory usage: \(currentUsage / 1024 / 1024)MB - performing cleanup")
            performMemoryCleanup()
        }
    }
    
    private func handleMemoryWarning() {
        memoryWarningCount += 1
        logger.warning("Memory warning received (count: \(self.memoryWarningCount))")
        
        // Perform aggressive cleanup
        performMemoryCleanup()
        
        // Start background task to complete cleanup
        startBackgroundCleanupTask()
    }
    
    private func startBackgroundCleanupTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "MemoryCleanup") {
            // End background task
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = .invalid
        }
        
        // Perform cleanup in background
        Task.detached {
            await MainActor.run {
                self.performMemoryCleanup()
                UIApplication.shared.endBackgroundTask(self.backgroundTask)
                self.backgroundTask = .invalid
            }
        }
    }
}

/**
 * Memory usage statistics
 */
struct MemoryStats {
    let currentUsage: Int
    let peakUsage: Int
    let warningCount: Int
    let isHighPressure: Bool
    
    var currentUsageMB: Int {
        currentUsage / 1024 / 1024
    }
    
    var peakUsageMB: Int {
        peakUsage / 1024 / 1024
    }
    
    var formattedCurrentUsage: String {
        ByteCountFormatter.string(fromByteCount: Int64(currentUsage), countStyle: .memory)
    }
    
    var formattedPeakUsage: String {
        ByteCountFormatter.string(fromByteCount: Int64(peakUsage), countStyle: .memory)
    }
}

/**
 * Memory pressure levels
 */
enum MemoryPressureLevel {
    case low
    case medium
    case high
    case critical
    
    init(memoryUsage: Int) {
        switch memoryUsage {
        case 0..<50_000_000: // < 50MB
            self = .low
        case 50_000_000..<100_000_000: // 50-100MB
            self = .medium
        case 100_000_000..<150_000_000: // 100-150MB
            self = .high
        default: // > 150MB
            self = .critical
        }
    }
    
    var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }
    
    var color: UIColor {
        switch self {
        case .low:
            return .systemGreen
        case .medium:
            return .systemYellow
        case .high:
            return .systemOrange
        case .critical:
            return .systemRed
        }
    }
}
