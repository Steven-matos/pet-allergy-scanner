//
//  HealthEventService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation

/**
 * Health Event Service
 * 
 * Manages health event data and API communication
 * Follows SOLID principles with single responsibility for health event operations
 * Implements DRY by reusing common API patterns
 * Follows KISS by keeping the service simple and focused
 */
@MainActor
class HealthEventService: ObservableObject {
    static let shared = HealthEventService()
    
    @Published var healthEvents: [String: [HealthEvent]] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService = APIService.shared
    
    private init() {}
    
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
            
            // Update local cache and notify observers
            await MainActor.run {
                if healthEvents[petId] == nil {
                    healthEvents[petId] = []
                }
                healthEvents[petId]?.append(createdEvent)
                healthEvents[petId]?.sort { $0.eventDate > $1.eventDate }
                
                // CRITICAL: Force SwiftUI to detect the change
                // Dictionary mutations don't always trigger @Published updates
                objectWillChange.send()
                print("✅ [createHealthEvent] Added event to cache and notified observers")
                print("   Pet ID: \(petId), Event count: \(healthEvents[petId]?.count ?? 0)")
            }
            
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
     * - Returns: Array of health events
     * - Throws: APIError if fetch fails
     */
    func getHealthEvents(
        for petId: String,
        limit: Int = 50,
        category: HealthEventCategory? = nil
    ) async throws -> [HealthEvent] {
        
        isLoading = true
        error = nil
        
        do {
            var endpoint = "/health-events/pet/\(petId)?limit=\(limit)"
            if let category = category {
                endpoint += "&category=\(category.rawValue)"
            }
            
            print("🔍 [getHealthEvents] Fetching health events for pet: \(petId)")
            print("   Endpoint: \(endpoint)")
            
            let response = try await apiService.get(
                endpoint: endpoint,
                responseType: HealthEventListResponse.self
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
            
            // Update local cache and notify observers
            // CRITICAL: @Published doesn't always detect dictionary mutations
            // Must explicitly notify observers to trigger SwiftUI updates
            await MainActor.run {
                healthEvents[petId] = response.events
                objectWillChange.send()
                print("✅ [getHealthEvents] Updated cache with \(response.events.count) events for pet: \(petId)")
                print("   Cache now contains: \(healthEvents[petId]?.count ?? 0) events")
            }
            
            isLoading = false
            return response.events
            
        } catch {
            isLoading = false
            self.error = error
            print("❌ [getHealthEvents] Error loading health events for pet \(petId):")
            print("   Error type: \(type(of: error))")
            print("   Error description: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("   Decoding error details: \(decodingError)")
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
            
            // Update local cache
            // CRITICAL FIX: @Published doesn't detect in-place array element mutations inside dictionaries
            // Create new dictionary instance to trigger observation
            await MainActor.run {
                var updatedHealthEvents = self.healthEvents
                for (petId, events) in updatedHealthEvents {
                    if let index = events.firstIndex(where: { $0.id == eventId }) {
                        var updatedEvents = events
                        updatedEvents[index] = updatedEvent
                        updatedHealthEvents[petId] = updatedEvents
                    }
                }
                self.healthEvents = updatedHealthEvents
                objectWillChange.send()
                print("✅ [updateHealthEvent] Updated event in cache and notified observers")
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
            
            // Remove from local cache
            // CRITICAL FIX: @Published doesn't detect in-place array mutations inside dictionaries
            // Create new dictionary instance to trigger observation
            await MainActor.run {
                var updatedHealthEvents = self.healthEvents
                if var events = updatedHealthEvents[petId] {
                    events.removeAll { $0.id == eventId }
                    updatedHealthEvents[petId] = events
                    self.healthEvents = updatedHealthEvents
                    objectWillChange.send()
                    print("✅ [deleteHealthEvent] Removed event from cache and notified observers")
                }
            }
            
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
        guard let events = healthEvents[petId] else { return [:] }
        
        var stats: [HealthEventType: Int] = [:]
        for event in events {
            stats[event.eventType, default: 0] += 1
        }
        
        return stats
    }
    
    /**
     * Clear cached health events for a pet
     * 
     * - Parameter petId: ID of the pet
     */
    func clearHealthEvents(for petId: String) {
        healthEvents.removeValue(forKey: petId)
    }
    
    /**
     * Clear all cached health events
     */
    func clearAllHealthEvents() {
        healthEvents.removeAll()
    }
    
    /**
     * Refresh health events for a pet
     * 
     * - Parameter petId: ID of the pet
     * - Throws: APIError if refresh fails
     */
    func refreshHealthEvents(for petId: String) async throws {
        _ = try await getHealthEvents(for: petId)
    }
}
