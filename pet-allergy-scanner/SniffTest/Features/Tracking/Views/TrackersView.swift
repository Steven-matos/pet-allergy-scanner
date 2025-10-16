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
    @StateObject private var petService = PetService.shared
    @StateObject private var healthEventService = HealthEventService.shared
    @State private var selectedTracker: TrackerType = .health
    @State private var showingAddTracker = false
    @State private var showingHealthEvents = false
    
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
                    VStack(spacing: ModernDesignSystem.Spacing.lg) {
                        // Header Section
                        headerSection
                        
                        // Quick Actions Grid
                        quickActionsGrid
                        
                        // Tracker Cards
                        trackerCardsSection
                    }
                    .padding(ModernDesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Trackers")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingAddTracker) {
            AddHealthEventView()
        }
        .sheet(isPresented: $showingHealthEvents) {
            if let selectedPet = petService.pets.first {
                HealthEventListView(pet: selectedPet)
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
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                .fill(ModernDesignSystem.Colors.background)
                .shadow(
                    color: ModernDesignSystem.Shadows.medium.color,
                    radius: ModernDesignSystem.Shadows.medium.radius,
                    x: ModernDesignSystem.Shadows.medium.x,
                    y: ModernDesignSystem.Shadows.medium.y
                )
        )
    }
    
    // MARK: - Quick Actions Grid
    
    private var quickActionsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: ModernDesignSystem.Spacing.md) {
            ForEach(TrackerType.allCases, id: \.self) { tracker in
                QuickActionCard(
                    title: tracker.rawValue,
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
                    PetHealthEventCard(pet: pet)
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
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
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
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Pet Health Event Card

struct PetHealthEventCard: View {
    let pet: Pet
    @StateObject private var healthEventService = HealthEventService.shared
    
    var recentEvents: [HealthEvent] {
        healthEventService.healthEvents[pet.id]?.prefix(3).map { $0 } ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                AsyncImage(url: URL(string: pet.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "pawprint.fill")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.name)
                        .font(ModernDesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("Health Events")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Button("View Events") {
                    // TODO: Navigate to health events for this pet
                }
                .font(ModernDesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                .padding(.vertical, ModernDesignSystem.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                        .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                )
            }
            
            if !recentEvents.isEmpty {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    ForEach(recentEvents) { event in
                        HStack {
                            Image(systemName: event.eventType.iconName)
                                .foregroundColor(event.eventType.category.color)
                                .font(.caption)
                            
                            Text(event.title)
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(event.eventDate, style: .date)
                                .font(ModernDesignSystem.Typography.caption2)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .padding(.top, ModernDesignSystem.Spacing.xs)
            } else {
                Text("No recent health events")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .padding(.top, ModernDesignSystem.Spacing.xs)
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
        .task {
            // Load health events for this pet
            do {
                _ = try await healthEventService.getHealthEvents(for: pet.id)
            } catch {
                print("Error loading health events for \(pet.name): \(error)")
            }
        }
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
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                .fill(ModernDesignSystem.Colors.background)
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
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

#Preview {
    TrackersView()
        .environmentObject(AuthService.shared)
}
