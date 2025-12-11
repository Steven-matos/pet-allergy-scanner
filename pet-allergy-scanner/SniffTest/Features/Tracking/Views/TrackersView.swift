//
//  TrackersView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import SwiftUI

/**
 * Trackers View
 * 
 * Central hub for various pet tracking features including:
 * - Weight tracking and management
 * - Feeding logs and nutrition tracking
 * - Health monitoring and trends
 * - Activity and behavior tracking
 * 
 * Follows SOLID principles with single responsibility for tracking features
 * Implements DRY by reusing common UI components
 * Follows KISS by keeping the interface intuitive and organized
 */
struct TrackersView: View {
    @EnvironmentObject var authService: AuthService
    @State private var petService = CachedPetService.shared
    @ObservedObject private var healthEventService = HealthEventService.shared
    @State private var selectedTracker: TrackerType = .health
    @State private var showingAddTracker = false
    @State private var lastAppearTime: Date?
    @State private var cardEventCounts: [String: Int] = [:]
    @State private var refreshTrigger = UUID()
    
    enum TrackerType: String, CaseIterable {
        case health = "Health Events"
        
        var icon: String {
            switch self {
            case .health: return "heart.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .health: return ModernDesignSystem.Colors.warning
            }
        }
    }
    
    
    var body: some View {
        NavigationView {
            ZStack {
                ModernDesignSystem.Colors.softCream
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: ModernDesignSystem.Spacing.lg) {
                        // Header Section only (stable)
                        headerSection
                        
                        // Quick Actions Grid (stable)
                        quickActionsGrid
                        
                // Tracker Cards (shows cached event counts; no images)
                        ForEach(petService.pets.prefix(3)) { pet in
                            SimplePetCardStatic(
                                pet: pet,
                                eventCount: cardEventCounts[pet.id] ?? 0
                            )
                            .id("\(pet.id)-\(cardEventCounts[pet.id] ?? 0)")
                        }
                    }
                    .padding(ModernDesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Trackers")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
        }
        .onAppear {
            // Reload counts every time view appears (including when returning from detail views)
            loadEventCounts()
        }
        .task(id: refreshTrigger) {
            // Also reload when refresh is explicitly triggered
            loadEventCounts()
        }
        .sheet(isPresented: $showingAddTracker, onDismiss: {
            // Refresh counts when sheet is dismissed (event may have been added)
            refreshTrigger = UUID()
        }) {
            AddHealthEventView()
        }
    }
    
    // MARK: - Load Operations
    
    /**
     * Load event counts for all pets asynchronously
     */
    private func loadEventCounts() {
        Task.detached(priority: .utility) {
            let pets = await MainActor.run { petService.pets.prefix(3) }
            var counts: [String: Int] = [:]
            for pet in pets {
                let events = await MainActor.run { healthEventService.healthEvents(for: pet.id) }
                counts[pet.id] = events.count
                await Task.yield()
            }
            await MainActor.run {
                cardEventCounts = counts
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Health Event Tracking")
                .font(ModernDesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text("Log and monitor your pet's health events like vomiting, vet visits, and behavioral changes.")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Quick Actions Grid
    
    private var quickActionsGrid: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            ForEach(TrackerType.allCases, id: \.self) { tracker in
                QuickActionCard(
                    title: tracker == .health ? "Add Health Event" : tracker.rawValue,
                    icon: tracker.icon,
                    color: tracker.color
                ) {
                    selectedTracker = tracker
                    if tracker == .health {
                        showingAddTracker = true
                    }
                }
            }
        }
    }
    
    // MARK: - Tracker Cards Section
    
    private var trackerCardsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Health Events")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if petService.pets.isEmpty {
                TrackerEmptyStateView(
                    icon: "pawprint.fill",
                    title: "No Pets Added",
                    message: "Add a pet to start tracking their health events."
                )
            } else {
                ForEach(petService.pets.prefix(3)) { pet in
                    SimplePetCardStatic(pet: pet, eventCount: cardEventCounts[pet.id] ?? 0)
                }
            }
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .background(ModernDesignSystem.Colors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Tracker Empty State View

struct TrackerEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text(title)
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text(message)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(ModernDesignSystem.Spacing.xl)
        .background(ModernDesignSystem.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
}

// MARK: - Add Tracker Sheet

struct AddTrackerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Add New Tracker")
                    .font(ModernDesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("This feature will be available soon!")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}

/// Minimal card to isolate layout issues (no images, no events)
/// Fully static card: no events access, to avoid blocking UI
struct SimplePetCardStatic: View {
    let pet: Pet
    let eventCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.name)
                        .font(ModernDesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text(pet.breed ?? "Pet")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                if eventCount > 0 {
                    NavigationLink(destination: HealthEventListView(pet: pet)) {
                        Text("View Events")
                            .font(ModernDesignSystem.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                            .padding(.horizontal, ModernDesignSystem.Spacing.md)
                            .padding(.vertical, ModernDesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                    .stroke(ModernDesignSystem.Colors.primary, lineWidth: 1)
                            )
                    }
                }
            }
            
            Text("Events: \(eventCount)")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
}

#Preview {
    TrackersView()
        .environmentObject(AuthService.shared)
}
