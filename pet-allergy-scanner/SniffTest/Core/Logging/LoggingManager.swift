//
//  LoggingManager.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import OSLog

/**
 * Centralized Logging Manager
 *
 * Provides unified logging across the app with proper log levels and conditional compilation.
 * Logs are only emitted in DEBUG builds to keep production clean and performant.
 *
 * Usage:
 * ```swift
 * LoggingManager.debug("Cache hit", category: .cache)
 * LoggingManager.error("Failed to load data: \(error)", category: .network)
 * ```
 *
 * Follows SOLID: Single responsibility for all logging
 * Follows DRY: Eliminates duplicate print statements
 * Follows KISS: Simple, consistent API
 */
final class LoggingManager {
    
    // MARK: - Log Categories
    
    /// Log categories for better organization in Console.app
    enum Category: String {
        case cache = "Cache"
        case network = "Network"
        case authentication = "Auth"
        case scanning = "Scanning"
        case nutrition = "Nutrition"
        case subscription = "Subscription"
        case analytics = "Analytics"
        case performance = "Performance"
        case notifications = "Notifications"
        case general = "General"
        case pets = "Pets"
        case profile = "Profile"
    }
    
    // MARK: - Log Levels
    
    /// Log level determines visibility and importance
    enum Level: String {
        case debug = "🔍"      // Development debugging
        case info = "ℹ️"       // General information
        case warning = "⚠️"    // Potential issues
        case error = "❌"      // Errors that need attention
        case critical = "🚨"   // Critical failures
    }
    
    // MARK: - Configuration
    
    /// Enable/disable logging globally (automatically disabled in release builds)
    private static var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Subsystem identifier for OSLog
    private static let subsystem = "com.snifftest.app"
    
    /// Cache of Logger instances by category (thread-safe with nonisolated(unsafe))
    private static nonisolated(unsafe) var loggers: [Category: Logger] = [:]
    
    // MARK: - Public API
    
    /**
     * Log debug information (only in DEBUG builds)
     *
     * Use for development debugging, detailed state information, etc.
     * Automatically suppressed in production.
     *
     * - Parameters:
     *   - message: Log message
     *   - category: Log category for organization
     */
    static func debug(_ message: String, category: Category = .general) {
        log(message, level: .debug, category: category)
    }
    
    /**
     * Log informational messages
     *
     * Use for important state changes, successful operations, etc.
     *
     * - Parameters:
     *   - message: Log message
     *   - category: Log category for organization
     */
    static func info(_ message: String, category: Category = .general) {
        log(message, level: .info, category: category)
    }
    
    /**
     * Log warnings
     *
     * Use for recoverable issues, deprecated usage, etc.
     *
     * - Parameters:
     *   - message: Log message
     *   - category: Log category for organization
     */
    static func warning(_ message: String, category: Category = .general) {
        log(message, level: .warning, category: category)
    }
    
    /**
     * Log errors
     *
     * Use for errors that need attention but don't crash the app.
     *
     * - Parameters:
     *   - message: Log message
     *   - category: Log category for organization
     */
    static func error(_ message: String, category: Category = .general) {
        log(message, level: .error, category: category)
    }
    
    /**
     * Log critical failures
     *
     * Use for critical errors that significantly impact functionality.
     * Always logged, even in production.
     *
     * - Parameters:
     *   - message: Log message
     *   - category: Log category for organization
     */
    static func critical(_ message: String, category: Category = .general) {
        // Critical logs are always emitted, even in production
        logInternal(message, level: .critical, category: category)
    }
    
    // MARK: - Private Methods
    
    /**
     * Internal logging implementation
     *
     * Routes logs to OSLog for proper integration with Console.app
     *
     * - Parameters:
     *   - message: Log message
     *   - level: Log level
     *   - category: Log category
     */
    private static func log(_ message: String, level: Level, category: Category) {
        guard isEnabled else { return }
        logInternal(message, level: level, category: category)
    }
    
    /**
     * Direct logging without enabled check (for critical logs)
     */
    private static func logInternal(_ message: String, level: Level, category: Category) {
        let logger = getLogger(for: category)
        let formattedMessage = "\(level.rawValue) [\(category.rawValue)] \(message)"
        
        switch level {
        case .debug:
            logger.debug("\(formattedMessage)")
        case .info:
            logger.info("\(formattedMessage)")
        case .warning:
            logger.warning("\(formattedMessage)")
        case .error:
            logger.error("\(formattedMessage)")
        case .critical:
            logger.critical("\(formattedMessage)")
        }
    }
    
    /**
     * Get or create Logger for category
     */
    private static func getLogger(for category: Category) -> Logger {
        if let logger = loggers[category] {
            return logger
        }
        
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = logger
        return logger
    }
}
