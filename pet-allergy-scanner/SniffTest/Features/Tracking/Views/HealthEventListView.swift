//
//  HealthEventListView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import SwiftUI
import Foundation

/**
 * Health Event List View
 * 
 * List view showing health events for a pet with filtering and grouping
 * Follows SOLID principles with single responsibility for health event display
 * Implements DRY by reusing common list patterns
 * Follows KISS by keeping the interface simple and organized
 */
struct HealthEventListView: View {
    let pet: Pet
    @StateObject private var healthEventService = HealthEventService.shared
    @State private var selectedCategory: HealthEventCategory? = nil
    @State private var showingAddEvent = false
    @State private var isLoading = false
    @State private var selectedEvent: HealthEvent? = nil
    
    // Performance optimization: Cache computed properties
    @State private var cachedFilteredEvents: [HealthEvent] = []
    @State private var cachedMedicationEvents: [HealthEvent] = []
    @State private var cachedGroupedEvents: [(String, [HealthEvent])] = []
    @State private var lastUpdateTime: Date = Date()
    
    // Performance optimized computed properties with memoization
    var filteredEvents: [HealthEvent] {
        // Use cached data if recent and category hasn't changed
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastUpdateTime) < 1.0 && !cachedFilteredEvents.isEmpty {
            print("🔄 Using cached filtered events: \(cachedFilteredEvents.count)")
            return cachedFilteredEvents
        }
        
        guard let events = healthEventService.healthEvents[pet.id] else { 
            print("❌ No events found for pet: \(pet.id)")
            return []
        }
        
        let filtered = selectedCategory == nil ? events : events.filter { $0.eventCategory == selectedCategory }
        let sorted = filtered.sorted { $0.eventDate > $1.eventDate }
        
        print("📊 Filtered events - Total: \(events.count), Filtered: \(filtered.count), Category: \(selectedCategory?.displayName ?? "All")")
        
        return sorted
    }
    
    var medicationEvents: [HealthEvent] {
        // Use cached data if recent
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastUpdateTime) < 1.0 && !cachedMedicationEvents.isEmpty {
            return cachedMedicationEvents
        }
        
        guard let events = healthEventService.healthEvents[pet.id] else { 
            return []
        }
        
        let filtered = events.filter { $0.eventType == .medication }
        let sorted = filtered.sorted { $0.eventDate > $1.eventDate }
        
        return sorted
    }
    
    var groupedEvents: [(String, [HealthEvent])] {
        // Use cached data if recent and events haven't changed
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastUpdateTime) < 1.0 && !cachedGroupedEvents.isEmpty {
            print("🔄 Using cached grouped events: \(cachedGroupedEvents.count) groups")
            return cachedGroupedEvents
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [(String, [HealthEvent])] = []
        var todayEvents: [HealthEvent] = []
        var yesterdayEvents: [HealthEvent] = []
        var thisWeekEvents: [HealthEvent] = []
        var earlierEvents: [HealthEvent] = []
        
        let eventsToGroup = filteredEvents
        print("📅 Grouping \(eventsToGroup.count) events")
        
        for event in eventsToGroup {
            let daysBetween = calendar.dateComponents([.day], from: event.eventDate, to: now).day ?? 0
            
            if daysBetween == 0 {
                todayEvents.append(event)
            } else if daysBetween == 1 {
                yesterdayEvents.append(event)
            } else if daysBetween <= 7 {
                thisWeekEvents.append(event)
            } else {
                earlierEvents.append(event)
            }
        }
        
        if !todayEvents.isEmpty {
            groups.append(("Today", todayEvents))
        }
        if !yesterdayEvents.isEmpty {
            groups.append(("Yesterday", yesterdayEvents))
        }
        if !thisWeekEvents.isEmpty {
            groups.append(("This Week", thisWeekEvents))
        }
        if !earlierEvents.isEmpty {
            groups.append(("Earlier", earlierEvents))
        }
        
        print("📊 Grouped events - Today: \(todayEvents.count), Yesterday: \(yesterdayEvents.count), This Week: \(thisWeekEvents.count), Earlier: \(earlierEvents.count)")
        
        return groups
    }
    
    // Performance optimization: Clear cache when data changes
    private func invalidateCache() {
        cachedFilteredEvents = []
        cachedMedicationEvents = []
        cachedGroupedEvents = []
        lastUpdateTime = Date()
    }
    
    var body: some View {
        ZStack {
            ModernDesignSystem.Colors.softCream
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Category Filter
                categoryFilterSection
                
                // Events List
                if isLoading {
                    loadingView
                } else if filteredEvents.isEmpty && medicationEvents.isEmpty {
                    emptyStateView
                } else {
                    eventsListSection
                }
            }
        }
        .navigationTitle("Health Events for \(pet.name)")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Add Event") {
                    PostHogAnalytics.trackAddHealthEventTapped(petId: pet.id)
                    showingAddEvent = true
                }
                .font(ModernDesignSystem.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.vertical, ModernDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(ModernDesignSystem.Colors.primary)
                )
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddHealthEventView()
        }
        .sheet(item: $selectedEvent) { event in
            HealthEventDetailView(event: event, pet: pet)
                .onAppear {
                    PostHogAnalytics.trackHealthEventViewed(
                        eventId: event.id,
                        eventCategory: event.eventCategory.rawValue
                    )
                }
        }
        .task {
            await loadHealthEvents()
        }
        .onAppear {
            PostHogAnalytics.trackHealthEventsViewOpened(petId: pet.id)
            // Ensure data is loaded when view appears
            Task {
                await loadHealthEvents()
            }
        }
        .refreshable {
            // Allow pull-to-refresh to reload data
            PostHogAnalytics.trackHealthEventsRefreshed(petId: pet.id)
            await loadHealthEvents()
        }
        .onChange(of: selectedCategory) { _, _ in
            invalidateCache()
        }
        .onChange(of: healthEventService.healthEvents[pet.id]) { _, _ in
            invalidateCache()
        }
    }
    
    // MARK: - Category Filter Section
    
    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                CategoryFilterChip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    count: healthEventService.healthEvents[pet.id]?.count ?? 0
                ) {
                    PostHogAnalytics.trackHealthEventFilterChanged(category: nil)
                    selectedCategory = nil
                }
                
                ForEach(HealthEventCategory.allCases, id: \.self) { category in
                    let count = healthEventService.healthEvents[pet.id]?.filter { $0.eventCategory == category }.count ?? 0
                    
                    CategoryFilterChip(
                        title: category.displayName,
                        isSelected: selectedCategory == category,
                        count: count
                    ) {
                        PostHogAnalytics.trackHealthEventFilterChanged(category: category.rawValue)
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
    }
    
    // MARK: - Events List Section
    
    private var eventsListSection: some View {
        ScrollView {
            LazyVStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Medications Section (if any)
                if !medicationEvents.isEmpty {
                    medicationsSection
                        .id("medications-section-\(medicationEvents.count)")
                }
                
                // Regular Events with optimized identifiers
                ForEach(Array(groupedEvents.enumerated()), id: \.offset) { index, group in
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        // Group Header
                        Text(group.0)
                            .font(ModernDesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                        
                        // Group Events with stable identifiers
                        ForEach(group.1, id: \.id) { event in
                            HealthEventRowView(
                                event: event, 
                                pet: pet,
                                onTap: {
                                    selectedEvent = event
                                }
                            )
                            .id("event-\(event.id)")
                        }
                    }
                    .id("group-\(index)-\(group.0)")
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.bottom, ModernDesignSystem.Spacing.xl)
        }
    }
    
    // MARK: - Medications Section
    
    private var medicationsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            // Medications Header
            HStack {
                Image(systemName: "pills.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.system(size: 16, weight: .medium))
                
                Text("Medications")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(medicationEvents.count)")
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                    )
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            // Medication Events with optimized identifiers
            ForEach(medicationEvents, id: \.id) { event in
                HealthEventRowView(
                    event: event, 
                    pet: pet,
                    onTap: {
                        selectedEvent = event
                    }
                )
                .id("medication-\(event.id)")
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading health events...")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .padding(.top, ModernDesignSystem.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("No Health Events")
                .font(ModernDesignSystem.Typography.title2)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text("Start tracking your pet's health by adding events like vet visits, symptoms, or behavioral changes.")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            Button("Add First Event") {
                showingAddEvent = true
            }
            .font(ModernDesignSystem.Typography.body)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.vertical, ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .fill(ModernDesignSystem.Colors.primary)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func loadHealthEvents() async {
        isLoading = true
        
        do {
            let events = try await healthEventService.getHealthEvents(for: pet.id)
            print("✅ Loaded \(events.count) health events for pet: \(pet.id)")
            
            // Force UI update after data is loaded
            await MainActor.run {
                invalidateCache()
            }
        } catch {
            print("❌ Error loading health events: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Category Filter Chip

struct CategoryFilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                Text(title)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(ModernDesignSystem.Typography.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? .white : ModernDesignSystem.Colors.primary)
                        )
                        .foregroundColor(isSelected ? ModernDesignSystem.Colors.primary : .white)
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.background)
                    .stroke(ModernDesignSystem.Colors.primary, lineWidth: isSelected ? 0 : 1)
            )
            .foregroundColor(isSelected ? .white : ModernDesignSystem.Colors.primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Health Event Row View

struct HealthEventRowView: View {
    let event: HealthEvent
    let pet: Pet
    let onTap: (() -> Void)?
    @StateObject private var healthEventService = HealthEventService.shared
    @State private var showingDeleteAlert = false
    
    // Performance optimization: Cache computed values
    private var eventIconName: String { event.eventType.iconName }
    private var eventColor: Color { Color(hex: event.eventType.colorCode) }
    private var severityColor: Color { Color(hex: event.severityColor) }
    private var severityDescription: String { event.severityDescription }
    
    init(event: HealthEvent, pet: Pet, onTap: (() -> Void)? = nil) {
        self.event = event
        self.pet = pet
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                // Event Icon - using cached values
                Image(systemName: eventIconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(eventColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(eventColor.opacity(0.1))
                    )
                
                // Event Details
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(ModernDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    HStack {
                        Text(event.eventType.displayName)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Text("•")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Text(severityDescription)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(severityColor)
                    }
                    
                    Text(event.eventDate, style: .relative)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Severity Indicator
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { level in
                        Circle()
                            .fill(level <= event.severityLevel ? Color(hex: event.severityColor) : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .fill(ModernDesignSystem.Colors.background)
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete", role: .destructive) {
                showingDeleteAlert = true
            }
        }
        .alert("Delete Health Event", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteHealthEvent()
            }
        } message: {
            Text("Are you sure you want to delete this health event? This action cannot be undone.")
        }
    }
    
    private func deleteHealthEvent() {
        Task {
            do {
                try await healthEventService.deleteHealthEvent(event.id, petId: pet.id)
            } catch {
                print("Error deleting health event: \(error)")
            }
        }
    }
}


#Preview {
    HealthEventListView(pet: Pet(
        id: "preview-pet",
        userId: "preview-user",
        name: "Buddy",
        species: .dog,
        breed: "Golden Retriever",
        birthday: Date(),
        weightKg: 25.0,
        activityLevel: .moderate,
        imageUrl: nil,
        knownSensitivities: [],
        vetName: nil,
        vetPhone: nil,
        createdAt: Date(),
        updatedAt: Date()
    ))
}
