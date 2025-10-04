//
//  NutritionDashboardView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import Combine

/**
 * Nutrition Dashboard View
 * 
 * Provides a comprehensive nutrition overview for pets with support for:
 * - Single pet (free tier)
 * - Multiple pets (premium tier)
 * - Nutrition tracking and recommendations
 * - Pet-specific dietary analysis
 */
struct NutritionDashboardView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var petService = PetService.shared
    @State private var selectedPet: Pet?
    @State private var showingPremiumUpgrade = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading nutrition data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if petService.pets.isEmpty {
                    EmptyNutritionView()
                } else {
                    nutritionContent
                }
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingPremiumUpgrade = true
                    }) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.orange)
                    }
                    .disabled(authService.currentUser?.role == .premium)
                }
            }
        }
        .environmentObject(petService)
        .onAppear {
            print("🔍 NutritionDashboardView: onAppear called")
            // Temporarily disable loadNutritionData to test
            // loadNutritionData()
        }
        .onDisappear {
            print("🔍 NutritionDashboardView: onDisappear called")
        }
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
        }
    }
    
    @ViewBuilder
    private var nutritionContent: some View {
        if let user = authService.currentUser {
            if user.role == .free && petService.pets.count > 1 {
                // Free tier with multiple pets - show upgrade prompt
                MultiplePetsUpgradeView(petCount: petService.pets.count)
            } else {
                // Show nutrition dashboard
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Pet Selection (for premium users with multiple pets)
                        if user.role == .premium && petService.pets.count > 1 {
                            PetSelectionSection(
                                pets: petService.pets,
                                selectedPet: $selectedPet
                            )
                        }
                        
                        // Nutrition Overview
                        if let pet = selectedPet ?? petService.pets.first {
                            NutritionOverviewSection(pet: pet)
                            NutritionRecommendationsSection(pet: pet)
                            NutritionHistorySection(pet: pet)
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    /**
     * Load nutrition data for the current user's pets
     */
    private func loadNutritionData() {
        print("🔍 NutritionDashboardView: loadNutritionData() called")
        isLoading = true
        
        Task {
            print("🔍 NutritionDashboardView: Calling petService.loadPets()")
            petService.loadPets()
            
            // Set default selected pet for premium users
            if let user = authService.currentUser,
               user.role == .premium,
               !petService.pets.isEmpty {
                print("🔍 NutritionDashboardView: Setting selectedPet to first pet")
                selectedPet = petService.pets.first
            }
            
            await MainActor.run {
                print("🔍 NutritionDashboardView: Setting isLoading = false")
                isLoading = false
            }
        }
    }
}

/**
 * Pet Selection Section for Premium Users
 */
struct PetSelectionSection: View {
    let pets: [Pet]
    @Binding var selectedPet: Pet?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Pet")
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pets) { pet in
                        PetSelectionCard(
                            pet: pet,
                            isSelected: selectedPet?.id == pet.id
                        ) {
                            selectedPet = pet
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
}

/**
 * Individual Pet Selection Card
 */
struct PetSelectionCard: View {
    let pet: Pet
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Pet Image
                AsyncImage(url: URL(string: pet.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: pet.species.icon)
                        .font(.title)
                        .foregroundColor(.gray)
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                
                // Pet Name
                Text(pet.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? ModernDesignSystem.Colors.primary : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? ModernDesignSystem.Colors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/**
 * Nutrition Overview Section
 */
struct NutritionOverviewSection: View {
    let pet: Pet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Nutrition Overview")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Image(systemName: pet.species.icon)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                NutritionMetricCard(
                    title: "Life Stage",
                    value: pet.lifeStage.displayName,
                    icon: "clock",
                    color: .blue
                )
                
                NutritionMetricCard(
                    title: "Activity Level",
                    value: pet.effectiveActivityLevel.displayName,
                    icon: "figure.run",
                    color: .green
                )
                
                NutritionMetricCard(
                    title: "Age",
                    value: pet.ageDescription ?? "Unknown",
                    icon: "calendar",
                    color: .orange
                )
                
                NutritionMetricCard(
                    title: "Weight",
                    value: pet.weightKg != nil ? "\(Int(pet.weightKg!)) kg" : "Not set",
                    icon: "scalemass",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

/**
 * Individual Nutrition Metric Card
 */
struct NutritionMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

/**
 * Nutrition Recommendations Section
 */
struct NutritionRecommendationsSection: View {
    let pet: Pet
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutritional Recommendations")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                RecommendationCard(
                    title: "Daily Calorie Intake",
                    description: "Recommended: 800-1200 calories",
                    icon: "flame.fill",
                    color: .red
                )
                
                RecommendationCard(
                    title: "Protein Requirements",
                    description: "High-quality protein: 25-30%",
                    icon: "leaf.fill",
                    color: .green
                )
                
                RecommendationCard(
                    title: "Hydration",
                    description: "Fresh water available at all times",
                    icon: "drop.fill",
                    color: .blue
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

/**
 * Individual Recommendation Card
 */
struct RecommendationCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

/**
 * Nutrition History Section with Live Data
 * 
 * This view displays recent nutrition activity from actual scan data
 * following SOLID, DRY, and KISS principles
 */
struct NutritionHistorySection: View {
    let pet: Pet
    @StateObject private var activityViewModel = NutritionActivityViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Nutrition Activity")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if activityViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let errorMessage = activityViewModel.errorMessage {
                ErrorView(message: errorMessage) {
                    activityViewModel.refreshActivity(for: pet.id)
                } onClearCache: {
                    activityViewModel.clearCacheAndRefresh(for: pet.id)
                }
            } else if activityViewModel.recentScans.isEmpty && !activityViewModel.isLoading {
                EmptyStateView()
            } else {
                VStack(spacing: 12) {
                    ForEach(activityViewModel.recentScans) { scan in
                        LiveHistoryItem(
                            scan: scan,
                            viewModel: activityViewModel
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .onAppear {
            activityViewModel.loadRecentActivity(for: pet.id)
        }
    }
}

/**
 * Live History Item using real scan data
 */
struct LiveHistoryItem: View {
    let scan: Scan
    let viewModel: NutritionActivityViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Circle()
                    .fill(colorForSafety(scan.result?.overallSafety ?? "unknown"))
                    .frame(width: 8, height: 8)
                
                Rectangle()
                    .fill(ModernDesignSystem.Colors.primary.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.getActivityDescription(for: scan))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(viewModel.getResultDescription(for: scan))
                    .font(.caption)
                    .foregroundColor(colorForSafety(scan.result?.overallSafety ?? "unknown"))
                
                Text(viewModel.formatDate(scan.createdAt))
                    .font(.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
    
    /**
     * Get color for safety status
     */
    private func colorForSafety(_ safety: String) -> Color {
        switch safety.lowercased() {
        case "safe":
            return .green
        case "caution", "warning":
            return .orange
        case "unsafe":
            return .red
        default:
            return .gray
        }
    }
}

/**
 * Empty State View for when no nutrition activity exists
 */
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            Text("No Recent Activity")
                .font(.headline)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text("Start scanning pet food to see nutrition activity here")
                .font(.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
    }
}

/**
 * Error View for displaying errors
 */
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onClearCache: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundColor(.orange)
            
            Text("Unable to Load Activity")
                .font(.headline)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                Button("Try Again") {
                    onRetry()
                }
                .buttonStyle(.bordered)
                .tint(ModernDesignSystem.Colors.primary)
                
                Button("Clear Cache & Retry") {
                    onClearCache()
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding(.vertical, 20)
    }
}

/**
 * Individual History Item
 */
struct HistoryItem: View {
    let date: String
    let action: String
    let result: String
    
    var body: some View {
        HStack(spacing: 12) {
            VStack {
                Circle()
                    .fill(ModernDesignSystem.Colors.primary)
                    .frame(width: 8, height: 8)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 20)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(action)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(result)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

/**
 * Empty State View for No Pets
 */
struct EmptyNutritionView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Pets Added")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add a pet to start tracking their nutrition and dietary needs")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            NavigationLink(destination: AddPetView()) {
                Text("Add Your First Pet")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(ModernDesignSystem.Colors.primary)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/**
 * Premium Upgrade View for Multiple Pets
 */
struct MultiplePetsUpgradeView: View {
    let petCount: Int
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Unlock Multiple Pets")
                .font(.title)
                .fontWeight(.bold)
            
            Text("You have \(petCount) pets but need Premium to access nutrition tracking for all of them")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                NutritionFeatureRow(icon: "pawprint.fill", text: "Track nutrition for unlimited pets")
                NutritionFeatureRow(icon: "leaf.fill", text: "Advanced nutrition recommendations")
                NutritionFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Detailed nutrition analytics")
                NutritionFeatureRow(icon: "bell.fill", text: "Custom feeding reminders")
            }
            .padding()
            
            Button(action: {
                // Handle premium upgrade
            }) {
                Text("Upgrade to Premium")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ModernDesignSystem.Colors.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/**
 * Feature Row for Premium Upgrade
 */
struct NutritionFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

/**
 * Premium Upgrade Sheet
 */
struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Premium Features")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Premium features list
                VStack(spacing: 16) {
                    PremiumFeatureCard(
                        icon: "pawprint.fill",
                        title: "Multiple Pets",
                        description: "Track nutrition for unlimited pets"
                    )
                    
                    PremiumFeatureCard(
                        icon: "leaf.fill",
                        title: "Advanced Nutrition",
                        description: "Detailed dietary analysis and recommendations"
                    )
                    
                    PremiumFeatureCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Analytics",
                        description: "Track nutrition trends and health insights"
                    )
                }
                
                Spacer()
                
                Button("Upgrade Now") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/**
 * Premium Feature Card
 */
struct PremiumFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    NutritionDashboardView()
        .environmentObject(AuthService.shared)
}
