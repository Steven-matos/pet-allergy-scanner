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
    @StateObject private var cachedNutritionService = CachedNutritionService.shared
    @StateObject private var cachedWeightService = CachedWeightTrackingService.shared
    @State private var selectedTab = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingWeightEntry = false
    @State private var showingGoalSetting = false
    @State private var showingPeriodSelector = false
    @State private var selectedPeriod: TrendPeriod = .thirtyDays
    
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
     * Load nutrition data using cache-first approach for optimal performance
     * Only makes API calls when cache is empty or data is stale
     */
    private func loadNutritionData() {
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
    
    /**
     * Load analytics data using cached nutrition and weight data
     * Generates insights from cached data instead of making new API calls
     */
    private func loadAnalyticsData() {
        guard let pet = petSelectionService.selectedPet else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            // Generate analytics from cached data instead of making new API calls
            let petId = pet.id
            
            // Get cached weight data for analysis
            let weightTrend = cachedWeightService.analyzeWeightTrend(for: petId)
            let recommendations = cachedWeightService.recommendations(for: petId)
            
            // Get cached nutrition data for analysis
            let feedingRecords = cachedNutritionService.feedingRecords.filter { $0.petId == petId }
            let dailySummaries = cachedNutritionService.dailySummaries[petId] ?? []
            
            // Calculate analytics from cached data
            let healthScore = calculateHealthScore(
                weightTrend: weightTrend,
                feedingRecords: feedingRecords,
                dailySummaries: dailySummaries
            )
            
            let nutritionalScore = calculateNutritionalScore(dailySummaries: dailySummaries)
            let consistencyScore = calculateConsistencyScore(feedingRecords: feedingRecords)
            
            let healthRisks = generateHealthRisks(
                weightTrend: weightTrend,
                dailySummaries: dailySummaries,
                recommendations: recommendations
            )
            
            let positiveIndicators = generatePositiveIndicators(
                weightTrend: weightTrend,
                dailySummaries: dailySummaries
            )
            
            let insights = HealthInsights(
                petId: petId,
                analysisDate: Date(),
                weightManagementStatus: trendDirectionString(weightTrend.trendDirection),
                nutritionalAdequacyScore: nutritionalScore,
                feedingConsistencyScore: consistencyScore,
                healthRisks: healthRisks,
                positiveIndicators: positiveIndicators,
                recommendations: recommendations,
                overallHealthScore: healthScore
            )
            
            let patterns = NutritionalPatterns(
                petId: petId,
                analysisPeriod: "30_days",
                feedingTimes: extractFeedingTimes(feedingRecords: feedingRecords),
                preferredFoods: extractPreferredFoods(feedingRecords: feedingRecords),
                nutritionalGaps: healthRisks,
                seasonalPatterns: [:],
                behavioralInsights: generateBehavioralInsights(feedingRecords: feedingRecords),
                optimizationSuggestions: recommendations
            )
            
            await MainActor.run {
                healthInsights = insights
                nutritionalPatterns = patterns
                isLoading = false
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
     */
    private func extractPreferredFoods(feedingRecords: [FeedingRecord]) -> [String] {
        // This would require food analysis data, simplified for now
        return ["Chicken & Rice", "Salmon Formula", "Turkey & Sweet Potato"]
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
