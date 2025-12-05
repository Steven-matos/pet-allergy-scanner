//
//  NutritionalTrendsView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import Charts

/**
 * Nutritional Trends View
 * 
 * Comprehensive nutritional trend analysis and visualization with support for:
 * - Calorie and macronutrient trends
 * - Feeding pattern analysis
 * - Weight correlation insights
 * - Historical data visualization
 * - Trend predictions and recommendations
 * 
 * Follows SOLID principles with single responsibility for trend visualization
 * Implements DRY by reusing common chart components
 * Follows KISS by keeping the interface intuitive and data-focused
 */
struct NutritionalTrendsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var trendsService = CachedNutritionalTrendsService.shared
    @State private var petService = CachedPetService.shared
    @StateObject private var petSelectionService = NutritionPetSelectionService.shared
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    @StateObject private var calorieGoalsService = CalorieGoalsService.shared
    @StateObject private var gatekeeper = SubscriptionGatekeeper.shared
    @StateObject private var feedingLogService = FeedingLogService.shared
    @Binding var selectedPeriod: TrendPeriod
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPeriodSelector = false
    @State private var showingFeedingLog = false
    @State private var showingCalorieGoalSheet: Pet?
    @State private var showingPaywall = false
    @State private var recentMeals: [FeedingRecord] = []
    
    private var selectedPet: Pet? {
        petSelectionService.selectedPet
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if gatekeeper.canAccessTrends() {
            if isLoading {
                ModernLoadingView(message: "Loading trends...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let pet = selectedPet {
                trendsContent(for: pet)
            } else {
                petSelectionView
                }
            } else {
                SubscriptionBlockerView(
                    featureName: "Nutritional Trends",
                    featureDescription: "Track your pet's nutrition over time with detailed analytics, calorie trends, and feeding pattern insights.",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .background(ModernDesignSystem.Colors.background)
        .sheet(isPresented: $showingPeriodSelector) {
            PeriodSelectionView(selectedPeriod: $selectedPeriod)
        }
        .sheet(isPresented: $showingFeedingLog) {
            FeedingLogView()
                .onDisappear {
                    // Refresh trends data when the feeding log sheet is dismissed (force refresh to get latest data)
                    loadTrendsData()
                    loadRecentMeals(forceRefresh: true)
                }
        }
        .sheet(item: $showingCalorieGoalSheet) { pet in
            CalorieGoalEntrySheet(pet: pet) {
                showingCalorieGoalSheet = nil
                // Reload goals after setting
                Task {
                    try? await calorieGoalsService.loadGoals()
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $gatekeeper.showingUpgradePrompt) {
            UpgradePromptView(
                title: gatekeeper.upgradePromptTitle,
                message: gatekeeper.upgradePromptMessage
            )
        }
        .onAppear {
            // Load pets synchronously from cache first (immediate UI rendering)
            petService.loadPets()
            
            // Set default selected pet if needed (use petSelectionService)
            if let user = authService.currentUser,
               user.role == .premium,
               !petService.pets.isEmpty,
               selectedPet == nil {
                petSelectionService.selectPet(petService.pets.first!)
            }
            
            // Load trends data with cache-first pattern
            loadTrendsDataIfNeeded()
            loadCalorieGoalsIfNeeded()
            loadRecentMeals()
        }
        .onChange(of: showingFeedingLog) { _, isShowing in
            if !isShowing {
                // Refresh trends and meals when feeding log is dismissed (force refresh to get latest data)
                loadTrendsData()
                loadRecentMeals(forceRefresh: true)
            }
        }
    }
    
    // MARK: - Pet Selection View
    
    private var petSelectionView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Select a Pet")
                .font(ModernDesignSystem.Typography.title2)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text("Choose a pet to view nutritional trends")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            if !petService.pets.isEmpty {
                LazyVStack(spacing: ModernDesignSystem.Spacing.md) {
                    ForEach(petService.pets) { pet in
                        NutritionalTrendsPetSelectionCard(pet: pet) {
                            petSelectionService.selectPet(pet)
                            loadTrendsData()
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
    
    // MARK: - Trends Content
    
    @ViewBuilder
    private func trendsContent(for pet: Pet) -> some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Summary Cards
                summaryCardsSection(for: pet)
                
                // Log Meal Section - Button and Recent Meals List
                logMealSection
                
                // Calorie Trends Chart
                if !trendsService.calorieTrends(for: pet.id).isEmpty {
                    CalorieTrendsChart(
                        trends: trendsService.calorieTrends(for: pet.id),
                        petName: pet.name
                    )
                }
                
                // Macronutrient Trends Chart
                if !trendsService.macronutrientTrends(for: pet.id).isEmpty {
                    MacronutrientTrendsChart(
                        trends: trendsService.macronutrientTrends(for: pet.id),
                        petName: pet.name
                    )
                }
                
                // Feeding Patterns Chart
                if !trendsService.feedingPatterns(for: pet.id).isEmpty {
                    FeedingPatternsChart(
                        patterns: trendsService.feedingPatterns(for: pet.id),
                        petName: pet.name
                    )
                }
                
                // Weight Correlation
                if let correlation = trendsService.weightCorrelation(for: pet.id) {
                    WeightCorrelationCard(correlation: correlation)
                }
                
                // Insights and Recommendations
                if !trendsService.insights(for: pet.id).isEmpty {
                    InsightsCard(insights: trendsService.insights(for: pet.id))
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        .background(ModernDesignSystem.Colors.background)
        .refreshable {
            await loadTrendsDataAsync()
        }
    }
    
    // MARK: - Summary Cards Section
    
    @ViewBuilder
    private func summaryCardsSection(for pet: Pet) -> some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Calorie Goal Card (Full Width)
            CalorieGoalCard(
                pet: pet,
                onTap: {
                    showingCalorieGoalSheet = pet
                }
            )
            
            // Other Summary Cards (2 Column Grid)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ModernDesignSystem.Spacing.md) {
                // Average Daily Calories
                SummaryCard(
                    title: "Avg Daily Calories",
                    value: "\(Int(trendsService.averageDailyCalories(for: pet.id)))",
                    unit: "kcal",
                    trend: trendsService.calorieTrend(for: pet.id),
                    color: ModernDesignSystem.Colors.goldenYellow
                )
                
                // Feeding Frequency
                SummaryCard(
                    title: "Feeding Frequency",
                    value: "\(String(format: "%.1f", trendsService.averageFeedingFrequency(for: pet.id)))",
                    unit: "times/day",
                    trend: trendsService.feedingTrend(for: pet.id),
                    color: ModernDesignSystem.Colors.primary
                )
                
                // Nutritional Balance
                SummaryCard(
                    title: "Nutritional Balance",
                    value: "\(Int(trendsService.nutritionalBalanceScore(for: pet.id)))",
                    unit: "%",
                    trend: trendsService.balanceTrend(for: pet.id),
                    color: ModernDesignSystem.Colors.primary
                )
                
                // Weight Change
                SummaryCard(
                    title: "Weight Change",
                    value: "\(String(format: "%.1f", trendsService.totalWeightChange(for: pet.id)))",
                    unit: unitService.getUnitSymbol(),
                    trend: trendsService.weightChangeTrend(for: pet.id),
                    color: ModernDesignSystem.Colors.warmCoral
                )
            }
        }
    }
    
    // MARK: - Log Meal Section
    
    private var logMealSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title2)
                
                Text("Log Meal")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            // Log Meal Button
            Button(action: {
                showingFeedingLog = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                    
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Log New Meal")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                        
                        Text("Record what your pet ate")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textOnPrimary.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.buttonPrimary)
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Recent Meals List
            if !recentMeals.isEmpty {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Recent Meals")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .padding(.top, ModernDesignSystem.Spacing.xs)
                    
                    ForEach(recentMeals.prefix(5)) { meal in
                        MealRow(meal: meal, onDelete: {
                            // Force refresh the meals list after deletion (bypass cache)
                            loadRecentMeals(forceRefresh: true)
                            // Refresh trends after deletion
                            loadTrendsData()
                        })
                    }
                }
            } else {
                VStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Text("No meals logged yet")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .padding(.top, ModernDesignSystem.Spacing.xs)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
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
     * Load recent meals for the selected pet with cache-first pattern
     * - Parameter forceRefresh: If true, bypasses cache and fetches fresh data from server
     */
    private func loadRecentMeals(forceRefresh: Bool = false) {
        guard let pet = selectedPet ?? petService.pets.first else {
            recentMeals = []
            return
        }
        
        // Check cache synchronously first (immediate UI rendering)
        let cacheCoordinator = UnifiedCacheCoordinator.shared
        let cacheKey = CacheKey.feedingRecords.scoped(forPetId: pet.id)
        
        if !forceRefresh {
            // Try cache first (synchronous)
            if let cachedMeals = cacheCoordinator.get([FeedingRecord].self, forKey: cacheKey) {
                // Filter to last 7 days for display
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let recentCached = cachedMeals.filter { $0.feedingTime >= sevenDaysAgo }
                if !recentCached.isEmpty {
                    recentMeals = recentCached.sorted { $0.feedingTime > $1.feedingTime }
                    // Refresh in background to ensure we have latest data
                    Task {
                        await refreshRecentMealsInBackground(for: pet.id)
                    }
                    return
                } else if !cachedMeals.isEmpty {
                    // We have cached meals but they're older than 7 days - still show them
                    // This handles the case where user has meals but they're slightly older
                    recentMeals = cachedMeals.sorted { $0.feedingTime > $1.feedingTime }
                    // Refresh in background to get latest data
                    Task {
                        await refreshRecentMealsInBackground(for: pet.id)
                    }
                    return
                }
            }
        } else {
            // Force refresh - invalidate cache first
            cacheCoordinator.invalidate(forKey: cacheKey)
        }
        
        // Cache miss or force refresh - load from server
        Task {
            do {
                // Load all records (days parameter is handled client-side for filtering)
                let allMeals = try await feedingLogService.getFeedingRecords(for: pet.id, days: 30, forceRefresh: forceRefresh)
                
                // Filter to last 7 days for display
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                let recentMealsFiltered = allMeals.filter { $0.feedingTime >= sevenDaysAgo }
                
                await MainActor.run {
                    // If we have recent meals, show those; otherwise show all meals (even if older)
                    // This ensures user always sees their meals if they exist
                    if !recentMealsFiltered.isEmpty {
                        recentMeals = recentMealsFiltered.sorted { $0.feedingTime > $1.feedingTime }
                    } else if !allMeals.isEmpty {
                        // Show all meals even if older than 7 days (better UX)
                        recentMeals = allMeals.sorted { $0.feedingTime > $1.feedingTime }
                    } else {
                        recentMeals = []
                    }
                    
                    print("📊 Loaded \(recentMeals.count) meals for pet \(pet.id)")
                }
            } catch {
                // Handle errors gracefully
                if let apiError = error as? APIError,
                   case .serverError(let statusCode) = apiError {
                    if statusCode == 404 {
                        // Resource deleted - cache already invalidated by service
                        print("⚠️ Recent meals resource deleted (404) - cache invalidated")
                    } else {
                        print("❌ Failed to load recent meals: HTTP \(statusCode)")
                    }
                } else {
                    print("❌ Failed to load recent meals: \(error.localizedDescription)")
                }
                
                // On error, try to show cached data if available
                if let cachedMeals = cacheCoordinator.get([FeedingRecord].self, forKey: cacheKey), !cachedMeals.isEmpty {
                    await MainActor.run {
                        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                        let recentCached = cachedMeals.filter { $0.feedingTime >= sevenDaysAgo }
                        recentMeals = recentCached.isEmpty ? cachedMeals.sorted { $0.feedingTime > $1.feedingTime } : recentCached.sorted { $0.feedingTime > $1.feedingTime }
                        print("📊 Using cached meals (\(recentMeals.count)) due to error")
                    }
                }
            }
        }
    }
    
    /**
     * Refresh recent meals in background (silent refresh)
     */
    private func refreshRecentMealsInBackground(for petId: String) async {
        do {
            // Load all records and filter client-side
            let allMeals = try await feedingLogService.getFeedingRecords(for: petId, days: 30, forceRefresh: false)
            
            // Filter to last 7 days for display
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let recentMealsFiltered = allMeals.filter { $0.feedingTime >= sevenDaysAgo }
            
            await MainActor.run {
                // If we have recent meals, show those; otherwise show all meals
                if !recentMealsFiltered.isEmpty {
                    recentMeals = recentMealsFiltered.sorted { $0.feedingTime > $1.feedingTime }
                } else if !allMeals.isEmpty {
                    // Show all meals even if older than 7 days
                    recentMeals = allMeals.sorted { $0.feedingTime > $1.feedingTime }
                }
                print("📊 Background refresh: Loaded \(recentMeals.count) meals for pet \(petId)")
            }
        } catch {
            // Silent failure for background refresh
            print("⚠️ Background refresh of recent meals failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    /**
     * Load calorie goals for the selected pet
     * This ensures the calorie goal card displays the latest data
     */
    private func loadCalorieGoalsIfNeeded() {
        guard selectedPet != nil else { return }
        
        Task {
            do {
                try await calorieGoalsService.loadGoals()
            } catch {
                // Silently fail - goals may not be set yet
                print("Failed to load calorie goals: \(error.localizedDescription)")
            }
        }
    }
    
    /**
     * Load trends data with cache-first pattern
     * Checks cache synchronously first to avoid flashing
     * Only shows loading spinner if no cache exists
     */
    private func loadTrendsDataIfNeeded() {
        guard let pet = selectedPet ?? petService.pets.first else { return }
        
        // Check cache synchronously first (immediate UI rendering)
        let hasCachedData = trendsService.hasCachedTrendsData(for: pet.id)
        
        // Only show loading if we don't have cached data
        if !hasCachedData {
            isLoading = true
            // Load from server if no cache
            Task {
                await loadTrendsDataAsync(showLoadingIfNeeded: true, forceRefresh: false)
            }
        } else {
            // Cache exists - refresh in background silently (no loading spinner)
            Task {
                await loadTrendsDataAsync(showLoadingIfNeeded: false, forceRefresh: false)
            }
        }
    }
    
    /**
     * Force load trends data from server
     * Used when new data is added (feeding log, weight entry)
     */
    private func loadTrendsData() {
        guard selectedPet != nil else { return }
        
        Task {
            // Force refresh when data changes (after adding/deleting records)
            await loadTrendsDataAsync(showLoadingIfNeeded: true, forceRefresh: true)
        }
    }
    
    private func loadTrendsDataAsync(showLoadingIfNeeded: Bool = false, forceRefresh: Bool = false) async {
        guard let pet = selectedPet ?? petService.pets.first else { return }
        
        // Check if we already have data in memory (from cache or previous load) - synchronous check
        let hadDataBefore = trendsService.hasCachedTrendsData(for: pet.id)
        
        // Only show loading if explicitly requested and we don't have data
        if showLoadingIfNeeded && !hadDataBefore {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
        }
        
        do {
            // Load data - use forceRefresh when explicitly requested (after adding/deleting records)
            try await trendsService.loadTrendsData(for: pet.id, period: selectedPeriod, forceRefresh: forceRefresh)
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            // Handle 404 errors gracefully
            if let apiError = error as? APIError,
               case .serverError(let statusCode) = apiError,
               statusCode == 404 {
                // Resource deleted - cache already invalidated by service
                print("⚠️ Trends data resource deleted (404) - cache invalidated")
            }
            
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Supporting Views

struct CalorieGoalCard: View {
    let pet: Pet
    let onTap: () -> Void
    @StateObject private var calorieGoalsService = CalorieGoalsService.shared
    
    private var hasGoal: Bool {
        calorieGoalsService.getGoal(for: pet.id) != nil
    }
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                HStack {
                    Text("Daily Calorie Goal")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    // Show tap indicator
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Text(hasGoal ? "Tap to edit" : "Tap to set")
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        Image(systemName: "chevron.right")
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                    }
                }
                
                HStack(alignment: .bottom, spacing: ModernDesignSystem.Spacing.xs) {
                    if let goal = calorieGoalsService.getGoal(for: pet.id) {
                        Text("\(Int(goal))")
                            .font(ModernDesignSystem.Typography.title2)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text("kcal")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    } else {
                        Text("Not Set")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "target")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .background(ModernDesignSystem.Colors.softCream)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.primary, lineWidth: 1)
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

struct NutritionalTrendsPetSelectionCard: View {
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

struct SummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let trend: TrendDirection
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
                
                Text(unit)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Spacer()
                
                trendIcon
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
    
    @ViewBuilder
    private var trendIcon: some View {
        switch trend {
        case .increasing:
            Image(systemName: "arrow.up.right")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.primary)
        case .decreasing:
            Image(systemName: "arrow.down.right")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
        case .stable:
            Image(systemName: "minus")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
    }
}

struct CalorieTrendsChart: View {
    let trends: [CalorieTrend]
    let petName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Calorie Trends")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if #available(iOS 16.0, *) {
                Chart(trends) { trend in
                    LineMark(
                        x: .value("Date", trend.date),
                        y: .value("Calories", trend.calories)
                    )
                    .foregroundStyle(ModernDesignSystem.Colors.goldenYellow)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Date", trend.date),
                        y: .value("Calories", trend.calories)
                    )
                    .foregroundStyle(ModernDesignSystem.Colors.goldenYellow.opacity(0.2))
                    
                    if let target = trend.target {
                        RuleMark(y: .value("Target", target))
                            .foregroundStyle(ModernDesignSystem.Colors.primary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let calories = value.as(Double.self) {
                                Text("\(Int(calories)) kcal")
                            }
                        }
                    }
                }
            } else {
                // Fallback for iOS 15 and earlier
                Text("Calorie trends chart requires iOS 16+")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(height: 200)
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

struct MacronutrientTrendsChart: View {
    let trends: [MacronutrientTrend]
    let petName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Macronutrient Trends")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if #available(iOS 16.0, *) {
                Chart(trends) { trend in
                    LineMark(
                        x: .value("Date", trend.date),
                        y: .value("Protein", trend.protein)
                    )
                    .foregroundStyle(ModernDesignSystem.Colors.warmCoral)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    LineMark(
                        x: .value("Date", trend.date),
                        y: .value("Fat", trend.fat)
                    )
                    .foregroundStyle(ModernDesignSystem.Colors.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    LineMark(
                        x: .value("Date", trend.date),
                        y: .value("Fiber", trend.fiber)
                    )
                    .foregroundStyle(ModernDesignSystem.Colors.goldenYellow)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let grams = value.as(Double.self) {
                                Text("\(grams, specifier: "%.0f") g")
                            }
                        }
                    }
                }
                .chartLegend(position: .top)
            } else {
                // Fallback for iOS 15 and earlier
                Text("Macronutrient trends chart requires iOS 16+")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(height: 200)
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

struct FeedingPatternsChart: View {
    let patterns: [FeedingPattern]
    let petName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Feeding Patterns")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if #available(iOS 16.0, *) {
                Chart(patterns) { pattern in
                    BarMark(
                        x: .value("Date", pattern.date),
                        y: .value("Feedings", pattern.feedingCount)
                    )
                    .foregroundStyle(ModernDesignSystem.Colors.primary)
                    
                    LineMark(
                        x: .value("Date", pattern.date),
                        y: .value("Compatibility", pattern.compatibilityScore)
                    )
                    .foregroundStyle(ModernDesignSystem.Colors.goldenYellow)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let count = value.as(Int.self) {
                                Text("\(count)")
                            }
                        }
                    }
                }
            } else {
                // Fallback for iOS 15 and earlier
                Text("Feeding patterns chart requires iOS 16+")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(height: 200)
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

struct WeightCorrelationCard: View {
    let correlation: WeightCorrelation
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Weight Correlation")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            HStack {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Correlation Strength")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Text(correlation.strength.capitalized)
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(correlationColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Correlation")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Text("\(correlation.correlation, specifier: "%.2f")")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                }
            }
            
            Text(correlation.interpretation)
                .font(ModernDesignSystem.Typography.subheadline)
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
    
    private var correlationColor: Color {
        switch correlation.strength {
        case "strong":
            return ModernDesignSystem.Colors.primary
        case "moderate":
            return ModernDesignSystem.Colors.goldenYellow
        case "weak":
            return ModernDesignSystem.Colors.warmCoral
        default:
            return ModernDesignSystem.Colors.textSecondary
        }
    }
}

struct InsightsCard: View {
    let insights: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Insights")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            LazyVStack(spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                            .padding(.top, 2)
                        
                        Text(insight)
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Spacer()
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

struct PeriodSelectionView: View {
    @Binding var selectedPeriod: TrendPeriod
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(TrendPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        selectedPeriod = period
                        dismiss()
                    }) {
                        HStack {
                            Text(period.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedPeriod == period {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Calorie Goal Entry Sheet

/**
 * Calorie Goal Entry Sheet
 * 
 * Simple sheet interface for setting or updating a pet's daily calorie goal.
 * Pre-populates with existing goal or calculated default based on pet characteristics.
 * Follows Trust & Nature Design System with clean, intuitive UI.
 */
struct CalorieGoalEntrySheet: View {
    let pet: Pet
    let onDismiss: () -> Void
    
    @StateObject private var calorieGoalsService = CalorieGoalsService.shared
    @State private var calorieGoalText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var defaultGoal: Int = 0
    @State private var isLoadingDefault = true
    @Environment(\.dismiss) private var dismiss
    
    private var existingGoal: Double? {
        calorieGoalsService.getGoal(for: pet.id)
    }
    
    private var isUpdating: Bool {
        existingGoal != nil
    }
    
    private var canSave: Bool {
        guard let goal = Double(calorieGoalText),
              goal > 0 else {
            return false
        }
        return true
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // Pet Info Card
                    petInfoCard
                    
                    // Goal Input Card
                    goalInputCard
                    
                    // Default Goal Card (only show when no existing goal and default is loaded)
                    if !isUpdating && !isLoadingDefault {
                        suggestedGoalCard
                    }
                    
                    // Error Message
                    if let errorMessage = errorMessage {
                        errorCard(message: errorMessage)
                    }
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle(isUpdating ? "Update Calorie Goal" : "Set Calorie Goal")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Load default goal from database
                isLoadingDefault = true
                let calculatedDefault = await calorieGoalsService.calculateSuggestedGoal(for: pet)
                defaultGoal = Int(calculatedDefault)
                isLoadingDefault = false
                
                // Pre-populate with existing goal or default
                if let existing = existingGoal {
                    calorieGoalText = "\(Int(existing))"
                } else {
                    calorieGoalText = "\(defaultGoal)"
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                    .foregroundColor(Color.red.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(!canSave || isLoading)
                    .foregroundColor(canSave && !isLoading ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Pet Info Card
    
    private var petInfoCard: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            AsyncImage(url: URL(string: pet.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "pawprint.circle.fill")
                    .font(.title)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
            }
            .frame(width: 60, height: 60)
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
            }
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Goal Input Card
    
    private var goalInputCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Text("Daily Calorie Goal")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                // Show indicator if using standard vs saved goal
                if !isUpdating {
                    Text("Using Standard")
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, ModernDesignSystem.Spacing.xs)
                        .background(ModernDesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                } else {
                    Text("Saved Goal")
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, ModernDesignSystem.Spacing.xs)
                        .background(ModernDesignSystem.Colors.textSecondary.opacity(0.1))
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                }
            }
            
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                TextField("Enter calories", text: $calorieGoalText)
                    .keyboardType(.numberPad)
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .padding(ModernDesignSystem.Spacing.md)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                            .stroke(
                                canSave ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.borderPrimary,
                                lineWidth: canSave ? 2 : 1
                            )
                    )
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                
                Text("kcal/day")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Text("💡 Tip: Consult with your veterinarian to determine the appropriate daily calorie intake for your pet")
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
    
    // MARK: - Suggested Goal Card
    
    /**
     * Default Goal Card
     * Shows the standard calorie goal from nutritional_standards table
     * Only displayed when no saved goal exists (user is setting goal for first time)
     */
    private var suggestedGoalCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title3)
                
                Text("Standard Goal")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            Text("Based on nutritional standards for \(pet.species.rawValue.capitalized), \(pet.lifeStage.rawValue.capitalized) life stage, and activity level. You can customize this value and save it for your pet.")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            Button(action: {
                calorieGoalText = "\(defaultGoal)"
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Use Standard")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Text("\(defaultGoal) kcal/day")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.softCream)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(ModernDesignSystem.Colors.primary, lineWidth: 1)
                )
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            }
            .buttonStyle(PlainButtonStyle())
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
    
    // MARK: - Error Card
    
    @ViewBuilder
    private func errorCard(message: String) -> some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ModernDesignSystem.Colors.error)
            
            Text(message)
                .font(ModernDesignSystem.Typography.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.error)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.error, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
    }
    
    // MARK: - Helper Methods
    
    /**
     * Save the calorie goal
     * Creates a new goal in calorie_goals table if none exists
     * Updates existing goal if one already exists
     */
    private func saveGoal() {
        guard let goal = Double(calorieGoalText),
              goal > 0 else {
            errorMessage = "Please enter a valid calorie goal"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // setGoal will create or update the goal in calorie_goals table
                // If no goal exists, it creates one
                // If goal exists, it updates it
                try await calorieGoalsService.setGoal(for: pet.id, calories: goal)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save goal: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Meal Row Component

/**
 * Meal Row
 * Displays a single meal in the recent meals list with delete functionality
 */
struct MealRow: View {
    let meal: FeedingRecord
    let onDelete: () -> Void
    @StateObject private var feedingLogService = FeedingLogService.shared
    @StateObject private var trendsService = CachedNutritionalTrendsService.shared
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Meal Icon
            Image(systemName: "fork.knife")
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .font(.system(size: 16))
                .frame(width: 24)
            
            // Meal Details
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                // Food Name (primary info)
                if let foodName = meal.foodName, !foodName.isEmpty {
                    Text(foodName)
                        .font(ModernDesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                } else {
                    Text("Meal")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                // Amount and brand
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Text("\(meal.amountGrams, specifier: "%.0f")g")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    if let brand = meal.foodBrand, !brand.isEmpty {
                        Text("• \(brand)")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    if let notes = meal.notes, !notes.isEmpty {
                        Text("• \(notes)")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Text(relativeDateFormatter.localizedString(for: meal.feedingTime, relativeTo: Date()))
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Delete Button
            if isDeleting {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(ModernDesignSystem.Colors.error)
                        .font(.system(size: 14))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(ModernDesignSystem.Spacing.sm)
        .background(ModernDesignSystem.Colors.surface)
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
        .alert("Delete Meal", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                deleteError = nil
            }
            Button("Delete", role: .destructive) {
                deleteError = nil
                deleteMeal()
            }
        } message: {
            if let error = deleteError {
                Text("Failed to delete meal: \(error)\n\nAre you sure you want to try again?")
            } else {
                Text("Are you sure you want to delete this meal? This action cannot be undone.")
            }
        }
    }
    
    /**
     * Delete the meal
     */
    private func deleteMeal() {
        isDeleting = true
        
        Task {
            do {
                try await feedingLogService.deleteFeedingRecord(meal.id)
                
                await MainActor.run {
                    isDeleting = false
                    // Call the onDelete callback to refresh the parent view
                    onDelete()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    // Show error to user
                    let errorMessage = error.localizedDescription
                    print("❌ Failed to delete meal: \(errorMessage)")
                    deleteError = errorMessage
                    // Re-show the alert with error message
                    showingDeleteAlert = true
                }
            }
        }
    }
}

// MARK: - Data Models


#Preview {
    NutritionalTrendsView(selectedPeriod: .constant(.thirtyDays))
        .environmentObject(AuthService.shared)
}
