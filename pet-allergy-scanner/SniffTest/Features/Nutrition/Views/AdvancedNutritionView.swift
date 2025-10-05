//
//  AdvancedNutritionView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/**
 * Advanced Nutrition View
 * 
 * Comprehensive nutrition management interface with support for:
 * - Weight management and tracking
 * - Nutritional trends and analytics
 * - Food comparison and analysis
 * - Advanced health insights
 * 
 * Follows SOLID principles with single responsibility for advanced nutrition features
 * Implements DRY by reusing common UI components
 * Follows KISS by keeping the interface organized and intuitive
 */
struct AdvancedNutritionView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var petService = PetService.shared
    @StateObject private var petSelectionService = NutritionPetSelectionService.shared
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    @State private var selectedTab = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingWeightEntry = false
    @State private var showingGoalSetting = false
    
    private var selectedPet: Pet? {
        petSelectionService.selectedPet
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading nutrition data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let pet = selectedPet {
                    phase3Content(for: pet)
                } else {
                    petSelectionView
                }
            }
            .navigationTitle(selectedPet != nil ? "\(selectedPet!.name) - Advanced" : "Advanced Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedTab == 0 && selectedPet != nil {
                        // Weight tab - Add Weight button
                        Button(action: {
                            showingWeightEntry = true
                        }) {
                            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                                Image(systemName: "plus.circle.fill")
                                    .font(ModernDesignSystem.Typography.caption)
                                Text("Add Weight")
                                    .font(ModernDesignSystem.Typography.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                            .padding(.horizontal, ModernDesignSystem.Spacing.md)
                            .padding(.vertical, ModernDesignSystem.Spacing.sm)
                            .background(ModernDesignSystem.Colors.buttonPrimary)
                            .cornerRadius(ModernDesignSystem.CornerRadius.small)
                            .shadow(
                                color: ModernDesignSystem.Shadows.small.color,
                                radius: ModernDesignSystem.Shadows.small.radius,
                                x: ModernDesignSystem.Shadows.small.x,
                                y: ModernDesignSystem.Shadows.small.y
                            )
                        }
                    } else if selectedTab == 1 && selectedPet != nil {
                        // Trends tab - Period selector
                        Button("30 Days") {
                            // Period selector for trends
                        }
                        .foregroundColor(ModernDesignSystem.Colors.buttonPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.softCream)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh Data") {
                            loadNutritionData()
                        }
                        .disabled(selectedPet == nil || isLoading)
                        
                        if selectedPet != nil {
                            Button("Change Pet") {
                                petSelectionService.clearSelection()
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(ModernDesignSystem.Colors.textPrimary)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.softCream)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .shadow(
                            color: ModernDesignSystem.Shadows.small.color,
                            radius: ModernDesignSystem.Shadows.small.radius,
                            x: ModernDesignSystem.Shadows.small.x,
                            y: ModernDesignSystem.Shadows.small.y
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showingWeightEntry) {
            if let pet = selectedPet {
                WeightEntryView(pet: pet)
                    .onDisappear {
                        // Refresh nutrition data when the weight entry sheet is dismissed
                        loadNutritionData()
                    }
            }
        }
        .sheet(isPresented: $showingGoalSetting) {
            if let pet = selectedPet {
                WeightGoalSettingView(pet: pet, existingGoal: nil)
                    .onDisappear {
                        // Refresh nutrition data when the goal setting sheet is dismissed
                        loadNutritionData()
                    }
            }
        }
        .onAppear {
            loadNutritionData()
        }
    }
    
    // MARK: - Pet Selection View
    
    private var petSelectionView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Select a Pet")
                .font(ModernDesignSystem.Typography.title2)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text("Choose a pet to access advanced nutrition features")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            if !petService.pets.isEmpty {
                LazyVStack(spacing: ModernDesignSystem.Spacing.md) {
                    ForEach(petService.pets) { pet in
                        AdvancedNutritionPetSelectionCard(pet: pet) {
                            petSelectionService.selectPet(pet)
                            loadNutritionData()
                        }
                    }
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
            } else {
                Text("No pets found. Add a pet to get started.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
    }
    
    // MARK: - Phase 3 Content
    
    @ViewBuilder
    private func phase3Content(for pet: Pet) -> some View {
        VStack(spacing: 0) {
            // Pet Header
            petHeaderSection(pet)
            
            // Tab Selection
            tabSelectionSection
            
            // Content based on selected tab
            TabView(selection: $selectedTab) {
                // Weight Management Tab
                WeightManagementView()
                    .environmentObject(authService)
                    .tag(0)
                
                // Nutritional Trends Tab
                NutritionalTrendsView()
                    .environmentObject(authService)
                    .tag(1)
                
                // Food Comparison Tab
                FoodComparisonView()
                    .environmentObject(authService)
                    .tag(2)
                
                // Advanced Analytics Tab
                AdvancedAnalyticsView()
                    .environmentObject(authService)
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
    
    // MARK: - Pet Header Section
    
    private func petHeaderSection(_ pet: Pet) -> some View {
        HStack {
            AsyncImage(url: URL(string: pet.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "pawprint.circle.fill")
                    .font(.title)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 2)
            )
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(pet.name)
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(pet.species.rawValue.capitalized)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                if let weight = pet.weightKg {
                    Text(unitService.formatWeight(weight))
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
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
    
    // MARK: - Tab Selection Section
    
    private var tabSelectionSection: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Image(systemName: tabIcon(for: index))
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(selectedTab == index ? 
                                ModernDesignSystem.Colors.primary : 
                                ModernDesignSystem.Colors.textSecondary)
                        
                        Text(tabTitle(for: index))
                            .font(ModernDesignSystem.Typography.caption)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                            .foregroundColor(selectedTab == index ? 
                                ModernDesignSystem.Colors.primary : 
                                ModernDesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ModernDesignSystem.Spacing.md)
                    .background(
                        selectedTab == index ? 
                            ModernDesignSystem.Colors.softCream : 
                            Color.clear
                    )
                    .overlay(
                        selectedTab == index ? 
                            Rectangle()
                                .frame(height: 3)
                                .foregroundColor(ModernDesignSystem.Colors.primary) : nil,
                        alignment: .bottom
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(ModernDesignSystem.Colors.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(ModernDesignSystem.Colors.lightGray),
            alignment: .bottom
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadNutritionData() {
        guard selectedPet != nil else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            // Load nutrition data for the selected pet
            // This would integrate with the various services
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "scalemass"
        case 1: return "chart.line.uptrend.xyaxis"
        case 2: return "chart.bar.xaxis"
        case 3: return "brain.head.profile"
        default: return "questionmark"
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Weight"
        case 1: return "Trends"
        case 2: return "Compare"
        case 3: return "Analytics"
        default: return "Unknown"
        }
    }
}

// MARK: - Supporting Views

struct AdvancedNutritionPetSelectionCard: View {
    let pet: Pet
    let onTap: () -> Void
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                AsyncImage(url: URL(string: pet.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.title)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 2)
                )
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(pet.name)
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text(pet.species.rawValue.capitalized)
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    if let weight = pet.weightKg {
                        Text(unitService.formatWeight(weight))
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .background(ModernDesignSystem.Colors.softCream)
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

// MARK: - Advanced Analytics View

struct AdvancedAnalyticsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var analyticsService = AdvancedAnalyticsService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var healthInsights: HealthInsights?
    @State private var nutritionalPatterns: NutritionalPatterns?
    
    var body: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                if isLoading {
                    ModernLoadingView(message: "Loading analytics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Health Insights Card
                    if let insights = healthInsights {
                        HealthInsightsCard(insights: insights)
                    }
                    
                    // Nutritional Patterns Card
                    if let patterns = nutritionalPatterns {
                        NutritionalPatternsCard(patterns: patterns)
                    }
                    
                    // Analytics Summary
                    analyticsSummarySection
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        .background(ModernDesignSystem.Colors.background)
        .onAppear {
            loadAnalyticsData()
        }
    }
    
    private var analyticsSummarySection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Analytics Summary")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ModernDesignSystem.Spacing.md) {
                AnalyticsSummaryCard(
                    title: "Health Score",
                    value: "\(Int(healthInsights?.overallHealthScore ?? 0))",
                    unit: "/100",
                    color: ModernDesignSystem.Colors.primary
                )
                
                AnalyticsSummaryCard(
                    title: "Nutritional Balance",
                    value: "\(Int(healthInsights?.nutritionalAdequacyScore ?? 0))",
                    unit: "%",
                    color: ModernDesignSystem.Colors.primary
                )
                
                AnalyticsSummaryCard(
                    title: "Feeding Consistency",
                    value: "\(Int(healthInsights?.feedingConsistencyScore ?? 0))",
                    unit: "%",
                    color: ModernDesignSystem.Colors.goldenYellow
                )
                
                AnalyticsSummaryCard(
                    title: "Weight Management",
                    value: healthInsights?.weightManagementStatus.capitalized ?? "Unknown",
                    unit: "",
                    color: ModernDesignSystem.Colors.warmCoral
                )
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
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
    
    private func loadAnalyticsData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Load health insights and patterns
                // This would integrate with the analytics service
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                
                // Mock data for now
                let mockInsights = HealthInsights(
                    petId: "mock-pet-id",
                    analysisDate: Date(),
                    weightManagementStatus: "stable",
                    nutritionalAdequacyScore: 85.0,
                    feedingConsistencyScore: 78.0,
                    healthRisks: ["Low fiber intake"],
                    positiveIndicators: ["Consistent feeding schedule", "Good weight stability"],
                    recommendations: [],
                    overallHealthScore: 82.0
                )
                
                let mockPatterns = NutritionalPatterns(
                    petId: "mock-pet-id",
                    analysisPeriod: "30_days",
                    feedingTimes: ["8:00 AM", "6:00 PM"],
                    preferredFoods: ["Chicken & Rice", "Salmon Formula"],
                    nutritionalGaps: ["Fiber intake could be improved"],
                    seasonalPatterns: [:],
                    behavioralInsights: ["Pet prefers morning feedings"],
                    optimizationSuggestions: ["Add more fiber-rich foods"]
                )
                
                await MainActor.run {
                    healthInsights = mockInsights
                    nutritionalPatterns = mockPatterns
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct HealthInsightsCard: View {
    let insights: HealthInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Health Insights")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            // Overall Health Score
            HStack {
                Text("Overall Health Score")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Spacer()
                
                Text("\(Int(insights.overallHealthScore))/100")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(healthScoreColor(insights.overallHealthScore))
            }
            
            // Health Risks
            if !insights.healthRisks.isEmpty {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Health Risks")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    
                    ForEach(insights.healthRisks, id: \.self) { risk in
                        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                            
                            Text(risk)
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            // Positive Indicators
            if !insights.positiveIndicators.isEmpty {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Positive Indicators")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    ForEach(insights.positiveIndicators, id: \.self) { indicator in
                        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.primary)
                            
                            Text(indicator)
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
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
    
    private func healthScoreColor(_ score: Double) -> Color {
        if score >= 80 {
            return ModernDesignSystem.Colors.primary
        } else if score >= 60 {
            return ModernDesignSystem.Colors.goldenYellow
        } else {
            return ModernDesignSystem.Colors.warmCoral
        }
    }
}

struct NutritionalPatternsCard: View {
    let patterns: NutritionalPatterns
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Nutritional Patterns")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            // Feeding Times
            if !patterns.feedingTimes.isEmpty {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Feeding Times")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    HStack {
                        ForEach(patterns.feedingTimes, id: \.self) { time in
                            Text(time)
                                .font(ModernDesignSystem.Typography.caption)
                                .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                                .padding(.vertical, ModernDesignSystem.Spacing.xs)
                                .background(ModernDesignSystem.Colors.primary.opacity(0.2))
                                .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        }
                    }
                }
            }
            
            // Preferred Foods
            if !patterns.preferredFoods.isEmpty {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Preferred Foods")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    LazyVStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        ForEach(patterns.preferredFoods, id: \.self) { food in
                            Text("• \(food)")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        }
                    }
                }
            }
            
            // Optimization Suggestions
            if !patterns.optimizationSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Optimization Suggestions")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    LazyVStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        ForEach(patterns.optimizationSuggestions, id: \.self) { suggestion in
                            HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                                Image(systemName: "lightbulb.fill")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                                
                                Text(suggestion)
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
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

struct AnalyticsSummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text(title)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            HStack(alignment: .bottom, spacing: ModernDesignSystem.Spacing.xs) {
                Text(value)
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "circle.fill")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(color)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
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

// MARK: - Data Models

struct HealthInsights {
    let petId: String
    let analysisDate: Date
    let weightManagementStatus: String
    let nutritionalAdequacyScore: Double
    let feedingConsistencyScore: Double
    let healthRisks: [String]
    let positiveIndicators: [String]
    let recommendations: [String]
    let overallHealthScore: Double
}

struct NutritionalPatterns {
    let petId: String
    let analysisPeriod: String
    let feedingTimes: [String]
    let preferredFoods: [String]
    let nutritionalGaps: [String]
    let seasonalPatterns: [String: Any]
    let behavioralInsights: [String]
    let optimizationSuggestions: [String]
}

// MARK: - Services

@MainActor
class AdvancedAnalyticsService: ObservableObject {
    static let shared = AdvancedAnalyticsService()
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {}
}

#Preview {
    AdvancedNutritionView()
        .environmentObject(AuthService.shared)
}
