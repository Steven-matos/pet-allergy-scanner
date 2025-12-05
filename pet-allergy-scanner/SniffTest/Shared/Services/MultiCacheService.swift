//
//  MultiCacheService.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import Combine

/**
 * Multi-Cache Service Helper
 * 
 * @deprecated Use UnifiedCacheCoordinator.shared instead. This service is being phased out.
 * 
 * Provides a convenient way to manage multiple ObservableCacheManager instances
 * in a single service, ensuring all cache updates trigger SwiftUI observation.
 * 
 * Usage:
 * ```swift
 * class MyService: ObservableObject {
 *     private let caches = MultiCacheService()
 *     
 *     var items: [Item] {
 *         caches.get("items") ?? []
 *     }
 *     
 *     func setItems(_ items: [Item]) {
 *         caches.set(items, forKey: "items")
 *     }
 * }
 * ```
 */
@available(*, deprecated, message: "Use UnifiedCacheCoordinator.shared instead")
@MainActor
class MultiCacheService: ObservableObject {
    
    /**
     * Internal storage for multiple cache managers
     * Key: Cache name, Value: Any ObservableCacheManager
     */
    private var caches: [String: Any] = [:]
    
    /**
     * Published property to trigger SwiftUI updates
     */
    @Published private var updateTrigger = UUID()
    
    /**
     * Get or create a cache manager for a specific type
     * 
     * - Parameters:
     *   - name: Unique name for this cache
     *   - defaultTTL: Default TTL for entries
     *   - maxCacheSize: Maximum cache size
     * - Returns: ObservableCacheManager instance
     */
    func cache<Key: Hashable, Value>(
        named name: String,
        defaultTTL: TimeInterval? = nil,
        maxCacheSize: Int? = nil
    ) -> ObservableCacheManager<Key, Value> {
        
        if let existingCache = caches[name] as? ObservableCacheManager<Key, Value> {
            return existingCache
        }
        
        let newCache = ObservableCacheManager<Key, Value>(
            defaultTTL: defaultTTL,
            maxCacheSize: maxCacheSize
        )
        
        // Observe cache changes to trigger service updates
        newCache.objectWillChange
            .sink { [weak self] _ in
                self?.updateTrigger = UUID()
            }
            .store(in: &cancellables)
        
        caches[name] = newCache
        return newCache
    }
    
    /**
     * Clear all caches
     */
    func clearAll() {
        for (_, cache) in caches {
            if let observableCache = cache as? any ObservableObject {
                // Try to call clear if it exists
                if let clearMethod = observableCache as? (any Clearable) {
                    clearMethod.clear()
                }
            }
        }
        caches.removeAll()
        updateTrigger = UUID()
    }
    
    private var cancellables = Set<AnyCancellable>()
}

/**
 * Protocol for cache types that can be cleared
 */
@MainActor
private protocol Clearable {
    func clear()
}

/// @deprecated ObservableCacheManager is deprecated. Use UnifiedCacheCoordinator.shared instead.
@available(*, deprecated, message: "ObservableCacheManager is deprecated. Use UnifiedCacheCoordinator.shared instead.")
@MainActor
extension ObservableCacheManager: Clearable {}

