//
//  NutritionalTrendsView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import Charts
import Darwin

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
    @State private var showingBreakdownSheet = false
    @State private var recentMeals: [FeedingRecord] = []
    
    private var selectedPet: Pet? {
        petSelectionService.selectedPet
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if gatekeeper.canAccessTrends() {
                    if let pet = selectedPet {
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
            .allowsHitTesting(!isLoading) // Block all interaction during loading
            
            // Loading overlay that blocks all interaction
            if isLoading {
                ModernLoadingView(message: "Loading trends...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                    .ignoresSafeArea()
                    .allowsHitTesting(true) // Allow touches on overlay to block underlying content
            }
        }
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
        // Subscription sheets hidden - app is fully free
        // .sheet(isPresented: $showingPaywall) {
        //     PaywallView()
        // }
        .sheet(isPresented: $showingBreakdownSheet) {
            if let pet = selectedPet {
                NutritionalBalanceBreakdownSheet(petId: pet.id)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        // .sheet(isPresented: $gatekeeper.showingUpgradePrompt) {
        //     UpgradePromptView(
        //         title: gatekeeper.upgradePromptTitle,
        //         message: gatekeeper.upgradePromptMessage
        //     )
        // }
        .onAppear {
            // CRITICAL: Check navigation coordinator first - skip all operations if in cooldown
            if TabNavigationCoordinator.shared.shouldBlockOperations() {
                print("⏭️ NutritionalTrendsView: Skipping onAppear - navigation cooldown active")
                return
            }
            
            // Track analytics (non-blocking)
            Task.detached(priority: .utility) { @MainActor in
                if let pet = selectedPet {
                    PostHogAnalytics.trackNutritionalTrendsViewed(petId: pet.id)
                }
            }
            
            // Load pets synchronously from cache first (immediate UI rendering)
            petService.loadPets()
            
            // Set default selected pet if needed (use petSelectionService)
            if let user = authService.currentUser,
               user.role == .premium,
               !petService.pets.isEmpty,
               selectedPet == nil,
               let firstPet = petService.pets.first {
                petSelectionService.selectPet(firstPet)
            }
            
            // Load trends data with cache-first pattern
            loadTrendsDataIfNeeded()
            loadCalorieGoalsIfNeeded()
            loadRecentMeals()
            
            // Ensure food analyses are loaded for calorie display
            if let pet = selectedPet {
                Task {
                    let nutritionService = CachedNutritionService.shared
                    try? await nutritionService.loadFoodAnalyses(for: pet.id)
                }
            }
        }
        .onChange(of: showingFeedingLog) { _, isShowing in
            if !isShowing {
                // Refresh trends and meals when feeding log is dismissed (user just logged a meal)
                loadTrendsData()
                loadRecentMeals(forceRefresh: true)
            }
        }
        .onChange(of: selectedPet) { oldPet, newPet in
            // When pet changes, load trends for the new pet (cache-first, no refresh)
            if newPet != nil {
                loadTrendsDataIfNeeded()
                loadRecentMeals(forceRefresh: false)
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
                // Limit data points on older devices to prevent freezing
                let calorieTrends = trendsService.calorieTrends(for: pet.id)
                let maxPoints = DevicePerformanceHelper.maxChartDataPoints
                let limitedCalorieTrends = Array(calorieTrends.prefix(maxPoints))
                
                if !limitedCalorieTrends.isEmpty {
                    CalorieTrendsChart(
                        trends: limitedCalorieTrends,
                        petName: pet.name
                    )
                }
                
                // Macronutrient Trends Chart
                let macronutrientTrends = trendsService.macronutrientTrends(for: pet.id)
                let limitedMacronutrientTrends = Array(macronutrientTrends.prefix(maxPoints))
                
                if !limitedMacronutrientTrends.isEmpty {
                    MacronutrientTrendsChart(
                        trends: limitedMacronutrientTrends,
                        petName: pet.name
                    )
                }
                
                // Weight Correlation
                if let correlation = trendsService.weightCorrelation(for: pet.id) {
                    WeightCorrelationCard(correlation: correlation)
                }
                
                // Disclaimer
                VeterinaryDisclaimerView()
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
                // Average Daily Calories with circular progress
                AverageDailyCaloriesCard(
                    averageCalories: trendsService.averageDailyCalories(for: pet.id),
                    goalCalories: calorieGoalsService.getGoal(for: pet.id)
                )
                
                // Feeding Frequency with orange arrow
                FeedingFrequencyCard(
                    frequency: trendsService.averageFeedingFrequency(for: pet.id)
                )
                
                // Weight Change with horizontal bar
                WeightChangeCard(
                    weightChange: trendsService.totalWeightChange(for: pet.id),
                    unit: unitService.getUnitSymbol()
                )
                
                // Nutritional Balance (compact tappable square)
                NutritionalBalanceCompactCard(
                    score: trendsService.nutritionalBalanceScore(for: pet.id),
                    onTap: {
                        showingBreakdownSheet = true
                    }
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
                    // Load food analyses in background to enable calorie display
                    Task {
                        let nutritionService = CachedNutritionService.shared
                        try? await nutritionService.loadFoodAnalyses(for: pet.id)
                        await refreshRecentMealsInBackground(for: pet.id)
                    }
                    return
                } else if !cachedMeals.isEmpty {
                    // We have cached meals but they're older than 7 days - still show them
                    // This handles the case where user has meals but they're slightly older
                    recentMeals = cachedMeals.sorted { $0.feedingTime > $1.feedingTime }
                    // Load food analyses in background to enable calorie display
                    Task {
                        let nutritionService = CachedNutritionService.shared
                        try? await nutritionService.loadFoodAnalyses(for: pet.id)
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
                
                // Load food analyses to enable calorie calculation
                // This is done in parallel with meal loading for better performance
                let nutritionService = CachedNutritionService.shared
                try? await nutritionService.loadFoodAnalyses(for: pet.id)
                
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
                    
                    LoggingManager.debug("Loaded \(recentMeals.count) meals for pet \(pet.id)", category: .nutrition)
                }
            } catch {
                // Handle errors gracefully
                if let apiError = error as? APIError,
                   case .serverError(let statusCode) = apiError {
                    if statusCode == 404 {
                        // Resource deleted - cache already invalidated by service
                        LoggingManager.debug("Recent meals resource deleted (404) - cache invalidated", category: .nutrition)
                    } else {
                        LoggingManager.warning("Failed to load recent meals: HTTP \(statusCode)", category: .nutrition)
                    }
                } else {
                    LoggingManager.error("Failed to load recent meals: \(error)", category: .nutrition)
                }
                
                // On error, try to show cached data if available
                if let cachedMeals = cacheCoordinator.get([FeedingRecord].self, forKey: cacheKey), !cachedMeals.isEmpty {
                    await MainActor.run {
                        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                        let recentCached = cachedMeals.filter { $0.feedingTime >= sevenDaysAgo }
                        recentMeals = recentCached.isEmpty ? cachedMeals.sorted { $0.feedingTime > $1.feedingTime } : recentCached.sorted { $0.feedingTime > $1.feedingTime }
                        LoggingManager.debug("Using cached meals (\(recentMeals.count)) due to error", category: .nutrition)
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
            
            // Load food analyses to enable calorie calculation
            let nutritionService = CachedNutritionService.shared
            try? await nutritionService.loadFoodAnalyses(for: petId)
            
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
                LoggingManager.debug("Background refresh: Loaded \(recentMeals.count) meals", category: .nutrition)
            }
        } catch {
            // Silent failure for background refresh
            LoggingManager.debug("Background refresh of recent meals failed: \(error)", category: .nutrition)
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
     * Does NOT automatically refresh - only loads when explicitly called
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
        }
        // If cache exists, use it - no background refresh unless explicitly requested
        // Trends only refresh when user logs meal or weight (handled by invalidateTrendsCache with autoReload)
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
            // This will also load requirements and food analyses internally
            try await trendsService.loadTrendsData(for: pet.id, period: selectedPeriod, forceRefresh: forceRefresh)
            
            // Ensure requirements and food analyses are loaded (may create requirements if missing)
            let nutritionService = CachedNutritionService.shared
            _ = try? await nutritionService.getNutritionalRequirements(for: pet.id)
            try? await nutritionService.loadFoodAnalyses(for: pet.id)
            
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

/**
 * Calorie Goal Card
 * 
 * Displays the daily calorie goal with edit option.
 * Matches mockup design with title, value, and tap-to-edit link.
 */
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
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Daily Calorie Goal")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    if let goal = calorieGoalsService.getGoal(for: pet.id) {
                        HStack(alignment: .bottom, spacing: 4) {
                            Text("\(Int(goal))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Text("kcal")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        }
                    } else {
                        Text("Not Set")
                            .font(.system(size: 24, weight: .medium, design: .rounded))
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Tap to edit link with target icon
                HStack(spacing: 4) {
                    Text(hasGoal ? "Tap to edit" : "Tap to set")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    Text(">")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    Image(systemName: "target")
                        .font(.system(size: 16))
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .background(ModernDesignSystem.Colors.softCream)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary.opacity(0.3), lineWidth: 1)
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
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
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

/**
 * Average Daily Calories Card
 * 
 * Displays average daily calories with circular progress bar showing goal percentage.
 * Matches mockup design with progress visualization.
 */
struct AverageDailyCaloriesCard: View {
    let averageCalories: Double
    let goalCalories: Double?
    
    private var progress: Double {
        guard let goal = goalCalories, goal > 0 else { return 0 }
        return min(1.0, averageCalories / goal)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Avg Daily Calories")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(Int(averageCalories))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("kcal")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            Spacer()
            
            // Circular progress bar
            ZStack {
                // Background circle
                Circle()
                    .stroke(ModernDesignSystem.Colors.textSecondary.opacity(0.2), lineWidth: 8)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ModernDesignSystem.Colors.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 60, height: 60)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary.opacity(0.3), lineWidth: 1)
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
 * Feeding Frequency Card
 * 
 * Displays average feeding frequency with orange downward arrow icon.
 * Matches mockup design with centered icon.
 */
struct FeedingFrequencyCard: View {
    let frequency: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Feeding Frequency")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.1f", frequency))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("times/day")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            Spacer()
            
            // Orange downward arrow icon
            Image(systemName: "arrow.down.right")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary.opacity(0.3), lineWidth: 1)
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
 * Weight Change Card
 * 
 * Displays weight change with horizontal gray bar indicator.
 * Matches mockup design with neutral indicator.
 */
struct WeightChangeCard: View {
    let weightChange: Double
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Weight Change")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%.1f", weightChange))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(unit)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            Spacer()
            
            // Horizontal gray bar
            Rectangle()
                .fill(ModernDesignSystem.Colors.textSecondary)
                .frame(height: 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(width: 40)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary.opacity(0.3), lineWidth: 1)
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

struct CalorieTrendsChart: View {
    let trends: [CalorieTrend]
    let petName: String
    
    @State private var isChartReady = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    // Limit data points for older devices
    private var chartData: [CalorieTrend] {
        let maxPoints = DevicePerformanceHelper.maxChartDataPoints
        return Array(trends.prefix(maxPoints))
    }
    
    // Adaptive chart height
    private var chartHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let baseHeight: CGFloat
        
        if screenHeight < 700 {
            baseHeight = 200
        } else if screenHeight < 850 {
            baseHeight = 220
        } else {
            baseHeight = 240
        }
        
        if dynamicTypeSize >= .xxxLarge {
            return baseHeight + 40
        }
        
        return baseHeight
    }
    
    // Gradient opacity (dark mode adaptive)
    private var gradientOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.2
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Title with icon
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "flame.fill")
                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                    .font(.title3)
                    .accessibilityHidden(true)
                
                Text("Calorie Trends")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            
            if #available(iOS 16.0, *) {
                if isChartReady || !DevicePerformanceHelper.shouldDeferChartRendering {
                    Chart(chartData) { trend in
                        LineMark(
                            x: .value("Date", trend.date),
                            y: .value("Calories", trend.calories)
                        )
                        .foregroundStyle(ModernDesignSystem.Colors.goldenYellow)
                        .lineStyle(StrokeStyle(lineWidth: DevicePerformanceHelper.shouldUseSimplifiedCharts ? 2 : 3))
                        
                        // AreaMark with gradient
                        if !DevicePerformanceHelper.shouldUseSimplifiedCharts {
                            AreaMark(
                                x: .value("Date", trend.date),
                                y: .value("Calories", trend.calories)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        ModernDesignSystem.Colors.goldenYellow,
                                        ModernDesignSystem.Colors.goldenYellow.opacity(gradientOpacity)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                        
                        if let target = trend.target {
                            RuleMark(y: .value("Target", target))
                                .foregroundStyle(ModernDesignSystem.Colors.primary)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        }
                    }
                    .frame(height: chartHeight)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisValueLabel(format: .dateTime.month().day())
                                .font(ModernDesignSystem.Typography.caption)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let calories = value.as(Double.self) {
                                    Text("\(Int(calories)) kcal")
                                        .font(ModernDesignSystem.Typography.caption)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                        }
                    }
                    .accessibilityLabel("Calorie trends chart showing daily calorie intake over time")
                } else {
                    ProgressView()
                        .frame(height: chartHeight)
                }
            } else {
                // Fallback for iOS 15 and earlier
                Text("Calorie trends chart requires iOS 16+")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(height: chartHeight)
            }
        }
        .onAppear {
            if DevicePerformanceHelper.shouldDeferChartRendering {
                Task { @MainActor in
                    await Task.yield()
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    if !Task.isCancelled {
                        isChartReady = true
                    }
                }
            } else {
                isChartReady = true
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
            color: colorScheme == .dark
                ? ModernDesignSystem.Shadows.medium.color.opacity(0.3)
                : ModernDesignSystem.Shadows.medium.color,
            radius: ModernDesignSystem.Shadows.medium.radius,
            x: ModernDesignSystem.Shadows.medium.x,
            y: ModernDesignSystem.Shadows.medium.y
        )
    }
}

struct MacronutrientTrendsChart: View {
    let trends: [MacronutrientTrend]
    let petName: String
    
    @State private var isChartReady = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    // Limit data points for older devices
    private var chartData: [MacronutrientTrend] {
        let maxPoints = DevicePerformanceHelper.maxChartDataPoints
        return Array(trends.prefix(maxPoints))
    }
    
    // Adaptive chart height
    private var chartHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        let baseHeight: CGFloat
        
        if screenHeight < 700 {
            baseHeight = 200
        } else if screenHeight < 850 {
            baseHeight = 220
        } else {
            baseHeight = 240
        }
        
        if dynamicTypeSize >= .xxxLarge {
            return baseHeight + 40
        }
        
        return baseHeight
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Title with icon
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title3)
                    .accessibilityHidden(true)
                
                Text("Macronutrient Trends")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            
            // Simplified legend with color dots
            HStack(spacing: ModernDesignSystem.Spacing.lg) {
                simpleLegendItem(color: ModernDesignSystem.Colors.warmCoral, label: "Protein")
                simpleLegendItem(color: ModernDesignSystem.Colors.primary, label: "Fat")
                if !DevicePerformanceHelper.shouldUseSimplifiedCharts {
                    simpleLegendItem(color: ModernDesignSystem.Colors.goldenYellow, label: "Fiber")
                }
            }
            
            if #available(iOS 16.0, *) {
                if isChartReady || !DevicePerformanceHelper.shouldDeferChartRendering {
                    Chart(chartData) { trend in
                        // Protein - clean line only
                        LineMark(
                            x: .value("Date", trend.date),
                            y: .value("Protein", trend.protein)
                        )
                        .foregroundStyle(ModernDesignSystem.Colors.warmCoral)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .symbol(.circle)
                        
                        // Fat - clean line only
                        LineMark(
                            x: .value("Date", trend.date),
                            y: .value("Fat", trend.fat)
                        )
                        .foregroundStyle(ModernDesignSystem.Colors.primary)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .symbol(.circle)
                        
                        // Fiber line only if not simplified
                        if !DevicePerformanceHelper.shouldUseSimplifiedCharts {
                            LineMark(
                                x: .value("Date", trend.date),
                                y: .value("Fiber", trend.fiber)
                            )
                            .foregroundStyle(ModernDesignSystem.Colors.goldenYellow)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                            .symbol(.circle)
                        }
                    }
                    .frame(height: chartHeight)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                            AxisValueLabel(format: .dateTime.month().day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let grams = value.as(Double.self) {
                                    Text("\(grams, specifier: "%.0f")g")
                                        .font(ModernDesignSystem.Typography.caption)
                                }
                            }
                        }
                    }
                    .chartLegend(.hidden) // Hide default legend, use custom
                    .accessibilityLabel("Macronutrient trends showing protein, fat, and fiber intake over time")
                } else {
                    ProgressView()
                        .frame(height: chartHeight)
                }
            } else {
                // Fallback for iOS 15 and earlier
                Text("Macronutrient trends chart requires iOS 16+")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(height: chartHeight)
            }
        }
        .onAppear {
            if DevicePerformanceHelper.shouldDeferChartRendering {
                Task { @MainActor in
                    await Task.yield()
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if !Task.isCancelled {
                        isChartReady = true
                    }
                }
            } else {
                isChartReady = true
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
            color: colorScheme == .dark
                ? ModernDesignSystem.Shadows.medium.color.opacity(0.3)
                : ModernDesignSystem.Shadows.medium.color,
            radius: ModernDesignSystem.Shadows.medium.radius,
            x: ModernDesignSystem.Shadows.medium.x,
            y: ModernDesignSystem.Shadows.medium.y
        )
    }
    
    // MARK: - Simplified Legend Item
    
    @ViewBuilder
    private func simpleLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            Text(label)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
    }
}

struct FeedingPatternsChart: View {
    let patterns: [FeedingPattern]
    let petName: String
    
    @State private var isChartReady = false
    
    // Limit data points for older devices
    private var chartData: [FeedingPattern] {
        let maxPoints = DevicePerformanceHelper.maxChartDataPoints
        return Array(patterns.prefix(maxPoints))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Feeding Patterns")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if #available(iOS 16.0, *) {
                if isChartReady || !DevicePerformanceHelper.shouldDeferChartRendering {
                    Chart(chartData) { pattern in
                        BarMark(
                            x: .value("Date", pattern.date),
                            y: .value("Feedings", pattern.feedingCount)
                        )
                        .foregroundStyle(ModernDesignSystem.Colors.primary)
                        
                        // LineMark disabled on older devices for performance
                        if !DevicePerformanceHelper.shouldUseSimplifiedCharts {
                            LineMark(
                                x: .value("Date", pattern.date),
                                y: .value("Compatibility", pattern.compatibilityScore)
                            )
                            .foregroundStyle(ModernDesignSystem.Colors.goldenYellow)
                            .lineStyle(StrokeStyle(lineWidth: 2))
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
                                if let count = value.as(Int.self) {
                                    Text("\(count)")
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .frame(height: 200)
                }
            } else {
                // Fallback for iOS 15 and earlier
                Text("Feeding patterns chart requires iOS 16+")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(height: 200)
            }
        }
        .onAppear {
            // Defer chart rendering on older devices to prevent freezing
            if DevicePerformanceHelper.shouldDeferChartRendering {
                Task { @MainActor in
                    await Task.yield()
                    try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds (staggered for multiple charts)
                    if !Task.isCancelled {
                        isChartReady = true
                    }
                }
            } else {
                isChartReady = true
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
    @StateObject private var nutritionService = CachedNutritionService.shared
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
    
    /**
     * Calculate calories for this meal
     * - Returns: Calories consumed, or nil if food analysis is not available
     * - Note: Prefers calories from API response, falls back to calculation
     * - Uses improved fallback logic: tries ID lookup first, then food name matching
     */
    private var mealCalories: Double? {
        // First try: Use calories from API response if available and > 0
        // Since calories is now non-optional, check if it's > 0 to determine if it's valid
        if meal.calories > 0 {
            return meal.calories
        }
        
        // Second try: Get food analysis by ID
        var analysis = nutritionService.getFoodAnalysis(by: meal.foodAnalysisId)
        
        // Third try: If not found by ID, try to find by food name (case-insensitive match)
        // This uses the same improved fallback logic we added to trends service
        if analysis == nil, let foodName = meal.foodName, !foodName.isEmpty {
            // Try to find food analysis by name (case-insensitive match)
            analysis = nutritionService.foodAnalyses.first(where: {
                $0.petId == meal.petId &&
                $0.foodName.localizedCaseInsensitiveContains(foodName)
            })
        }
        
        // Calculate calories from analysis if found
        if let analysis = analysis {
            let calculatedCalories = meal.calculateCaloriesConsumed(from: analysis)
            return calculatedCalories
        }
        
        return nil
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
                
                // Amount, brand, and calories
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
                    
                    // Always show calories if available (prominent display)
                    if let calories = mealCalories {
                        Text("• \(Int(calories)) kcal")
                            .font(ModernDesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
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
        .task {
            // Ensure food analyses are loaded when this view appears
            // This helps ensure calories can be calculated even if they weren't loaded initially
            if mealCalories == nil {
                Task {
                    do {
                        try await nutritionService.loadFoodAnalyses(for: meal.petId)
                        LoggingManager.debug("Loaded food analyses for pet \(meal.petId)", category: .nutrition)
                    } catch {
                        LoggingManager.warning("Failed to load food analyses: \(error)", category: .nutrition)
                    }
                }
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
                    LoggingManager.error("Failed to delete meal: \(errorMessage)", category: .nutrition)
                    deleteError = errorMessage
                    // Re-show the alert with error message
                    showingDeleteAlert = true
                }
            }
        }
    }
}

// MARK: - Nutritional Balance Breakdown Components

/**
 * Nutritional Balance Compact Card
 * 
 * Compact square tappable card that displays nutritional balance index
 * Designed to fit in the 2-column grid next to Weight Change
 * Opens bottom sheet with detailed breakdown when tapped
 */
/**
 * Nutritional Balance Compact Card
 * 
 * Displays nutritional balance index with leaf icon and tap indicator.
 * Matches mockup design with leaf icon top-left, value centered, arrow bottom-right.
 */
struct NutritionalBalanceCompactCard: View {
    let score: Double
    let onTap: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    private let haptics = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        Button(action: {
            haptics.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Icon and title at top
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 14))
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    Text("Nutritional Balance Index")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    Spacer()
                }
                
                Spacer()
                
                // Balance index value centered
                Text("\(Int(score))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
                
                // Green arrow in bottom-right
                HStack {
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(ModernDesignSystem.Colors.softCream)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .shadow(
                color: colorScheme == .dark
                    ? ModernDesignSystem.Shadows.small.color.opacity(0.3)
                    : ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Nutritional Balance: Balance Index \(Int(score)). Tap to view detailed breakdown")
        .accessibilityAddTraits(.isButton)
    }
}

/**
 * Nutritional Balance Breakdown Sheet
 * 
 * Bottom sheet that displays detailed breakdown of protein, fat, and fiber
 * with color-coded status indicators and contextual explanations
 */
struct NutritionalBalanceBreakdownSheet: View {
    let petId: String
    
    @StateObject private var trendsService = CachedNutritionalTrendsService.shared
    @StateObject private var nutritionService = CachedNutritionService.shared
    @StateObject private var feedingLogService = FeedingLogService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showFeedingLog = false
    @State private var isLoadingData = false
    @State private var breakdown: NutritionalBreakdown?
    @State private var dataLoadTimestamp: Date = Date()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    if let breakdown = breakdown, !breakdown.hasInsufficientData {
                        // Balance Summary (replaces Overall Score)
                        if let summary = breakdown.summary {
                            BalanceSummaryCard(summary: summary)
                        }
                        
                        // Macro Breakdown
                        VStack(spacing: ModernDesignSystem.Spacing.md) {
                            macroProgressBar(data: breakdown.protein)
                            macroProgressBar(data: breakdown.fat)
                            macroProgressBar(data: breakdown.fiber)
                        }
                        
                        // Action Plan
                        if let plan = breakdown.plan {
                            NutrientPlanCard(plan: plan)
                        }
                        
                        // Educational Info
                        educationalCard
                    } else {
                        // Empty State
                        emptyStateView
                    }
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Nutritional Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
            .sheet(isPresented: $showFeedingLog) {
                FeedingLogView()
            }
            .task {
                await loadNutritionalData()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(breakdown?.accessibilityDescription ?? "Nutritional balance requires more data")
    }
    
    // MARK: - Balance Summary Card
    
    /**
     * Balance Summary Card
     * Replaces the old "Overall Score 100%" card with a status-based summary
     */
    struct BalanceSummaryCard: View {
        let summary: NutritionalBalanceSummary
        
        var body: some View {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                // Status badge
                Text(summary.status.displayText)
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(summary.status.color)
                    .fontWeight(.semibold)
                
                // Targets met or balance index
                if let index = summary.balanceIndex {
                    Text("Balance Index: \(Int(index))")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                } else {
                    Text("\(summary.targetsMet) of \(summary.targetsTotal) targets met")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                }
                
                // Driver attribution
                Text("\(summary.primaryDriver) is the biggest issue today (\(Int(summary.primaryDriverPercent))% of recommended)")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                // Explanation
                Text(summary.explanation)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .background(ModernDesignSystem.Colors.softCream)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(summary.accessibilityLabel)
        }
    }
    
    // MARK: - Nutrient Plan Card
    
    /**
     * Nutrient Plan Card
     * Shows prioritized actions to improve nutritional balance
     */
    struct NutrientPlanCard: View {
        let plan: NutrientPlan
        
        var body: some View {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                Text("Your Action Plan")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    ForEach(plan.actions.prefix(3)) { action in
                        PlanActionRow(action: action)
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
            .accessibilityElement(children: .contain)
            .accessibilityLabel(planAccessibilityLabel)
        }
        
        private var planAccessibilityLabel: String {
            var label = "Your Action Plan. "
            for (index, action) in plan.actions.prefix(3).enumerated() {
                label += "Priority \(index + 1): \(action.instruction). Currently \(Int(action.current)) grams versus recommended \(Int(action.target)) grams. "
            }
            return label
        }
    }
    
    /**
     * Plan Action Row
     * Individual action item in the plan
     */
    struct PlanActionRow: View {
        let action: PlanAction
        
        var body: some View {
            HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                Text(action.priorityIndicator)
                    .font(ModernDesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .frame(width: 24, alignment: .leading)
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(action.instruction)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Currently \(Int(action.current))g vs recommended \(Int(action.target))g")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Priority \(action.priority): \(action.instruction). Currently \(Int(action.current)) grams versus recommended \(Int(action.target)) grams")
        }
    }
    
    // MARK: - Macro Progress Bar
    
    @ViewBuilder
    private func macroProgressBar(data: MacroNutrientData) -> some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            // Header with icon and name
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: data.icon)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(data.status.color)
                    .frame(width: 24)
                
                Text(data.name)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                // Status badge
                Text(data.status.displayText)
                    .font(ModernDesignSystem.Typography.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                    .background(data.status.color)
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                        .fill(ModernDesignSystem.Colors.borderPrimary.opacity(0.2))
                        .frame(height: 8)
                    
                    // Foreground (clamped to 100% visually)
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                        .fill(data.status.color)
                        .frame(
                            width: geometry.size.width * min(data.percentage / 100.0, 1.0),
                            height: 8
                        )
                }
            }
            .frame(height: 8)
            
            // Values and context
            HStack {
                Text("\(Int(data.percentage))% of recommended")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Spacer()
            }
            
            Text(data.contextText)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .accessibilityValue(data.accessibilityLabel)
    }
    
    // MARK: - Educational Card
    
    private var educationalCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title3)
                
                Text("What This Means")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                educationalRow(
                    color: ModernDesignSystem.Colors.primary,
                    title: "Optimal (90-110%)",
                    description: "Your pet's intake is within the ideal range"
                )
                
                educationalRow(
                    color: ModernDesignSystem.Colors.goldenYellow,
                    title: "Slightly Off (80-120%)",
                    description: "Close to recommended, minor adjustments may help"
                )
                
                educationalRow(
                    color: ModernDesignSystem.Colors.warmCoral,
                    title: "Needs Attention (<80% or >120%)",
                    description: "Consult your veterinarian for dietary guidance"
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
    }
    
    @ViewBuilder
    private func educationalRow(color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(title)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - Empty State
    
    // MARK: - Data Loading
    
    /**
     * Load nutritional data for the pet
     * 
     * Fetches feeding records, food analyses, and nutritional requirements
     */
    private func loadNutritionalData() async {
        isLoadingData = true
        defer { isLoadingData = false }
        
        do {
            print("🔄 [BreakdownSheet] Loading data for pet: \(petId)")
            
            // Load all required data in parallel for better performance
            // Use withThrowingTaskGroup for Void-returning functions
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await self.nutritionService.loadFeedingRecords(for: self.petId, days: 30)
                }
                group.addTask {
                    try await self.nutritionService.loadFoodAnalyses(for: self.petId)
                }
                group.addTask {
                    _ = try await self.nutritionService.getNutritionalRequirements(for: self.petId)
                }
                
                // Wait for all tasks to complete
                try await group.waitForAll()
            }
            
            print("✅ [BreakdownSheet] Data loaded successfully")
            print("   📊 Food analyses count: \(nutritionService.foodAnalyses.count)")
            LoggingManager.debug("Feeding records count: \(nutritionService.feedingRecords.count)", category: .nutrition)
            
            // Calculate breakdown AFTER data is loaded and update state
            await MainActor.run {
                self.breakdown = trendsService.getNutritionalBreakdown(for: petId)
                self.dataLoadTimestamp = Date() // Trigger view update
            }
            
            // Debug: Check what we got
            if let breakdown = breakdown {
                print("📊 [BreakdownSheet] Score: \(breakdown.overallScore)%, Protein: \(breakdown.protein.percentage)%, Fat: \(breakdown.fat.percentage)%, Fiber: \(breakdown.fiber.percentage)%")
            } else {
                print("⚠️ [BreakdownSheet] No breakdown data available after calculation")
            }
        } catch {
            print("❌ [BreakdownSheet] Failed to load data: \(error)")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Log Meals to Track Balance")
                .font(ModernDesignSystem.Typography.title2)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text("We need at least 3 logged meals to calculate your pet's nutritional balance")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: {
                showFeedingLog = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Log First Meal")
                }
                .font(ModernDesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.vertical, ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.buttonPrimary)
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityHint("Opens meal logging screen")
            
            Text("Nutritional balance compares your pet's protein, fat, and fiber intake against veterinary recommendations")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, ModernDesignSystem.Spacing.sm)
        }
        .padding(ModernDesignSystem.Spacing.xl)
    }
}

// MARK: - Veterinary Disclaimer View

/**
 * Veterinary Disclaimer View
 * 
 * Displays a disclaimer that the app is for tracking purposes only
 * and does not replace veterinary recommendations.
 */
struct VeterinaryDisclaimerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .padding(.top, 2)
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Medical Disclaimer")
                        .font(ModernDesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("This information is for tracking purposes only and does not replace a veterinarian's recommendation. Please seek professional veterinary advice for medically accurate information specific to your individual pet.")
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream.opacity(0.5))
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                .stroke(ModernDesignSystem.Colors.borderPrimary.opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
    }
}

// MARK: - Data Models


// MARK: - Data Models

// MARK: - View Extensions

extension View {
    /// Applies a modifier conditionally
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}


#Preview {
    NutritionalTrendsView(selectedPeriod: .constant(.thirtyDays))
        .environmentObject(AuthService.shared)
}
