//
//  CacheFirstDataLoader.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation

/**
 * Cache-First Data Loader
 * 
 * Generic service for cache-first data loading pattern.
 * Returns cached data immediately (synchronous), then fetches from server in background if needed.
 * 
 * Key Features:
 * - Synchronous cache check for immediate UI rendering
 * - Background refresh for stale data
 * - Automatic 404 handling and cache invalidation
 * - Deleted resource detection
 * - Smart refresh strategies
 * 
 * Follows SOLID principles: Single responsibility for cache-first loading
 * Implements DRY by providing reusable loading pattern
 * Follows KISS by keeping the API simple and transparent
 */
@MainActor
class CacheFirstDataLoader {
    static let shared = CacheFirstDataLoader()
    
    private let cacheCoordinator = UnifiedCacheCoordinator.shared
    private let apiService = APIService.shared
    
    private init() {}
    
    /**
     * Load data with cache-first pattern
     * 
     * - Parameters:
     *   - type: Data type to load
     *   - cacheKey: Cache key
     *   - fetchFromServer: Async closure to fetch from server
     *   - forceRefresh: If true, bypasses cache and fetches fresh data
     * - Returns: Cached data immediately, then updates with fresh data if needed
     */
    func load<T: Codable>(
        _ type: T.Type,
        cacheKey: String,
        fetchFromServer: @escaping () async throws -> T,
        forceRefresh: Bool = false
    ) async throws -> T {
        // If force refresh, invalidate cache first
        if forceRefresh {
            cacheCoordinator.invalidate(forKey: cacheKey)
        }
        
        // Try cache first (synchronous for immediate UI)
        if let cached = cacheCoordinator.get(type, forKey: cacheKey) {
            // Return cached data immediately
            // Then refresh in background if stale
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                do {
                    let fresh = try await fetchFromServer()
                    self.cacheCoordinator.set(fresh, forKey: cacheKey)
                } catch {
                    // If 404, invalidate cache
                    if let apiError = error as? APIError,
                       case .serverError(let statusCode) = apiError,
                       statusCode == 404 {
                        self.cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                    }
                }
            }
            return cached
        }
        
        // Cache miss - fetch from server
        do {
            let data = try await fetchFromServer()
            cacheCoordinator.set(data, forKey: cacheKey)
            return data
        } catch {
            // Handle 404 - resource deleted
            if let apiError = error as? APIError,
               case .serverError(let statusCode) = apiError,
               statusCode == 404 {
                cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                throw CacheError.resourceDeleted
            }
            throw error
        }
    }
    
    /**
     * Load array of data with cache-first pattern
     * Handles partial cache hits and server deletions
     * 
     * - Parameters:
     *   - type: Array element type
     *   - cacheKey: Cache key
     *   - fetchFromServer: Async closure to fetch from server
     *   - forceRefresh: If true, bypasses cache
     * - Returns: Cached data immediately, then updates with fresh data
     */
    func loadArray<T: Codable>(
        _ type: T.Type,
        cacheKey: String,
        fetchFromServer: @escaping () async throws -> [T],
        forceRefresh: Bool = false
    ) async throws -> [T] {
        // If force refresh, invalidate cache first
        if forceRefresh {
            cacheCoordinator.invalidate(forKey: cacheKey)
        }
        
        // Try cache first
        if let cached = cacheCoordinator.get([T].self, forKey: cacheKey) {
            // Return cached data immediately
            // Then refresh in background
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                do {
                    let fresh = try await fetchFromServer()
                    self.cacheCoordinator.set(fresh, forKey: cacheKey)
                } catch {
                    // If 404, invalidate cache
                    if let apiError = error as? APIError,
                       case .serverError(let statusCode) = apiError,
                       statusCode == 404 {
                        self.cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                    }
                }
            }
            return cached
        }
        
        // Cache miss - fetch from server
        do {
            let data = try await fetchFromServer()
            cacheCoordinator.set(data, forKey: cacheKey)
            return data
        } catch {
            // Handle 404
            if let apiError = error as? APIError,
               case .serverError(let statusCode) = apiError,
               statusCode == 404 {
                cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                // Return empty array for deleted resources
                return []
            }
            throw error
        }
    }
    
    /**
     * Load data with explicit cache validation
     * Validates cache entry against server before returning
     * 
     * - Parameters:
     *   - type: Data type
     *   - cacheKey: Cache key
     *   - validateCache: Closure to validate cache entry
     *   - fetchFromServer: Async closure to fetch from server
     * - Returns: Validated cached data or fresh data from server
     */
    func loadWithValidation<T: Codable>(
        _ type: T.Type,
        cacheKey: String,
        validateCache: @escaping (T) -> Bool,
        fetchFromServer: @escaping () async throws -> T
    ) async throws -> T {
        // Check cache
        if let cached = cacheCoordinator.get(type, forKey: cacheKey) {
            // Validate cache entry
            if validateCache(cached) {
                // Cache is valid, return it
                // Refresh in background
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    do {
                        let fresh = try await fetchFromServer()
                        self.cacheCoordinator.set(fresh, forKey: cacheKey)
                    } catch {
                        // Handle 404
                        if let apiError = error as? APIError,
                           case .serverError(let statusCode) = apiError,
                           statusCode == 404 {
                            self.cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                        }
                    }
                }
                return cached
            } else {
                // Cache invalid, invalidate and fetch fresh
                cacheCoordinator.invalidate(forKey: cacheKey)
            }
        }
        
        // Fetch from server
        do {
            let data = try await fetchFromServer()
            cacheCoordinator.set(data, forKey: cacheKey)
            return data
        } catch {
            // Handle 404
            if let apiError = error as? APIError,
               case .serverError(let statusCode) = apiError,
               statusCode == 404 {
                cacheCoordinator.handleResourceDeleted(forKey: cacheKey)
                throw CacheError.resourceDeleted
            }
            throw error
        }
    }
}

// MARK: - Cache Errors

/**
 * Cache-specific errors
 */
enum CacheError: LocalizedError {
    case resourceDeleted
    case cacheCorrupted
    case cacheExpired
    
    var errorDescription: String? {
        switch self {
        case .resourceDeleted:
            return "Resource has been deleted from server"
        case .cacheCorrupted:
            return "Cache data is corrupted"
        case .cacheExpired:
            return "Cache data has expired"
        }
    }
}
