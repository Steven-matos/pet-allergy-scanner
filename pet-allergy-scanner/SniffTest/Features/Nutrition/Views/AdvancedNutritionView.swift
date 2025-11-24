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
    @State private var petService = CachedPetService.shared
    @StateObject private var petSelectionService = NutritionPetSelectionService.shared
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    @StateObject private var cachedNutritionService = CachedNutritionService.shared
    @StateObject private var cachedWeightService = CachedWeightTrackingService.shared
    @StateObject private var gatekeeper = SubscriptionGatekeeper.shared
    @State private var selectedTab = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingWeightEntry = false
    @State private var showingGoalSetting = false
    @State private var showingPeriodSelector = false
    @State private var selectedPeriod: TrendPeriod = .thirtyDays
    @State private var showingPaywall = false
    
    private var selectedPet: Pet? {
        petSelectionService.selectedPet
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if gatekeeper.canAccessAnalytics() {
                    if isLoading {
                        ProgressView("Loading nutrition data...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let pet = selectedPet {
                        phase3Content(for: pet)
                    } else {
                        petSelectionView
                    }
                } else {
                    SubscriptionBlockerView(
                        featureName: "Advanced Nutrition Analytics",
                        featureDescription: "Get detailed nutrition analytics, weight tracking, and personalized insights for your pet's health.",
                        icon: "chart.bar.fill"
                    )
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
                        Button(action: {
                            showingPeriodSelector = true
                        }) {
                            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                Image(systemName: "calendar")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.primary)
                                
                                Text(selectedPeriod.displayName)
                                    .font(ModernDesignSystem.Typography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                
                                Image(systemName: "chevron.down")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                            .padding(.horizontal, ModernDesignSystem.Spacing.md)
                            .padding(.vertical, ModernDesignSystem.Spacing.sm)
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
        .sheet(isPresented: $showingPeriodSelector) {
            PeriodSelectionView(selectedPeriod: $selectedPeriod)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: Binding(
            get: { gatekeeper.showingUpgradePrompt && !showingPaywall },
            set: { gatekeeper.showingUpgradePrompt = $0 }
        )) {
            UpgradePromptView(
                title: gatekeeper.upgradePromptTitle,
                message: gatekeeper.upgradePromptMessage
            )
        }
        .onAppear {
            loadNutritionDataIfNeeded()
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
            // Pet Header with margin
            petHeaderSection(pet)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.top, ModernDesignSystem.Spacing.md)
                .padding(.bottom, ModernDesignSystem.Spacing.sm)
            
            // Tab Selection
            tabSelectionSection
            
            // Content based on selected tab
            TabView(selection: $selectedTab) {
                // Weight Management Tab
                WeightManagementView()
                    .environmentObject(authService)
                    .tag(0)
                
                // Nutritional Trends Tab
                NutritionalTrendsView(selectedPeriod: $selectedPeriod)
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
    
    /**
     * Load nutrition data only if needed (cache-first approach)
     * Checks for cached data before making server calls
     */
    private func loadNutritionDataIfNeeded() {
        // First, load pets and check for auto-selection
        Task {
            petService.loadPets()
            
            await MainActor.run {
                // Auto-select pet if user has only one pet
                autoSelectSinglePet()
            }
        }
        
        // If no pet is selected, don't proceed with nutrition data loading
        guard let pet = selectedPet else { return }
        
        // Check if we have cached data for this pet
        let hasCachedNutritionData = cachedNutritionService.hasCachedNutritionData(for: pet.id)
        let hasCachedWeightData = cachedWeightService.hasCachedWeightData(for: pet.id)
        
        if hasCachedNutritionData && hasCachedWeightData {
            // We have cached data, no need to make server calls
            print("✅ Using cached nutrition data for pet: \(pet.name)")
            return
        } else {
            // Missing some cached data, load from server
            print("⚠️ Missing cached data, loading from server for pet: \(pet.name)")
            loadNutritionData()
        }
    }
    
    /**
     * Load nutrition data using cache-first approach for optimal performance
     * Only makes API calls when cache is empty or data is stale
     */
    private func loadNutritionData() {
        // First, load pets and check for auto-selection
        Task {
            petService.loadPets()
            
            await MainActor.run {
                // Auto-select pet if user has only one pet
                autoSelectSinglePet()
            }
        }
        
        // If no pet is selected, don't proceed with nutrition data loading
        guard let pet = selectedPet else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Use cached services to load data efficiently
                // These services will check cache first before making API calls
                
                // Load nutritional requirements (cached)
                _ = try await cachedNutritionService.getNutritionalRequirements(for: pet.id)
                
                // Load weight data (cached)
                try await cachedWeightService.loadWeightData(for: pet.id)
                
                // Load feeding records (cached)
                try await cachedNutritionService.loadFeedingRecords(for: pet.id)
                
                // Load daily summaries (cached)
                try await cachedNutritionService.loadDailySummaries(for: pet.id)
                
                await MainActor.run {
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
                print("❌ Failed to load nutrition data: \(error)")
            }
        }
    }
    
    /**
     * Automatically select pet if user has only one pet
     * Follows KISS principle by providing simple auto-selection logic
     */
    private func autoSelectSinglePet() {
        // Only auto-select if no pet is currently selected and user has exactly one pet
        guard petSelectionService.selectedPet == nil,
              petService.pets.count == 1,
              let singlePet = petService.pets.first else {
            return
        }
        
        print("🔍 AdvancedNutritionView: Auto-selecting single pet: \(singlePet.name)")
        petSelectionService.selectPet(singlePet)
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
    @StateObject private var cachedNutritionService = CachedNutritionService.shared
    @StateObject private var cachedWeightService = CachedWeightTrackingService.shared
    @StateObject private var petSelectionService = NutritionPetSelectionService.shared
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
        .refreshable {
            await loadAnalyticsDataAsync()
        }
        .onAppear {
            loadAnalyticsData()
        }
    }
    
    /**
     * Async version of loadAnalyticsData for refreshable support
     */
    private func loadAnalyticsDataAsync() async {
        guard let pet = petSelectionService.selectedPet else { return }
        
        isLoading = true
        errorMessage = nil
        
        let petId = pet.id
        
        do {
            async let insightsTask = analyticsService.fetchHealthInsights(petId: petId)
            async let patternsTask = analyticsService.fetchNutritionalPatterns(petId: petId)
            
            let insights = try await insightsTask
            let patterns = try await patternsTask
            
            await MainActor.run {
                self.healthInsights = insights
                self.nutritionalPatterns = patterns
                self.isLoading = false
                self.errorMessage = nil
            }
        } catch {
            // Silently fall back to cached data - not showing error message
            // since cached data is still useful and valid
            await MainActor.run {
                self.isLoading = false
            }
            
            // Load fallback data in background
            await loadFallbackData(petId: petId)
        }
    }
    
    /**
     * Load fallback analytics data from cached services
     * Used when API calls fail - provides local calculations as backup
     */
    private func loadFallbackData(petId: String) async {
        await MainActor.run {
            // Use cached data as fallback
            let weightTrend = cachedWeightService.analyzeWeightTrend(for: petId)
            let recommendations = cachedWeightService.recommendations(for: petId)
            let feedingRecords = cachedNutritionService.feedingRecords.filter { $0.petId == petId }
            let dailySummaries = cachedNutritionService.dailySummaries[petId] ?? []
            
            // Convert recommendations to API format
            let recommendationObjects = recommendations.map { rec in
                NutritionalRecommendation(
                    id: UUID().uuidString,
                    petId: petId,
                    recommendationType: "general",
                    title: rec,
                    description: rec,
                    priority: "medium",
                    category: "diet",
                    isActive: true,
                    generatedAt: Date()
                )
            }
            
            // Create fallback insights using simple initializer
            let fallbackInsights = HealthInsights(
                petId: petId,
                analysisDate: Date(),
                weightManagementStatus: trendDirectionString(weightTrend.trendDirection),
                nutritionalAdequacyScore: calculateNutritionalScore(dailySummaries: dailySummaries),
                feedingConsistencyScore: calculateConsistencyScore(feedingRecords: feedingRecords),
                healthRisks: generateHealthRisks(
                    weightTrend: weightTrend,
                    dailySummaries: dailySummaries,
                    recommendations: recommendations
                ),
                positiveIndicators: generatePositiveIndicators(
                    weightTrend: weightTrend,
                    dailySummaries: dailySummaries
                ),
                recommendations: recommendationObjects,
                overallHealthScore: calculateHealthScore(
                    weightTrend: weightTrend,
                    feedingRecords: feedingRecords,
                    dailySummaries: dailySummaries
                )
            )
            
            let fallbackPatterns = NutritionalPatterns(
                petId: petId,
                analysisPeriod: "30_days",
                feedingTimes: extractFeedingTimes(feedingRecords: feedingRecords),
                preferredFoods: extractPreferredFoods(feedingRecords: feedingRecords),
                nutritionalGaps: generateHealthRisks(
                    weightTrend: weightTrend,
                    dailySummaries: dailySummaries,
                    recommendations: recommendations
                ),
                seasonalPatterns: [:],
                behavioralInsights: generateBehavioralInsights(feedingRecords: feedingRecords),
                optimizationSuggestions: recommendations
            )
            
            self.healthInsights = fallbackInsights
            self.nutritionalPatterns = fallbackPatterns
            self.isLoading = false
            self.errorMessage = nil
        }
    }
    
    private var analyticsSummarySection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
            // Section Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                
                Text("Analytics Summary")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            // Summary Cards Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ModernDesignSystem.Spacing.md) {
                // Health Score Card
                AnalyticsSummaryCard(
                    title: "Health Score",
                    value: healthInsights?.overallHealthScore ?? 0,
                    unit: "/100",
                    icon: "heart.fill",
                    color: healthScoreColor(healthInsights?.overallHealthScore ?? 0)
                )
                
                // Nutritional Balance Card
                AnalyticsSummaryCard(
                    title: "Nutritional Balance",
                    value: healthInsights?.nutritionalAdequacyScore ?? 0,
                    unit: "%",
                    icon: "leaf.fill",
                    color: scoreColor(healthInsights?.nutritionalAdequacyScore ?? 0)
                )
                
                // Feeding Consistency Card
                AnalyticsSummaryCard(
                    title: "Feeding Consistency",
                    value: healthInsights?.feedingConsistencyScore ?? 0,
                    unit: "%",
                    icon: "clock.fill",
                    color: scoreColor(healthInsights?.feedingConsistencyScore ?? 0)
                )
                
                // Weight Management Card
                AnalyticsSummaryCard(
                    title: "Weight Status",
                    value: healthInsights?.weightManagementStatus.capitalized ?? "Unknown",
                    unit: "",
                    icon: "scalemass.fill",
                    color: weightStatusColor(healthInsights?.weightManagementStatus)
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
    
    /**
     * Get color for health score based on value
     * Following Trust & Nature design system guidelines
     */
    private func healthScoreColor(_ score: Double) -> Color {
        if score >= 80 {
            return ModernDesignSystem.Colors.primary // Deep Forest Green - Excellent
        } else if score >= 60 {
            return ModernDesignSystem.Colors.goldenYellow // Golden Yellow - Good
        } else {
            return ModernDesignSystem.Colors.warmCoral // Warm Coral - Needs Attention
        }
    }
    
    /**
     * Get color for percentage-based scores
     */
    private func scoreColor(_ score: Double) -> Color {
        if score >= 80 {
            return ModernDesignSystem.Colors.primary
        } else if score >= 60 {
            return ModernDesignSystem.Colors.goldenYellow
        } else {
            return ModernDesignSystem.Colors.warmCoral
        }
    }
    
    /**
     * Get color for weight status
     */
    private func weightStatusColor(_ status: String?) -> Color {
        guard let status = status?.lowercased() else {
            return ModernDesignSystem.Colors.textSecondary
        }
        
        switch status {
        case "stable":
            return ModernDesignSystem.Colors.primary
        case "increasing", "decreasing":
            return ModernDesignSystem.Colors.goldenYellow
        default:
            return ModernDesignSystem.Colors.textSecondary
        }
    }
    
    /**
     * Load analytics data from backend API
     * Fetches real-time health insights and nutritional patterns
     */
    private func loadAnalyticsData() {
        guard let pet = petSelectionService.selectedPet else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            let petId = pet.id
            
            do {
                // Fetch data from API in parallel for better performance
                async let insightsTask = analyticsService.fetchHealthInsights(petId: petId)
                async let patternsTask = analyticsService.fetchNutritionalPatterns(petId: petId)
                
                // Wait for both API calls to complete
                let insights = try await insightsTask
                let patterns = try await patternsTask
                
                await MainActor.run {
                    self.healthInsights = insights
                    self.nutritionalPatterns = patterns
                    self.isLoading = false
                    self.errorMessage = nil
                }
            } catch {
                // Silently fall back to cached data - not showing error message
                // since cached data is still useful and valid
                await loadFallbackData(petId: petId)
            }
        }
    }
    
    // MARK: - Analytics Calculation Methods
    
    /**
     * Calculate overall health score from cached data
     */
    private func calculateHealthScore(
        weightTrend: WeightTrendAnalysis,
        feedingRecords: [FeedingRecord],
        dailySummaries: [DailyNutritionSummary]
    ) -> Double {
        var score = 70.0 // Base score
        
        // Weight management score
        switch weightTrend.trendDirection {
        case .stable:
            score += 20
        case .increasing, .decreasing:
            score += 10
        }
        
        // Feeding consistency score
        if feedingRecords.count >= 14 { // 2 weeks of data
            score += 10
        }
        
        // Nutritional adequacy score
        let avgCompatibility = dailySummaries.map { $0.averageCompatibility }.reduce(0, +) / Double(max(dailySummaries.count, 1))
        score += avgCompatibility * 0.1
        
        return min(100.0, score)
    }
    
    /**
     * Calculate nutritional adequacy score from daily summaries
     */
    private func calculateNutritionalScore(dailySummaries: [DailyNutritionSummary]) -> Double {
        guard !dailySummaries.isEmpty else { return 0.0 }
        
        let avgCompatibility = dailySummaries.map { $0.averageCompatibility }.reduce(0, +) / Double(dailySummaries.count)
        return avgCompatibility
    }
    
    /**
     * Calculate feeding consistency score
     */
    private func calculateConsistencyScore(feedingRecords: [FeedingRecord]) -> Double {
        guard feedingRecords.count >= 7 else { return 0.0 }
        
        // Simple consistency calculation based on feeding frequency
        let daysWithFeedings = Set(feedingRecords.map { Calendar.current.startOfDay(for: $0.feedingTime) }).count
        let totalDays = 7 // Last week
        let consistency = Double(daysWithFeedings) / Double(totalDays)
        
        return consistency * 100
    }
    
    /**
     * Generate health risks from cached data
     */
    private func generateHealthRisks(
        weightTrend: WeightTrendAnalysis,
        dailySummaries: [DailyNutritionSummary],
        recommendations: [String]
    ) -> [String] {
        var risks: [String] = []
        
        if weightTrend.trendStrength == .strong && weightTrend.trendDirection == .increasing {
            risks.append("Rapid weight gain detected")
        }
        
        if weightTrend.trendStrength == .strong && weightTrend.trendDirection == .decreasing {
            risks.append("Significant weight loss detected")
        }
        
        let avgCompatibility = dailySummaries.map { $0.averageCompatibility }.reduce(0, +) / Double(max(dailySummaries.count, 1))
        if avgCompatibility < 70 {
            risks.append("Low nutritional compatibility")
        }
        
        return risks
    }
    
    /**
     * Generate positive indicators from cached data
     */
    private func generatePositiveIndicators(
        weightTrend: WeightTrendAnalysis,
        dailySummaries: [DailyNutritionSummary]
    ) -> [String] {
        var indicators: [String] = []
        
        if weightTrend.trendDirection == .stable {
            indicators.append("Stable weight management")
        }
        
        let avgCompatibility = dailySummaries.map { $0.averageCompatibility }.reduce(0, +) / Double(max(dailySummaries.count, 1))
        if avgCompatibility > 80 {
            indicators.append("Good nutritional compatibility")
        }
        
        if dailySummaries.count >= 7 {
            indicators.append("Consistent feeding tracking")
        }
        
        return indicators
    }
    
    /**
     * Extract feeding times from feeding records
     */
    private func extractFeedingTimes(feedingRecords: [FeedingRecord]) -> [String] {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let times = feedingRecords.map { formatter.string(from: $0.feedingTime) }
        let uniqueTimes = Array(Set(times)).sorted()
        
        return Array(uniqueTimes.prefix(3)) // Top 3 most common times
    }
    
    /**
     * Extract preferred foods from feeding records
     * Analyzes actual feeding data to determine most frequently fed foods
     */
    private func extractPreferredFoods(feedingRecords: [FeedingRecord]) -> [String] {
        guard !feedingRecords.isEmpty else { return [] }
        
        // Count food occurrences by food analysis ID
        var foodCounts: [String: Int] = [:]
        for record in feedingRecords {
            let foodAnalysisId = record.foodAnalysisId
            foodCounts[foodAnalysisId, default: 0] += 1
        }
        
        // Sort by frequency and get top 3
        let topFoods = foodCounts.sorted { $0.value > $1.value }.prefix(3)
        
        // Try to get food names from cached service
        var preferredFoods: [String] = []
        for (foodAnalysisId, _) in topFoods {
            // Look up food name in cached service if available
            if let foodAnalysis = cachedNutritionService.foodAnalyses.first(where: { $0.id == foodAnalysisId }) {
                preferredFoods.append(foodAnalysis.foodName)
            } else {
                // Fallback to food analysis ID if name not available
                preferredFoods.append("Food \(foodAnalysisId.prefix(8))")
            }
        }
        
        // Return empty array if no foods found, letting the view handle the empty state
        return preferredFoods.isEmpty ? [] : preferredFoods
    }
    
    /**
     * Generate behavioral insights from feeding records
     */
    private func generateBehavioralInsights(feedingRecords: [FeedingRecord]) -> [String] {
        var insights: [String] = []
        
        if feedingRecords.count >= 14 {
            insights.append("Consistent feeding schedule maintained")
        }
        
        // Analyze feeding times
        let morningFeedings = feedingRecords.filter { 
            Calendar.current.component(.hour, from: $0.feedingTime) < 12 
        }.count
        
        let eveningFeedings = feedingRecords.filter { 
            Calendar.current.component(.hour, from: $0.feedingTime) >= 12 
        }.count
        
        if morningFeedings > eveningFeedings {
            insights.append("Prefers morning feedings")
        } else if eveningFeedings > morningFeedings {
            insights.append("Prefers evening feedings")
        }
        
        return insights
    }
    
    /**
     * Convert TrendDirection to string representation
     */
    private func trendDirectionString(_ direction: TrendDirection) -> String {
        switch direction {
        case .increasing:
            return "increasing"
        case .decreasing:
            return "decreasing"
        case .stable:
            return "stable"
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
            
            // Recommendations
            if !insights.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Recommendations")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    ForEach(insights.recommendations, id: \.id) { recommendation in
                        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                            Image(systemName: "lightbulb.fill")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                // Only show title and description if they're different
                                if recommendation.title == recommendation.description {
                                    // Same text - only show once as description
                                    Text(recommendation.description)
                                        .font(ModernDesignSystem.Typography.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                } else {
                                    // Different text - show both with hierarchy
                                    Text(recommendation.title)
                                        .font(ModernDesignSystem.Typography.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                    
                                    Text(recommendation.description)
                                        .font(ModernDesignSystem.Typography.caption2)
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                }
                            }
                            
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

/**
 * Enhanced Analytics Summary Card
 * Displays metrics with icons, progress indicators, and visual hierarchy
 * Follows Trust & Nature design system principles
 */
struct AnalyticsSummaryCard: View {
    let title: String
    let value: Any
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Icon and Title Row
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(color)
                    .frame(width: 20, height: 20)
                
                Text(title)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                
                Spacer()
            }
            
            // Value Display
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: ModernDesignSystem.Spacing.xs) {
                    if let numericValue = value as? Double {
                        // Display numeric value with unit
                        Text("\(Int(numericValue))")
                            .font(ModernDesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        if !unit.isEmpty {
                            Text(unit)
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .baselineOffset(4)
                        }
                        
                        Spacer()
                    } else if let stringValue = value as? String {
                        // Display string value (for weight status)
                        Text(stringValue)
                            .font(ModernDesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                        
                        Spacer()
                        
                        // Status indicator circle
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .fill(color)
                                    .frame(width: 6, height: 6)
                            )
                    }
                }
                
                // Progress bar for numeric values
                if let numericValue = value as? Double, numericValue >= 0 && numericValue <= 100 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color.opacity(0.2))
                                .frame(height: 4)
                            
                            // Progress fill
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(
                                    width: geometry.size.width * CGFloat(numericValue / 100),
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 100, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
}

// MARK: - Data Models

/**
 * Health Insights model matching backend API response
 * Decodes JSON from /api/v1/advanced-nutrition/analytics/health-insights/{pet_id}
 */
struct HealthInsights: Codable {
    let petId: String
    let analysisDate: Date
    let weightManagementStatus: String
    let nutritionalAdequacyScore: Double
    let feedingConsistencyScore: Double
    let healthRisks: [String]
    let positiveIndicators: [String]
    let recommendations: [NutritionalRecommendation]
    let overallHealthScore: Double
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case analysisDate = "analysis_date"
        case weightManagementStatus = "weight_management_status"
        case nutritionalAdequacyScore = "nutritional_adequacy_score"
        case feedingConsistencyScore = "feeding_consistency_score"
        case healthRisks = "health_risks"
        case positiveIndicators = "positive_indicators"
        case recommendations
        case overallHealthScore = "overall_health_score"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        petId = try container.decode(String.self, forKey: .petId)
        
        // Parse analysis date
        let dateString = try container.decode(String.self, forKey: .analysisDate)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let date = dateFormatter.date(from: dateString) {
            analysisDate = date
        } else {
            // Fallback to current date if parsing fails
            analysisDate = Date()
        }
        
        weightManagementStatus = try container.decode(String.self, forKey: .weightManagementStatus)
        nutritionalAdequacyScore = try container.decode(Double.self, forKey: .nutritionalAdequacyScore)
        feedingConsistencyScore = try container.decode(Double.self, forKey: .feedingConsistencyScore)
        healthRisks = try container.decode([String].self, forKey: .healthRisks)
        positiveIndicators = try container.decode([String].self, forKey: .positiveIndicators)
        recommendations = try container.decode([NutritionalRecommendation].self, forKey: .recommendations)
        overallHealthScore = try container.decode(Double.self, forKey: .overallHealthScore)
    }
    
    /**
     * Simple initializer for creating HealthInsights from calculated data
     * Used for fallback scenarios when API is unavailable
     */
    init(
        petId: String,
        analysisDate: Date,
        weightManagementStatus: String,
        nutritionalAdequacyScore: Double,
        feedingConsistencyScore: Double,
        healthRisks: [String],
        positiveIndicators: [String],
        recommendations: [NutritionalRecommendation],
        overallHealthScore: Double
    ) {
        self.petId = petId
        self.analysisDate = analysisDate
        self.weightManagementStatus = weightManagementStatus
        self.nutritionalAdequacyScore = nutritionalAdequacyScore
        self.feedingConsistencyScore = feedingConsistencyScore
        self.healthRisks = healthRisks
        self.positiveIndicators = positiveIndicators
        self.recommendations = recommendations
        self.overallHealthScore = overallHealthScore
    }
}

/**
 * Nutritional Recommendation model matching backend API
 */
struct NutritionalRecommendation: Codable {
    let id: String
    let petId: String
    let recommendationType: String
    let title: String
    let description: String
    let priority: String
    let category: String
    let isActive: Bool
    let generatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case petId = "pet_id"
        case recommendationType = "recommendation_type"
        case title
        case description
        case priority
        case category
        case isActive = "is_active"
        case generatedAt = "generated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        petId = try container.decode(String.self, forKey: .petId)
        recommendationType = try container.decode(String.self, forKey: .recommendationType)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        priority = try container.decode(String.self, forKey: .priority)
        category = try container.decode(String.self, forKey: .category)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        
        // Parse generated date
        let dateString = try container.decode(String.self, forKey: .generatedAt)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = dateFormatter.date(from: dateString) {
            generatedAt = date
        } else {
            // Fallback parsing without fractional seconds
            dateFormatter.formatOptions = [.withInternetDateTime]
            if let date = dateFormatter.date(from: dateString) {
                generatedAt = date
            } else {
                generatedAt = Date()
            }
        }
    }
    
    /**
     * Simple initializer for creating NutritionalRecommendation from data
     * Used for fallback scenarios when API is unavailable
     */
    init(
        id: String,
        petId: String,
        recommendationType: String,
        title: String,
        description: String,
        priority: String,
        category: String,
        isActive: Bool,
        generatedAt: Date
    ) {
        self.id = id
        self.petId = petId
        self.recommendationType = recommendationType
        self.title = title
        self.description = description
        self.priority = priority
        self.category = category
        self.isActive = isActive
        self.generatedAt = generatedAt
    }
}

/**
 * Nutritional Patterns model matching backend API response
 * Decodes JSON from /api/v1/advanced-nutrition/analytics/patterns/{pet_id}
 */
struct NutritionalPatterns: Codable {
    let petId: String
    let analysisPeriod: String
    let feedingTimes: [String]
    let preferredFoods: [String]
    let nutritionalGaps: [String]
    let seasonalPatterns: [String: String]
    let behavioralInsights: [String]
    let optimizationSuggestions: [String]
    
    enum CodingKeys: String, CodingKey {
        case petId = "pet_id"
        case analysisPeriod = "analysis_period"
        case feedingTimes = "feeding_times"
        case preferredFoods = "preferred_foods"
        case nutritionalGaps = "nutritional_gaps"
        case seasonalPatterns = "seasonal_patterns"
        case behavioralInsights = "behavioral_insights"
        case optimizationSuggestions = "optimization_suggestions"
    }
}

// MARK: - Services

/**
 * Advanced Analytics Service
 * Handles API calls for health insights and nutritional patterns
 * Follows SOLID principles with single responsibility for analytics API calls
 */
@MainActor
class AdvancedAnalyticsService: ObservableObject {
    static let shared = AdvancedAnalyticsService()
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService = APIService.shared
    
    private init() {}
    
    /**
     * Fetch health insights for a pet from the backend API
     * - Parameter petId: The pet ID to fetch insights for
     * - Returns: HealthInsights object with comprehensive health data
     * - Throws: APIError if the request fails
     */
    func fetchHealthInsights(petId: String) async throws -> HealthInsights {
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let endpoint = "/api/v1/advanced-nutrition/analytics/health-insights/\(petId)"
            let insights = try await apiService.get(
                endpoint: endpoint,
                responseType: HealthInsights.self
            )
            return insights
        } catch {
            self.error = error
            throw error
        }
    }
    
    /**
     * Fetch nutritional patterns for a pet from the backend API
     * - Parameter petId: The pet ID to fetch patterns for
     * - Returns: NutritionalPatterns object with pattern analysis
     * - Throws: APIError if the request fails
     */
    func fetchNutritionalPatterns(petId: String) async throws -> NutritionalPatterns {
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let endpoint = "/api/v1/advanced-nutrition/analytics/patterns/\(petId)"
            let patterns = try await apiService.get(
                endpoint: endpoint,
                responseType: NutritionalPatterns.self
            )
            return patterns
        } catch {
            self.error = error
            throw error
        }
    }
}

#Preview {
    AdvancedNutritionView()
        .environmentObject(AuthService.shared)
}
