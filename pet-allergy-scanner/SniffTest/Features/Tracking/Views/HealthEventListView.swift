//
//  HealthEventListView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import SwiftUI

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
    
    var filteredEvents: [HealthEvent] {
        guard let events = healthEventService.healthEvents[pet.id] else { return [] }
        
        let filtered = selectedCategory == nil ? events : events.filter { $0.eventCategory == selectedCategory }
        return filtered.sorted { $0.eventDate > $1.eventDate }
    }
    
    var groupedEvents: [(String, [HealthEvent])] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [(String, [HealthEvent])] = []
        var todayEvents: [HealthEvent] = []
        var yesterdayEvents: [HealthEvent] = []
        var thisWeekEvents: [HealthEvent] = []
        var earlierEvents: [HealthEvent] = []
        
        for event in filteredEvents {
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
        
        return groups
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ModernDesignSystem.Colors.softCream
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Category Filter
                    categoryFilterSection
                    
                    // Events List
                    if filteredEvents.isEmpty {
                        emptyStateView
                    } else {
                        eventsListSection
                    }
                }
            }
            .navigationTitle("Health Events")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
            Button("Add Event") {
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
                AddHealthEventView(pet: pet)
            }
            .task {
                await loadHealthEvents()
            }
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
                    selectedCategory = nil
                }
                
                ForEach(HealthEventCategory.allCases, id: \.self) { category in
                    let count = healthEventService.healthEvents[pet.id]?.filter { $0.eventCategory == category }.count ?? 0
                    
                    CategoryFilterChip(
                        title: category.displayName,
                        isSelected: selectedCategory == category,
                        count: count
                    ) {
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
                ForEach(groupedEvents, id: \.0) { group in
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        // Group Header
                        Text(group.0)
                            .font(ModernDesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                        
                        // Group Events
                        ForEach(group.1) { event in
                            HealthEventRowView(event: event, pet: pet)
                        }
                    }
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.bottom, ModernDesignSystem.Spacing.xl)
        }
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
            _ = try await healthEventService.getHealthEvents(for: pet.id)
        } catch {
            print("Error loading health events: \(error)")
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
    @StateObject private var healthEventService = HealthEventService.shared
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Event Icon
            Image(systemName: event.eventType.iconName)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(hex: event.eventType.colorCode))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color(hex: event.eventType.colorCode).opacity(0.1))
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
                    
                    Text(event.severityDescription)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(Color(hex: event.severityColor))
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
