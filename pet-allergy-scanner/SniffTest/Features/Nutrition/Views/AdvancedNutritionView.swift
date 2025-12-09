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
    // MEMORY OPTIMIZATION: Use direct access for non-observable services, @ObservedObject for observable ones
    // @ObservedObject is better than @StateObject for shared singletons as it doesn't create new instances
    private let petService = CachedPetService.shared
    @ObservedObject private var petSelectionService = NutritionPetSelectionService.shared
    @ObservedObject private var unitService = WeightUnitPreferenceService.shared
    private let cachedNutritionService = CachedNutritionService.shared
    private let cachedWeightService = CachedWeightTrackingService.shared
    @ObservedObject private var gatekeeper = SubscriptionGatekeeper.shared
    @State private var selectedTab = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingWeightEntry = false
    @State private var showingGoalSetting = false
    @State private var showingPeriodSelector = false
    @State private var selectedPeriod: TrendPeriod = .thirtyDays
    @State private var showingPaywall = false
    @State private var loadTask: Task<Void, Never>?
    @State private var refreshTask: Task<Void, Never>?
    @State private var onAppearTask: Task<Void, Never>?
    @State private var lastAppearTime: Date?
    
    private var selectedPet: Pet? {
        petSelectionService.selectedPet
    }
    
    /// Get current tab name for analytics
    private var selectedTabName: String {
        tabName(for: selectedTab)
    }
    
    /// Get tab name from index
    private func tabName(for index: Int) -> String {
        switch index {
        case 0: return "Weight"
        case 1: return "Trends"
        case 2: return "Compare"
        case 3: return "Analytics"
        default: return "Unknown"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    if gatekeeper.canAccessAnalytics() {
                        if let pet = selectedPet {
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
                .allowsHitTesting(!isLoading) // Block all interaction during loading
                
                // Loading overlay that blocks all interaction
                if isLoading {
                    ModernLoadingView(message: "Loading nutrition data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                        .ignoresSafeArea()
                        .allowsHitTesting(true) // Allow touches on overlay to block underlying content
                }
            }
            .navigationTitle(selectedPet.map { "\($0.name) - Advanced" } ?? "Advanced Nutrition")
            .navigationBarTitleDisplayMode(.large)
            // CRITICAL iOS 18.6+: Use toolbarBackground with ultraThinMaterial for liquid glass effect
            // DO NOT combine with toolbarColorScheme to avoid opacity issues
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                // Only show toolbar items if user has premium access
                if gatekeeper.canAccessAnalytics() {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if selectedTab == 0 && selectedPet != nil {
                            // Weight tab - Add Weight button integrated with liquid glass
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
                                .foregroundColor(ModernDesignSystem.Colors.buttonPrimary)
                                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                            }
                            .buttonStyle(.plain)
                        } else if selectedTab == 1 && selectedPet != nil {
                            // Trends tab - Period selector integrated with liquid glass
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
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Refresh Data") {
                                loadNutritionData(forceRefresh: true)
                            }
                            .disabled(selectedPet == nil || isLoading)
                            
                            if selectedPet != nil {
                                Button("Change Pet") {
                                    petSelectionService.clearSelection()
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                .padding(ModernDesignSystem.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showingWeightEntry) {
            if let pet = selectedPet {
                WeightEntryView(pet: pet, lastRecordedWeightId: .constant(nil))
                    .onDisappear {
                        // Refresh nutrition data when the weight entry sheet is dismissed (force refresh to get latest data)
                        loadNutritionData(forceRefresh: true)
                    }
            }
        }
        .sheet(isPresented: $showingGoalSetting) {
            if let pet = selectedPet {
                WeightGoalSettingView(pet: pet, existingGoal: nil)
                    .onDisappear {
                        // Refresh nutrition data when the goal setting sheet is dismissed (force refresh to get latest data)
                        loadNutritionData(forceRefresh: true)
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
            // CRITICAL: Check navigation coordinator first - skip all operations if in cooldown
            if TabNavigationCoordinator.shared.shouldBlockOperations() {
                print("⏭️ AdvancedNutritionView: Skipping onAppear - navigation cooldown active")
                return
            }
            
            // CRITICAL: Debounce rapid tab switches to prevent freezing
            let now = Date()
            if let lastAppear = lastAppearTime, now.timeIntervalSince(lastAppear) < 0.5 {
                print("⏭️ AdvancedNutritionView: Skipping onAppear (too soon after last appear)")
                return
            }
            lastAppearTime = now
            
            let viewLoadStart = Date()
            
            // Cancel any existing onAppear task first
            onAppearTask?.cancel()
            onAppearTask = nil
            
            // Create a single task for all onAppear operations
            onAppearTask = Task(priority: .userInitiated) { @MainActor in
                // CRITICAL: Longer delay to ensure previous view's onDisappear has completed
                // This prevents freezing when switching tabs rapidly
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds (increased)
                guard !Task.isCancelled else { return }
                
                // Double-check coordinator before proceeding
                if TabNavigationCoordinator.shared.shouldBlockOperations() {
                    print("⏭️ AdvancedNutritionView: Aborting operations - cooldown still active")
                    return
                }
                
                // Yield to allow any pending cancellations to complete
                await Task.yield()
                guard !Task.isCancelled else { return }
                
                // Track analytics (non-blocking) - don't capture self
                let petId = selectedPet?.id
                let petName = selectedPet?.name
                let tabName = selectedTabName
                Task.detached(priority: .utility) { @MainActor in
                    if let petId = petId, let petName = petName {
                        PostHogAnalytics.trackAdvancedNutritionViewOpened(petId: petId)
                        // Track screen for session replay
                        PostHogAnalytics.trackScreenViewed(
                            screenName: "AdvancedNutritionView",
                            properties: [
                                "pet_id": petId,
                                "pet_name": petName,
                                "selected_tab": tabName
                            ]
                        )
                    }
                }
                
                // Load pets asynchronously to prevent blocking UI
                // Use async version to avoid any potential blocking
                Task.detached(priority: .utility) { @MainActor in
                    CachedPetService.shared.loadPets()
                }
                
                // Yield to allow UI to render first
                await Task.yield()
                guard !Task.isCancelled else { return }
                
                // Auto-select pet if needed
                autoSelectSinglePet()
                
                // Yield again after auto-select
                await Task.yield()
                guard !Task.isCancelled else { return }
                
                // Load nutrition data with cache-first pattern
                loadNutritionDataIfNeeded()
                
                // Track view load performance
                let loadTime = Date().timeIntervalSince(viewLoadStart)
                Task.detached(priority: .utility) { @MainActor in
                    PostHogAnalytics.trackViewLoad(
                        viewName: "AdvancedNutritionView",
                        loadTime: loadTime,
                        success: true
                    )
                }
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Track tab changes for session replay analysis
            Task.detached(priority: .utility) { @MainActor in
                if let pet = selectedPet {
                    PostHogAnalytics.trackScreenViewed(
                        screenName: "AdvancedNutritionView_\(selectedTabName)",
                        properties: [
                            "pet_id": pet.id,
                            "tab_index": newValue,
                            "tab_name": selectedTabName,
                            "previous_tab": tabName(for: oldValue)
                        ]
                    )
                }
            }
        }
        .onDisappear {
            // CRITICAL: Cancel all ongoing tasks to prevent state updates after view disappears
            onAppearTask?.cancel()
            onAppearTask = nil
            loadTask?.cancel()
            loadTask = nil
            refreshTask?.cancel()
            refreshTask = nil
            
            // Reset loading state to prevent stuck UI
            isLoading = false
            
            // MEMORY OPTIMIZATION: Clear cached data when view disappears to free memory
            // This helps prevent memory buildup when navigating between tabs
            Task {
                // Clear image cache if memory pressure is high
                let stats = MemoryEfficientImageCache.shared.getCacheStats()
                if stats.memoryUsage > 20_000_000 { // If over 20MB
                    MemoryEfficientImageCache.shared.clearCache()
                }
            }
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
                            // Load nutrition data with cache-first pattern when pet is selected
                            loadNutritionDataIfNeeded()
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
            // CRITICAL: Use Group to prevent SwiftUI view identity issues with nested TabView
            Group {
                switch selectedTab {
                case 0:
                    WeightManagementView()
                        .environmentObject(authService)
                case 1:
                    NutritionalTrendsView(selectedPeriod: $selectedPeriod)
                        .environmentObject(authService)
                case 2:
                    FoodComparisonView()
                        .environmentObject(authService)
                case 3:
                    AdvancedAnalyticsView()
                        .environmentObject(authService)
                default:
                    WeightManagementView()
                        .environmentObject(authService)
                }
            }
            .id(selectedTab) // Force view recreation on tab change to prevent state issues
        }
    }
    
    // MARK: - Pet Header Section
    
    private func petHeaderSection(_ pet: Pet) -> some View {
        HStack {
            // MEMORY OPTIMIZATION: Use RemoteImageView for memory-efficient image loading
            RemoteImageView(
                petImageUrl: pet.imageUrl,
                species: pet.species,
                contentMode: .fill
            )
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
                
                if let weight = cachedWeightService.currentWeights[pet.id] ?? pet.weightKg {
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
     * Load nutrition data with cache-first pattern
     * Checks cache synchronously first to avoid flashing
     * Only shows loading spinner if no cache exists
     */
    private func loadNutritionDataIfNeeded() {
        // If no pet is selected, don't proceed with nutrition data loading
        guard let pet = selectedPet ?? petService.pets.first else { return }
        
        // Check cache synchronously first (immediate UI rendering)
        let hasCachedNutritionData = cachedNutritionService.hasCachedNutritionData(for: pet.id)
        let hasCachedWeightData = cachedWeightService.hasCachedWeightData(for: pet.id)
        
        if hasCachedNutritionData && hasCachedWeightData {
            // We have cached data - refresh in background silently (no loading spinner)
            print("✅ Using cached nutrition data for pet: \(pet.name)")
            // Cancel any existing refresh task
            refreshTask?.cancel()
            refreshTask = Task {
                await refreshNutritionDataInBackground(for: pet.id)
            }
        } else {
            // Missing some cached data - show loading and load from server
            print("⚠️ Missing cached data, loading from server for pet: \(pet.name)")
            // Cancel any existing load task
            loadTask?.cancel()
            isLoading = true
            loadNutritionData()
        }
    }
    
    /**
     * Load nutrition data using cache-first approach for optimal performance
     * Only makes API calls when cache is empty or data is stale
     * Force refresh when explicitly called (e.g., after adding/deleting records)
     */
    private func loadNutritionData(forceRefresh: Bool = false) {
        // If no pet is selected, don't proceed with nutrition data loading
        guard let pet = selectedPet ?? petService.pets.first else { return }
        
        // Check cache synchronously first to avoid flashing (unless force refresh)
        if !forceRefresh {
            let hasCachedNutrition = cachedNutritionService.hasCachedNutritionData(for: pet.id)
            let hasCachedWeight = cachedWeightService.hasCachedWeightData(for: pet.id)
            
            // Only show loading if we don't have cached data
            if !hasCachedNutrition || !hasCachedWeight {
                isLoading = true
            } else {
                // Cache exists - refresh in background silently
                // Cancel any existing refresh task
                refreshTask?.cancel()
                refreshTask = Task {
                    await refreshNutritionDataInBackground(for: pet.id)
                }
                return
            }
        } else {
            // Force refresh - show loading
            isLoading = true
        }
        
        errorMessage = nil
        
        // Add timeout protection to prevent isLoading from getting stuck
        var timeoutTask: Task<Void, Never>?
        let loadStartTime = Date()
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            if !Task.isCancelled && isLoading {
                let freezeDuration = Date().timeIntervalSince(loadStartTime)
                print("⚠️ Nutrition data load timeout - resetting isLoading")
                // Track UI freeze in PostHog
                PostHogAnalytics.trackUIFreeze(
                    viewName: "AdvancedNutritionView",
                    duration: freezeDuration,
                    action: "loadNutritionData"
                )
                PostHogAnalytics.trackError(
                    error: "Nutrition data load timeout after \(Int(freezeDuration))s",
                    context: "AdvancedNutritionView.loadNutritionData",
                    severity: "high"
                )
                isLoading = false
            }
        }
        
        // Cancel any existing load task before starting a new one
        loadTask?.cancel()
        loadTask = Task {
            defer {
                timeoutTask?.cancel()
            }
            
            // Yield immediately to allow view to render first - critical for preventing UI freeze
            await Task.yield()
            
            // Check if task was cancelled (e.g., view disappeared)
            guard !Task.isCancelled else { return }
            
            do {
                // Use cached services to load data efficiently (cache-first)
                // These services will check cache first before making API calls
                
                // Load nutritional requirements (cache-first)
                // Note: getNutritionalRequirements doesn't support forceRefresh, it always checks cache first
                _ = try await cachedNutritionService.getNutritionalRequirements(for: pet.id)
                
                // Check cancellation before continuing
                guard !Task.isCancelled else { return }
                
                // Load weight data (cache-first)
                try await cachedWeightService.loadWeightData(for: pet.id, forceRefresh: forceRefresh)
                
                // Check cancellation before continuing
                guard !Task.isCancelled else { return }
                
                // Load feeding records (cache-first)
                try await cachedNutritionService.loadFeedingRecords(for: pet.id, forceRefresh: forceRefresh)
                
                // Check cancellation before continuing
                guard !Task.isCancelled else { return }
                
                // Load daily summaries (cache-first)
                // Note: Daily summaries are computed data - 404 means "no data yet", not "deleted"
                // The service handles 404s gracefully by returning empty array
                try await cachedNutritionService.loadDailySummaries(for: pet.id, forceRefresh: forceRefresh)
                
                // Check cancellation before updating UI
                guard !Task.isCancelled else { return }
                
                // CRITICAL: Only update state if view is still alive
                await MainActor.run {
                    // Double-check cancellation before state update
                    guard !Task.isCancelled else { return }
                    isLoading = false
                }
                
            } catch {
                // Check cancellation before handling error
                guard !Task.isCancelled else { return }
                
                // Handle 404 errors gracefully - for computed data like daily summaries,
                // 404 means "no data yet" (no meals logged), not an error
                if let apiError = error as? APIError,
                   case .serverError(let statusCode) = apiError,
                   statusCode == 404 {
                    // For daily summaries, 404 is normal when no meals exist - don't show error
                    print("ℹ️ [AdvancedNutritionView] No daily summaries yet - no meals logged (404 is normal)")
                // CRITICAL: Only update state if view is still alive
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    isLoading = false
                    // Don't set errorMessage - empty state is valid
                }
                    return
                }
                
                // Track error in PostHog (only for non-deleted resource errors)
                PostHogAnalytics.trackError(
                    error: error.localizedDescription,
                    context: "AdvancedNutritionView.loadNutritionData",
                    severity: "medium"
                )
                
                // CRITICAL: Only update state if view is still alive
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
                print("❌ Failed to load nutrition data: \(error)")
            }
        }
    }
    
    /**
     * Refresh nutrition data in background (silent refresh)
     * Used when cache exists to update data without showing loading spinner
     */
    private func refreshNutritionDataInBackground(for petId: String) async {
        // Yield immediately to prevent blocking
        await Task.yield()
        
        // Check cancellation before proceeding
        guard !Task.isCancelled else { return }

        do {
            // Load data in background without showing loading state
            // Note: getNutritionalRequirements doesn't support forceRefresh, it always checks cache first
            _ = try await cachedNutritionService.getNutritionalRequirements(for: petId)
            
            // Check cancellation before each operation
            guard !Task.isCancelled else { return }
            
            try await cachedWeightService.loadWeightData(for: petId, forceRefresh: false)
            
            // Check cancellation again
            guard !Task.isCancelled else { return }
            
            try await cachedNutritionService.loadFeedingRecords(for: petId, days: 30, forceRefresh: false)
            
            // Final check before loading daily summaries
            guard !Task.isCancelled else { return }
            
            // Load daily summaries - service handles 404s gracefully (empty array for no data)
            try await cachedNutritionService.loadDailySummaries(for: petId, days: 30, forceRefresh: false)
        } catch {
            // Handle 404s gracefully - for computed data like daily summaries,
            // 404 means "no data yet" (no meals logged), not an error
            if let apiError = error as? APIError,
               case .serverError(let statusCode) = apiError,
               statusCode == 404 {
                // 404 is normal for computed data when no source data exists - don't log as error
                print("ℹ️ [AdvancedNutritionView] Background refresh: No data yet (404) - normal for computed data")
            } else {
                // Only log non-404 errors
                print("⚠️ Background refresh of nutrition data failed: \(error.localizedDescription)")
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
    // MEMORY OPTIMIZATION: Use @ObservedObject for observable shared singletons
    @ObservedObject private var unitService = WeightUnitPreferenceService.shared
    @ObservedObject private var cachedWeightService = CachedWeightTrackingService.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // MEMORY OPTIMIZATION: Use RemoteImageView for memory-efficient image loading
                RemoteImageView(
                    petImageUrl: pet.imageUrl,
                    species: pet.species,
                    contentMode: .fill
                )
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
                    
                    if let weight = cachedWeightService.currentWeights[pet.id] ?? pet.weightKg {
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
    // MEMORY OPTIMIZATION: Use direct access for non-observable services, @ObservedObject for observable ones
    private let analyticsService = AdvancedAnalyticsService.shared
    private let cachedNutritionService = CachedNutritionService.shared
    private let cachedWeightService = CachedWeightTrackingService.shared
    private let trendsService = CachedNutritionalTrendsService.shared
    @ObservedObject private var petSelectionService = NutritionPetSelectionService.shared
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
                    
                    // Insights & Recommendations
                    if let pet = petSelectionService.selectedPet {
                        InsightsCard(
                            insights: healthInsights?.recommendations.map { $0.title } ?? [],
                            pet: pet
                        )
                    }
                    
                    // Disclaimer
                    VeterinaryDisclaimerView()
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
        
        // CRITICAL: Ensure trends data is loaded first (with improved fallback logic)
        // This ensures nutritional balance score is calculated correctly
        do {
            try await trendsService.loadTrendsData(for: petId, period: .thirtyDays, forceRefresh: false)
        } catch {
            print("⚠️ [AdvancedAnalyticsView] Failed to load trends data: \(error.localizedDescription)")
            // Continue anyway - will use fallback calculation
        }
        
        do {
            async let insightsTask = analyticsService.fetchHealthInsights(petId: petId)
            async let patternsTask = analyticsService.fetchNutritionalPatterns(petId: petId)
            
            let insights = try await insightsTask
            let patterns = try await patternsTask
            
            await MainActor.run {
                // CRITICAL: Override nutritionalAdequacyScore with trends service value
                // This ensures we use the improved fallback logic (food name matching)
                let trendsBalance = trendsService.nutritionalBalanceScore(for: petId)
                if trendsBalance > 0 {
                    // Create updated insights with correct nutritional balance
                    let updatedInsights = HealthInsights(
                        petId: insights.petId,
                        analysisDate: insights.analysisDate,
                        weightManagementStatus: insights.weightManagementStatus,
                        nutritionalAdequacyScore: trendsBalance, // Use trends service value
                        feedingConsistencyScore: insights.feedingConsistencyScore,
                        healthRisks: insights.healthRisks,
                        positiveIndicators: insights.positiveIndicators,
                        recommendations: insights.recommendations,
                        overallHealthScore: insights.overallHealthScore
                    )
                    self.healthInsights = updatedInsights
                } else {
                    self.healthInsights = insights
                }
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
            let dailySummaries = cachedNutritionService.dailySummaries(for: petId)
            
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
                nutritionalAdequacyScore: calculateNutritionalScore(dailySummaries: dailySummaries, petId: petId),
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
                // CRITICAL: Sanitize all numeric values to prevent NaN propagation
                let healthScore = sanitizeScore(healthInsights?.overallHealthScore)
                let nutritionalScore = sanitizeScore(healthInsights?.nutritionalAdequacyScore)
                let feedingScore = sanitizeScore(healthInsights?.feedingConsistencyScore)
                
                // Health Score Card
                AnalyticsSummaryCard(
                    title: "Health Score",
                    value: healthScore,
                    unit: "/100",
                    icon: "heart.fill",
                    color: healthScoreColor(healthScore)
                )

                // Nutritional Balance Card
                AnalyticsSummaryCard(
                    title: "Nutritional Balance",
                    value: nutritionalScore,
                    unit: "%",
                    icon: "leaf.fill",
                    color: scoreColor(nutritionalScore)
                )

                // Feeding Consistency Card
                AnalyticsSummaryCard(
                    title: "Feeding Consistency",
                    value: feedingScore,
                    unit: "%",
                    icon: "clock.fill",
                    color: scoreColor(feedingScore)
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
     * Sanitize score values to prevent NaN or infinite values
     * Returns 0 for any invalid values (NaN, infinite, negative)
     */
    private func sanitizeScore(_ score: Double?) -> Double {
        guard let score = score else { return 0.0 }
        if score.isNaN || score.isInfinite || score < 0 {
            return 0.0
        }
        return min(100.0, score) // Cap at 100
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
            
            // CRITICAL: Ensure trends data is loaded first (with improved fallback logic)
            // This ensures nutritional balance score is calculated correctly
            do {
                try await trendsService.loadTrendsData(for: petId, period: .thirtyDays, forceRefresh: false)
            } catch {
                print("⚠️ [AdvancedAnalyticsView] Failed to load trends data: \(error.localizedDescription)")
                // Continue anyway - will use fallback calculation
            }
            
            do {
                // Fetch data from API in parallel for better performance
                async let insightsTask = analyticsService.fetchHealthInsights(petId: petId)
                async let patternsTask = analyticsService.fetchNutritionalPatterns(petId: petId)
                
                // Wait for both API calls to complete
                let insights = try await insightsTask
                let patterns = try await patternsTask
                
                await MainActor.run {
                    // CRITICAL: Override nutritionalAdequacyScore with trends service value
                    // This ensures we use the improved fallback logic (food name matching)
                    let trendsBalance = trendsService.nutritionalBalanceScore(for: petId)
                    if trendsBalance > 0 {
                        // Create updated insights with correct nutritional balance
                        let updatedInsights = HealthInsights(
                            petId: insights.petId,
                            analysisDate: insights.analysisDate,
                            weightManagementStatus: insights.weightManagementStatus,
                            nutritionalAdequacyScore: trendsBalance, // Use trends service value
                            feedingConsistencyScore: insights.feedingConsistencyScore,
                            healthRisks: insights.healthRisks,
                            positiveIndicators: insights.positiveIndicators,
                            recommendations: insights.recommendations,
                            overallHealthScore: insights.overallHealthScore
                        )
                        self.healthInsights = updatedInsights
                    } else {
                        self.healthInsights = insights
                    }
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
     * Falls back to trends service if daily summaries don't have valid compatibility scores
     */
    private func calculateNutritionalScore(dailySummaries: [DailyNutritionSummary], petId: String) -> Double {
        // First try to use trends service (which has the improved fallback logic)
        let trendsBalance = trendsService.nutritionalBalanceScore(for: petId)
        if trendsBalance > 0 {
            return trendsBalance
        }
        
        // Fallback to daily summaries if trends service doesn't have data
        guard !dailySummaries.isEmpty else { return 0.0 }
        
        let avgCompatibility = dailySummaries.map { $0.averageCompatibility }.reduce(0, +) / Double(dailySummaries.count)
        
        // Only use daily summaries if they have valid scores (not all zeros)
        if avgCompatibility > 0 {
            return avgCompatibility
        }
        
        // If daily summaries are all zeros, return 0 (trends service already returned 0)
        return 0.0
    }
    
    /**
     * Calculate feeding consistency score
     * Measures how consistently the pet is being fed over the analysis period
     * Score is based on:
     * - Number of days with feedings vs. total days
     * - Minimum 2 feeding records required for meaningful analysis
     */
    private func calculateConsistencyScore(feedingRecords: [FeedingRecord]) -> Double {
        // Need at least 2 records to calculate consistency
        guard feedingRecords.count >= 2 else {
            print("⚠️ [calculateConsistencyScore] Not enough records: \(feedingRecords.count), need at least 2")
            return 0.0
        }
        
        // Get unique days with feedings
        let daysWithFeedings = Set(feedingRecords.map { Calendar.current.startOfDay(for: $0.feedingTime) })
        
        // Calculate the date range of the feeding records
        let sortedDates = feedingRecords.map { $0.feedingTime }.sorted()
        guard let firstDate = sortedDates.first, let lastDate = sortedDates.last else {
            print("⚠️ [calculateConsistencyScore] Could not determine date range")
            return 0.0
        }
        
        // Calculate total days in the analysis period
        let calendar = Calendar.current
        let daysBetween = calendar.dateComponents([.day], from: calendar.startOfDay(for: firstDate), to: calendar.startOfDay(for: lastDate)).day ?? 0
        let totalDays = max(1, daysBetween + 1) // +1 to include both first and last day
        
        // Calculate consistency percentage
        let consistency = Double(daysWithFeedings.count) / Double(totalDays)
        let score = consistency * 100
        
        print("✅ [calculateConsistencyScore] Score: \(score)% (\(daysWithFeedings.count) days with feedings out of \(totalDays) total days)")
        
        return score
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
     * Uses food names directly from feeding records (which include food_name from API)
     */
    private func extractPreferredFoods(feedingRecords: [FeedingRecord]) -> [String] {
        guard !feedingRecords.isEmpty else { return [] }
        
        // Group records by food name (use foodName from record, fallback to foodAnalysisId lookup)
        // This ensures we count by actual food name, not just ID
        var foodCounts: [String: (count: Int, foodName: String, foodBrand: String?)] = [:]
        
        for record in feedingRecords {
            // Get food name from record if available
            let foodName: String
            let foodBrand: String?
            
            if let recordFoodName = record.foodName, !recordFoodName.isEmpty {
                // Use food name from record (already populated by API)
                foodName = recordFoodName
                foodBrand = record.foodBrand
            } else {
                // Fallback: try to get name from cached service
                if let foodAnalysis = cachedNutritionService.foodAnalyses.first(where: { $0.id == record.foodAnalysisId }) {
                    foodName = foodAnalysis.foodName
                    foodBrand = foodAnalysis.brand
                } else {
                    // Last resort: use foodAnalysisId (shouldn't happen if API is working correctly)
                    foodName = record.foodAnalysisId
                    foodBrand = nil
                }
            }
            
            // Use lowercase food name as key for grouping (case-insensitive)
            let foodKey = foodName.lowercased()
            
            // Update count and store display name
            if let existing = foodCounts[foodKey] {
                foodCounts[foodKey] = (
                    count: existing.count + 1,
                    foodName: foodName, // Keep original casing
                    foodBrand: foodBrand ?? existing.foodBrand
                )
            } else {
                foodCounts[foodKey] = (
                    count: 1,
                    foodName: foodName,
                    foodBrand: foodBrand
                )
            }
        }
        
        // Sort by frequency and get top 3
        let topFoods = foodCounts.sorted { $0.value.count > $1.value.count }.prefix(3)
        
        // Build preferred foods list with proper names
        var preferredFoods: [String] = []
        for (_, foodData) in topFoods {
            // Skip if we only have an ID (shouldn't happen, but safety check)
            if foodData.foodName.count == 36 && foodData.foodName.contains("-") {
                // Looks like a UUID - try one more time to get name from cache
                if let record = feedingRecords.first(where: { $0.foodAnalysisId == foodData.foodName }),
                   let recordFoodName = record.foodName, !recordFoodName.isEmpty {
                    // Use food name from the record
                    if let brand = record.foodBrand, !brand.isEmpty {
                        preferredFoods.append("\(recordFoodName) (\(brand))")
                    } else {
                        preferredFoods.append(recordFoodName)
                    }
                    continue
                }
                // Skip IDs - don't show them to users
                continue
            }
            
            // Add brand if available for better context
            if let brand = foodData.foodBrand, !brand.isEmpty {
                preferredFoods.append("\(foodData.foodName) (\(brand))")
            } else {
                preferredFoods.append(foodData.foodName)
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
                        // CRITICAL: Sanitize numeric value to prevent display issues
                        let safeValue = numericValue.isNaN || numericValue.isInfinite ? 0 : numericValue
                        
                        // Display numeric value with unit
                        Text("\(Int(safeValue))")
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
                if let numericValue = value as? Double, numericValue >= 0 && numericValue <= 100, !numericValue.isNaN, !numericValue.isInfinite {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color.opacity(0.2))
                                .frame(height: 4)
                            
                            // Progress fill - CRITICAL: Sanitize width calculation to prevent NaN
                            let safeWidth = max(0, min(geometry.size.width, geometry.size.width * CGFloat(numericValue / 100)))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(
                                    width: safeWidth.isNaN || safeWidth.isInfinite ? 0 : safeWidth,
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

// MARK: - Insights & Recommendations Card

/**
 * Insights and Recommendations Card
 * Displays recommended daily calories, weight, and insights for a pet
 */
private struct InsightsCard: View {
    let insights: [String]
    let pet: Pet
    
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Insights & Recommendations")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            LazyVStack(spacing: ModernDesignSystem.Spacing.md) {
                // Daily Calories with explicit RER and MER labels
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "flame.fill")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Calories")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            
                            // MER (Maintenance Energy Requirement)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("MER:")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                
                                Text(formatCalories(maintenanceEnergyRequirement))
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                    .fontWeight(.bold)
                            }
                            
                            // RER (Resting Energy Requirement)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("RER:")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                
                                Text(formatCalories(restingEnergyRequirement))
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                    .fontWeight(.bold)
                                
                                Text("× \(String(format: "%.1f", calorieMultiplier))")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    .fontWeight(.bold)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(ModernDesignSystem.Spacing.sm)
                .background(Color.white.opacity(0.5))
                .cornerRadius(ModernDesignSystem.CornerRadius.small)
                
                // Recommended Weight
                RecommendationRow(
                    icon: "scalemass.fill",
                    iconColor: ModernDesignSystem.Colors.primary,
                    title: "Recommended Weight",
                    value: formatWeight(recommendedWeight)
                )
                
                // Educational insights about MER and RER
                HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MER (Maintenance Energy Requirement)")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            .fontWeight(.semibold)
                        
                        Text("The total daily calories your pet needs based on their activity level, life stage, and weight goals.")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
                
                HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .padding(.top, 2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RER (Resting Energy Requirement)")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            .fontWeight(.semibold)
                        
                        Text("The baseline calories your pet needs at rest. MER is calculated by multiplying RER by an activity factor.")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                }
                
                // Existing insights
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
    
    // MARK: - Computed Properties
    
    /**
     * Calculate RER (Resting Energy Requirement)
     * This is the baseline calories the pet needs at rest
     * Formula: RER = 70 × (body weight in kg)^0.75
     */
    private var restingEnergyRequirement: Double {
        // Get weight for calculation (current weight or default)
        let weightKg: Double
        if let weight = pet.weightKg, weight > 0 {
            weightKg = weight
        } else {
            // Use species-appropriate default
            weightKg = pet.species == .cat ? 4.0 : 20.0
        }
        
        return 70.0 * pow(weightKg, 0.75)
    }
    
    /**
     * Calculate MER (Maintenance Energy Requirement)
     * This is the actual daily calories needed based on activity, life stage, etc.
     * Formula: MER = RER × species/life stage/activity multiplier
     */
    private var maintenanceEnergyRequirement: Double {
        let requirements = PetNutritionalRequirements.calculate(for: pet)
        return requirements.dailyCalories
    }
    
    /**
     * Calculate the multiplier being applied to RER
     * This shows the factor applied for life stage, activity level, etc.
     */
    private var calorieMultiplier: Double {
        guard restingEnergyRequirement > 0 else { return 1.0 }
        return maintenanceEnergyRequirement / restingEnergyRequirement
    }
    
    /// Legacy property for backward compatibility
    private var recommendedCalories: Double {
        return maintenanceEnergyRequirement
    }
    
    /// Calculate recommended weight based on species, age, and breed
    private var recommendedWeight: Double {
        calculateRecommendedWeight(for: pet)
    }
    
    // MARK: - Helper Methods
    
    private func formatCalories(_ calories: Double) -> String {
        "\(Int(calories)) kcal/day"
    }
    
    private func formatWeight(_ weightKg: Double) -> String {
        unitService.formatWeight(weightKg)
    }
    
    /// Calculate recommended weight range based on species, age, and breed
    private func calculateRecommendedWeight(for pet: Pet) -> Double {
        let ageMonths = pet.ageMonths ?? 0
        
        switch pet.species {
        case .dog:
            return calculateRecommendedDogWeight(ageMonths: ageMonths, breed: pet.breed)
        case .cat:
            return calculateRecommendedCatWeight(ageMonths: ageMonths)
        }
    }
    
    /// Calculate recommended weight for dogs based on age and breed size
    private func calculateRecommendedDogWeight(ageMonths: Int, breed: String?) -> Double {
        let breedSize = estimateBreedSize(breed: breed)
        
        if ageMonths < 12 {
            return calculatePuppyWeight(ageMonths: ageMonths, breedSize: breedSize)
        }
        
        switch breedSize {
        case .small:
            return 5.0
        case .medium:
            return 15.0
        case .large:
            return 30.0
        case .giant:
            return 50.0
        }
    }
    
    /// Calculate recommended weight for cats based on age
    private func calculateRecommendedCatWeight(ageMonths: Int) -> Double {
        if ageMonths < 12 {
            let adultWeight = 4.5
            return min(0.5 + (Double(ageMonths) / 12.0) * (adultWeight - 0.5), adultWeight)
        }
        return 4.5
    }
    
    /// Estimate breed size category for dogs
    private func estimateBreedSize(breed: String?) -> DogBreedSize {
        guard let breed = breed?.lowercased() else {
            return .medium
        }
        
        let smallBreeds = ["chihuahua", "yorkie", "yorkshire", "pomeranian", "maltese", "shih tzu", "pug", "dachshund", "beagle", "corgi", "jack russell"]
        let largeBreeds = ["labrador", "golden retriever", "german shepherd", "rottweiler", "boxer", "doberman", "husky", "border collie", "australian shepherd"]
        let giantBreeds = ["great dane", "mastiff", "st. bernard", "newfoundland", "bernese mountain", "irish wolfhound"]
        
        if smallBreeds.contains(where: { breed.contains($0) }) {
            return .small
        } else if largeBreeds.contains(where: { breed.contains($0) }) {
            return .large
        } else if giantBreeds.contains(where: { breed.contains($0) }) {
            return .giant
        }
        
        return .medium
    }
    
    /// Calculate expected weight for puppies based on age and breed size
    private func calculatePuppyWeight(ageMonths: Int, breedSize: DogBreedSize) -> Double {
        let adultWeight: Double
        switch breedSize {
        case .small:
            adultWeight = 7.5
        case .medium:
            adultWeight = 17.5
        case .large:
            adultWeight = 32.5
        case .giant:
            adultWeight = 55.0
        }
        
        let growthFactor: Double
        if ageMonths < 4 {
            growthFactor = 0.5 * (Double(ageMonths) / 4.0)
        } else if ageMonths < 8 {
            growthFactor = 0.5 + 0.25 * (Double(ageMonths - 4) / 4.0)
        } else {
            growthFactor = 0.75 + 0.15 * (Double(ageMonths - 8) / 4.0)
        }
        
        return adultWeight * growthFactor
    }
}

/// Dog breed size categories for weight estimation
private enum DogBreedSize {
    case small
    case medium
    case large
    case giant
}

/// Recommendation row component for displaying calorie and weight recommendations
private struct RecommendationRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(iconColor)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text(value)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    AdvancedNutritionView()
        .environmentObject(AuthService.shared)
}
