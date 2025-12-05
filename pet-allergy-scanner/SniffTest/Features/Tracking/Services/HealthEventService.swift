//
//  HealthEventService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import Combine

/**
 * Health Event Service
 * 
 * Manages health event data and API communication with reliable SwiftUI observation.
 * Uses ObservableCacheManager for proper cache updates that trigger SwiftUI view refreshes.
 * 
 * Follows SOLID principles with single responsibility for health event operations
 * Implements DRY by reusing common API patterns
 * Follows KISS by keeping the service simple and focused
 */
@MainActor
class HealthEventService: ObservableObject {
    static let shared = HealthEventService()
    
    // MARK: - Published Properties
    
    // In-memory cache for SwiftUI observation (synced with UnifiedCacheCoordinator)
    @Published private var healthEventsCache: [String: [HealthEvent]] = [:]
    
    @Published var isLoading = false
    @Published var error: Error?
    
    // MARK: - Services
    
    private let apiService = APIService.shared
    private let cacheCoordinator = UnifiedCacheCoordinator.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadCachedDataOnInit()
    }
    
    /**
     * Load cached data synchronously on init for immediate UI rendering
     */
    private func loadCachedDataOnInit() {
        // Load cached health events from UnifiedCacheCoordinator synchronously
        let pets = CachedPetService.shared.pets
        for pet in pets {
            let cacheKey = CacheKey.healthEvents.scoped(forPetId: pet.id)
            if let cached = cacheCoordinator.get([HealthEvent].self, forKey: cacheKey) {
                healthEventsCache[pet.id] = cached
            }
        }
    }
    
    // MARK: - Computed Properties for Views
    
    /**
     * Get health events for a pet (for SwiftUI views)
     * Returns from in-memory cache (synced with UnifiedCacheCoordinator)
     */
    func healthEvents(for petId: String) -> [HealthEvent] {
        // First check in-memory cache
        if let cached = healthEventsCache[petId] {
            return cached
        }
        
        // Try UnifiedCacheCoordinator (synchronous)
        let cacheKey = CacheKey.healthEvents.scoped(forPetId: petId)
        if let cached = cacheCoordinator.get([HealthEvent].self, forKey: cacheKey) {
            healthEventsCache[petId] = cached
            return cached
        }
        
        return []
    }
    
    /**
     * Check if we have cached events for a pet
     */
    func hasCachedEvents(for petId: String) -> Bool {
        // Check in-memory cache first
        if healthEventsCache[petId] != nil {
            return true
        }
        
        // Check UnifiedCacheCoordinator
        let cacheKey = CacheKey.healthEvents.scoped(forPetId: petId)
        return cacheCoordinator.exists(forKey: cacheKey)
    }
    
    /**
     * Create a new health event for a pet
     * 
     * - Parameters:
     *   - petId: ID of the pet
     *   - eventType: Type of health event
     *   - title: Title for the event
     *   - notes: Optional notes
     *   - severityLevel: Severity level (1-5)
     *   - eventDate: Date when the event occurred
     * - Returns: Created health event
     * - Throws: APIError if creation fails
     */
    func createHealthEvent(
        for petId: String,
        eventType: HealthEventType,
        title: String,
        notes: String? = nil,
        severityLevel: Int = 1,
        eventDate: Date = Date(),
        documents: [String]? = nil
    ) async throws -> HealthEvent {
        
        isLoading = true
        error = nil
        
        // Debug authentication state before making request
        await apiService.debugAuthState()
        
        // Test authentication before making the request
        do {
            try await apiService.testAuthentication()
        } catch {
            print("❌ DEBUG: Authentication test failed: \(error)")
            throw error
        }
        
        do {
            let healthEventCreate = HealthEventCreate(
                petId: petId,
                eventType: eventType,
                title: title,
                notes: notes,
                severityLevel: severityLevel,
                eventDate: eventDate,
                documents: documents
            )
            
            let createdEvent = try await apiService.post(
                endpoint: "/health-events",
                body: healthEventCreate,
                responseType: HealthEvent.self
            )
            
            // Update cache with new event using UnifiedCacheCoordinator
            var currentEvents = healthEvents(for: petId)
            currentEvents.append(createdEvent)
            currentEvents.sort { $0.eventDate > $1.eventDate }
            
            let cacheKey = CacheKey.healthEvents.scoped(forPetId: petId)
            cacheCoordinator.set(currentEvents, forKey: cacheKey)
            healthEventsCache[petId] = currentEvents
            objectWillChange.send()
            
            print("✅ [createHealthEvent] Added event to cache for pet: \(petId)")
            print("   Event count: \(currentEvents.count)")
            
            isLoading = false
            return createdEvent
            
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    /**
     * Get health events for a pet
     * 
     * - Parameters:
     *   - petId: ID of the pet
     *   - limit: Maximum number of events to return
     *   - category: Optional category filter
     *   - forceRefresh: Force refresh from server (default: false)
     * - Returns: Array of health events
     * - Throws: APIError if fetch fails
     */
    func getHealthEvents(
        for petId: String,
        limit: Int = 50,
        category: HealthEventCategory? = nil,
        forceRefresh: Bool = false
    ) async throws -> [HealthEvent] {
        
        // Return cached data if available and not forcing refresh (synchronous for immediate UI)
        // Only use cache if it has actual data (not empty array)
        if !forceRefresh {
            let cacheKey = CacheKey.healthEvents.scoped(forPetId: petId)
            
            // Check in-memory cache first
            if let cachedEvents = healthEventsCache[petId] {
                if !cachedEvents.isEmpty {
                    print("📦 [getHealthEvents] Returning \(cachedEvents.count) cached events for pet: \(petId)")
                    return cachedEvents
                } else {
                    // Cache has empty array, clear it to force fresh fetch
                    print("🔄 [getHealthEvents] Cache has empty array, clearing to force fresh fetch for pet: \(petId)")
                    healthEventsCache.removeValue(forKey: petId)
                    cacheCoordinator.invalidate(forKey: cacheKey)
                }
            } else if let cachedEvents = cacheCoordinator.get([HealthEvent].self, forKey: cacheKey) {
                // Check UnifiedCacheCoordinator
                if !cachedEvents.isEmpty {
                    healthEventsCache[petId] = cachedEvents
                    print("📦 [getHealthEvents] Returning \(cachedEvents.count) cached events from UnifiedCacheCoordinator for pet: \(petId)")
                    return cachedEvents
                } else {
                    // Cache has empty array, clear it
                    cacheCoordinator.invalidate(forKey: cacheKey)
                }
            }
        }
        
        isLoading = true
        error = nil
        
        do {
            var endpoint = "/health-events/pet/\(petId)?limit=\(limit)"
            if let category = category {
                endpoint += "&category=\(category.rawValue)"
            }
            
            // Log full request details
            print("🔍 [getHealthEvents] Fetching health events for pet: \(petId)")
            print("   Endpoint: \(endpoint)")
            print("   Base URL: \(Configuration.apiBaseURL)")
            print("   Full URL: \(Configuration.apiBaseURL)\(endpoint)")
            print("   Limit: \(limit)")
            if let category = category {
                print("   Category filter: \(category.rawValue)")
            }
            
            // Check authentication before making request
            let hasToken = await apiService.hasAuthToken
            print("   Has auth token: \(hasToken)")
            if !hasToken {
                print("   ⚠️ WARNING: No auth token - request will likely fail")
            }
            
            // CRITICAL: Always bypass cache for health events to ensure fresh data
            // Health events are dynamic and should always fetch from server
            let response = try await apiService.get(
                endpoint: endpoint,
                responseType: HealthEventListResponse.self,
                bypassCache: true  // Force fresh data from server
            )
            
            print("📦 [getHealthEvents] API Response received:")
            print("   Total: \(response.total)")
            print("   Events count: \(response.events.count)")
            print("   Limit: \(response.limit)")
            print("   Offset: \(response.offset)")
            
            if response.events.isEmpty {
                print("⚠️ [getHealthEvents] No events in response (but total=\(response.total))")
            } else {
                print("✅ [getHealthEvents] First event: \(response.events[0].id) - \(response.events[0].title)")
            }
            
            // Update cache using UnifiedCacheCoordinator
            let cacheKey = CacheKey.healthEvents.scoped(forPetId: petId)
            cacheCoordinator.set(response.events, forKey: cacheKey)
            healthEventsCache[petId] = response.events
            objectWillChange.send()
            
            print("✅ [getHealthEvents] Updated cache with \(response.events.count) events for pet: \(petId)")
            
            isLoading = false
            return response.events
            
        } catch {
            isLoading = false
            self.error = error
            print("❌ [getHealthEvents] Error loading health events for pet \(petId):")
            print("   Error: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            
            if let decodingError = error as? DecodingError {
                print("   Decoding error details: \(decodingError)")
                switch decodingError {
                case .dataCorrupted(let context):
                    print("     Data corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("     Key not found: \(key.stringValue) in \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("     Type mismatch: \(type) in \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("     Value not found: \(type) in \(context.debugDescription)")
                @unknown default:
                    print("     Unknown decoding error")
                }
            }
            if let apiError = error as? APIError {
                print("   API Error details: \(apiError)")
            }
            
            // Check if it's a network error
            if let urlError = error as? URLError {
                print("   URL Error code: \(urlError.code.rawValue)")
                print("   URL Error description: \(urlError.localizedDescription)")
                if urlError.code == .notConnectedToInternet {
                    print("   ⚠️ Network connection issue - check internet connection")
                } else if urlError.code == .timedOut {
                    print("   ⚠️ Request timed out - server may be slow or unreachable")
                } else if urlError.code == .cannotFindHost {
                    print("   ⚠️ Cannot find host - check API base URL: \(Configuration.apiBaseURL)")
                }
            }
            
            throw error
        }
    }
    
    /**
     * Get a specific health event by ID
     * 
     * - Parameter eventId: ID of the health event
     * - Returns: Health event
     * - Throws: APIError if fetch fails
     */
    func getHealthEvent(eventId: String) async throws -> HealthEvent {
        return try await apiService.get(
            endpoint: "/health-events/\(eventId)",
            responseType: HealthEvent.self
        )
    }
    
    /**
     * Update a health event
     * 
     * - Parameters:
     *   - eventId: ID of the health event
     *   - updates: Update data
     * - Returns: Updated health event
     * - Throws: APIError if update fails
     */
    func updateHealthEvent(_ eventId: String, updates: HealthEventUpdate) async throws -> HealthEvent {
        isLoading = true
        error = nil
        
        do {
            let updatedEvent = try await apiService.put(
                endpoint: "/health-events/\(eventId)",
                body: updates,
                responseType: HealthEvent.self
            )
            
            // Update cache - find which pet this event belongs to
            for (petId, events) in healthEventsCache {
                if let index = events.firstIndex(where: { $0.id == eventId }) {
                    var updatedEvents = events
                    updatedEvents[index] = updatedEvent
                    updatedEvents.sort { $0.eventDate > $1.eventDate }
                    
                    let cacheKey = CacheKey.healthEvents.scoped(forPetId: petId)
                    cacheCoordinator.set(updatedEvents, forKey: cacheKey)
                    healthEventsCache[petId] = updatedEvents
                    objectWillChange.send()
                    print("✅ [updateHealthEvent] Updated event in cache for pet: \(petId)")
                    break
                }
            }
            
            isLoading = false
            return updatedEvent
            
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    /**
     * Delete a health event
     * 
     * - Parameters:
     *   - eventId: ID of the health event
     *   - petId: ID of the pet (for cache update)
     * - Throws: APIError if deletion fails
     */
    func deleteHealthEvent(_ eventId: String, petId: String) async throws {
        isLoading = true
        error = nil
        
        do {
            try await apiService.delete(endpoint: "/health-events/\(eventId)")
            
            // Update cache using UnifiedCacheCoordinator
            var events = healthEvents(for: petId)
            events.removeAll { $0.id == eventId }
            
            let cacheKey = CacheKey.healthEvents.scoped(forPetId: petId)
            cacheCoordinator.set(events, forKey: cacheKey)
            healthEventsCache[petId] = events
            objectWillChange.send()
            
            print("✅ [deleteHealthEvent] Removed event from cache for pet: \(petId)")
            
            isLoading = false
            
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    /**
     * Get health events by category for a pet
     * 
     * - Parameters:
     *   - petId: ID of the pet
     *   - category: Category to filter by
     * - Returns: Array of health events in the category
     * - Throws: APIError if fetch fails
     */
    func getHealthEventsByCategory(
        for petId: String,
        category: HealthEventCategory
    ) async throws -> [HealthEvent] {
        return try await getHealthEvents(for: petId, category: category)
    }
    
    /**
     * Get recent health events for a pet (last 7 days)
     * 
     * - Parameter petId: ID of the pet
     * - Returns: Array of recent health events
     * - Throws: APIError if fetch fails
     */
    func getRecentHealthEvents(for petId: String) async throws -> [HealthEvent] {
        let allEvents = try await getHealthEvents(for: petId)
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        return allEvents.filter { $0.eventDate >= sevenDaysAgo }
    }
    
    /**
     * Get health event statistics for a pet
     * 
     * - Parameter petId: ID of the pet
     * - Returns: Dictionary of event type counts
     */
    func getHealthEventStats(for petId: String) -> [HealthEventType: Int] {
        let events = healthEvents(for: petId)
        
        var stats: [HealthEventType: Int] = [:]
        for event in events {
            stats[event.eventType, default: 0] += 1
        }
        
        return stats
    }
    
    /**
     * Clear cached health events for a pet using UnifiedCacheCoordinator
     * 
     * - Parameter petId: ID of the pet
     */
    func clearHealthEvents(for petId: String) {
        let cacheKey = CacheKey.healthEvents.scoped(forPetId: petId)
        cacheCoordinator.invalidate(forKey: cacheKey)
        healthEventsCache.removeValue(forKey: petId)
        objectWillChange.send()
        print("🗑️ [clearHealthEvents] Cleared cache for pet: \(petId)")
    }
    
    /**
     * Clear all cached health events using UnifiedCacheCoordinator
     */
    func clearAllHealthEvents() {
        for petId in healthEventsCache.keys {
            let cacheKey = CacheKey.healthEvents.scoped(forPetId: petId)
            cacheCoordinator.invalidate(forKey: cacheKey)
        }
        healthEventsCache.removeAll()
        objectWillChange.send()
        print("🗑️ [clearAllHealthEvents] Cleared all health event caches")
    }
    
    /**
     * Refresh health events for a pet (force refresh from server)
     * 
     * - Parameter petId: ID of the pet
     * - Throws: APIError if refresh fails
     */
    func refreshHealthEvents(for petId: String) async throws {
        _ = try await getHealthEvents(for: petId, forceRefresh: true)
    }
    
    /**
     * Remove expired cache entries
     * UnifiedCacheCoordinator handles expiration automatically
     * 
     * - Returns: Number of expired entries removed (always 0, handled by coordinator)
     */
    @discardableResult
    func cleanupExpiredCache() -> Int {
        // UnifiedCacheCoordinator handles expiration automatically
        // This method is kept for API compatibility
        return 0
    }
}
