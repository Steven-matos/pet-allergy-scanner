//
//  WeightManagementView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import Charts
import Darwin

/**
 * Weight Management View
 * 
 * Comprehensive weight tracking and management interface with support for:
 * - Weight recording and history
 * - Goal setting and tracking
 * - Trend analysis and visualization
 * - Progress monitoring and recommendations
 * 
 * SwiftUI Best Practices:
 * - Uses @StateObject for observable objects owned by this view
 * - Uses @EnvironmentObject for injected dependencies
 * - Uses @State for view-local state only
 * - Computed properties for derived values
 * - ViewBuilder for conditional content
 * - Proper lifecycle management (onAppear/onDisappear)
 * 
 * Follows SOLID principles with single responsibility for weight management
 * Implements DRY by reusing common UI components
 * Follows KISS by keeping the interface intuitive and focused
 */
struct WeightManagementView: View {
    // MARK: - Dependencies (Injected or Shared)
    
    @EnvironmentObject var authService: AuthService
    @StateObject private var weightService = CachedWeightTrackingService.shared
    @StateObject private var syncService = WeightDataSyncService.shared
    @StateObject private var petSelectionService = NutritionPetSelectionService.shared
    
    // Note: petService is intentionally @State (not @StateObject) because it's a shared singleton
    @State private var petService = CachedPetService.shared
    
    // MARK: - View State
    
    @State private var showingWeightEntry = false
    @State private var showingGoalSetting = false
    @State private var showingAllWeightEntries = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    // Removed refreshTrigger - it was causing infinite re-render loops
    // SwiftUI will automatically update when @Published properties in weightService change
    @State private var lastRecordedWeightId: String?
    @State private var showingUndoToast = false
    @State private var loadTask: Task<Void, Never>?
    @State private var onAppearTask: Task<Void, Never>?
    @State private var lastAppearTime: Date?
    
    // MARK: - Computed Properties
    
    private var selectedPet: Pet? {
        petSelectionService.selectedPet
    }
    
    var body: some View {
        ZStack {
            // Main content
            if isLoading {
                ModernLoadingView(message: "Loading weight data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false) // Prevent touches on loading view
            } else if let pet = selectedPet {
                weightManagementContent(for: pet)
            } else {
                petSelectionView
            }
        }
        .background(ModernDesignSystem.Colors.background)
        .sheet(isPresented: $showingWeightEntry) {
            if let pet = selectedPet {
                WeightEntryView(pet: pet, lastRecordedWeightId: $lastRecordedWeightId)
                    .onDisappear {
                        // Weight was added - refresh data from server to get latest
                        // This is the only time we need to fetch from server (after user action)
                        // Use Task to avoid blocking
                        Task { @MainActor in
                            await loadWeightDataAsync(showLoadingIfNeeded: false, forceRefresh: true)
                            // Don't toggle refreshTrigger - SwiftUI will update automatically
                        }
                        
                        // Trends will be automatically refreshed via invalidateTrendsCache with autoReload
                        // (handled in CachedWeightTrackingService.recordWeight)
                    }
            }
        }
        .sheet(isPresented: $showingAllWeightEntries) {
            if let pet = selectedPet {
                AllWeightEntriesView(pet: pet)
            }
        }
        .sheet(isPresented: $showingGoalSetting) {
            if let pet = selectedPet {
                WeightGoalSettingView(pet: pet, existingGoal: nil)
                    .onDisappear {
                        // Goal was set/updated - refresh data from server to get latest
                        // This is the only time we need to fetch from server (after user action)
                        // Use Task to avoid blocking
                        Task { @MainActor in
                            await loadWeightDataAsync(showLoadingIfNeeded: false, forceRefresh: true)
                            // Don't toggle refreshTrigger - SwiftUI will update automatically
                        }
                    }
            }
        }
        .onAppear {
            // CRITICAL: Debounce rapid tab switches to prevent freezing
            let now = Date()
            if let lastAppear = lastAppearTime, now.timeIntervalSince(lastAppear) < 0.5 {
                // If appeared within last 0.5 seconds, skip to prevent rapid successive loads
                print("⏭️ WeightManagementView: Skipping onAppear (too soon after last appear)")
                return
            }
            lastAppearTime = now
            
            // Cancel any existing onAppear task first
            onAppearTask?.cancel()
            onAppearTask = nil
            
            // Create a single task for all onAppear operations
            onAppearTask = Task(priority: .userInitiated) { @MainActor in
                guard !Task.isCancelled else { return }
                
                // Track analytics (dispatch asynchronously to prevent blocking) - don't capture self
                let petId = selectedPet?.id
                Task.detached(priority: .utility) { @MainActor in
                    PostHogAnalytics.trackWeightManagementViewOpened(petId: petId)
                }
                
                // Load pets asynchronously to prevent blocking UI
                petService.loadPets()
                
                // Yield to allow UI to render first
                await Task.yield()
                guard !Task.isCancelled else { return }
                
                // Auto-select pet if needed
                if selectedPet == nil, !petService.pets.isEmpty, let firstPet = petService.pets.first {
                    petSelectionService.selectPet(firstPet)
                }
                
                // Yield again after auto-select
                await Task.yield()
                guard !Task.isCancelled else { return }
                
                // Weight data is static - use cached data exclusively
                // No server calls on view appearance since data only changes when:
                // 1. User adds/deletes weight entry (handled by sheet onDisappear)
                // 2. User sets/updates goal (handled by sheet onDisappear)
                // 3. User pulls to refresh (explicit user action)
                guard let pet = selectedPet ?? petService.pets.first else { return }
                
                // Check if we have cached data - if not, load it (cache-first, no server call if cached)
                // loadWeightData with forceRefresh: false will use cache if available
                if !weightService.hasCachedWeightData(for: pet.id) {
                    // Cancel any existing load task
                    loadTask?.cancel()
                    loadTask = nil
                    
                    // First time - load data (will use cache if available, only calls server if no cache)
                    // Use Task with MainActor to ensure UI updates work correctly
                    loadTask = Task { @MainActor in
                        // Yield immediately to allow view to render first - critical for preventing UI freeze
                        await Task.yield()
                        
                        // Check if task was cancelled (e.g., view disappeared)
                        guard !Task.isCancelled else { return }
                        
                        // Prevent multiple simultaneous loads
                        guard !isLoading else { return }
                        
                        // Set loading state with timeout protection
                        isLoading = true
                        
                        // Add timeout to prevent isLoading from getting stuck
                        let loadStartTime = Date()
                        let timeoutTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                            guard !Task.isCancelled else { return }
                            if isLoading {
                                let freezeDuration = Date().timeIntervalSince(loadStartTime)
                                print("⚠️ Weight data load timeout - resetting isLoading")
                                // Track UI freeze in PostHog
                                PostHogAnalytics.trackUIFreeze(
                                    viewName: "WeightManagementView",
                                    duration: freezeDuration,
                                    action: "loadWeightData"
                                )
                                PostHogAnalytics.trackError(
                                    error: "Weight data load timeout after \(Int(freezeDuration))s",
                                    context: "WeightManagementView.loadWeightData",
                                    severity: "high"
                                )
                                isLoading = false
                            }
                        }
                        
                        defer {
                            timeoutTask.cancel()
                            // CRITICAL: Only update state if task wasn't cancelled
                            if !Task.isCancelled {
                                isLoading = false
                            }
                        }
                        
                        do {
                            // forceRefresh: false means it will use cache if available
                            try await weightService.loadWeightData(for: pet.id, forceRefresh: false)
                            
                        // Don't toggle refreshTrigger - it causes view recreation
                        // SwiftUI will automatically update when weightService @Published properties change
                        } catch {
                            // Handle error gracefully - don't crash the app
                            guard !Task.isCancelled else { return }
                            print("⚠️ Failed to load weight data: \(error.localizedDescription)")
                            // Don't set errorMessage here to avoid blocking UI
                        }
                    }
                }
                // If we have cached data, it's already in memory - no action needed
                
                // Note: Sync service is disabled since weight data is static
                // We don't need periodic syncing - data only changes on user actions
            }
        }
        .onDisappear {
            // CRITICAL: Cancel all ongoing tasks to prevent state updates after view disappears
            // Cancel in reverse order of creation to ensure proper cleanup
            loadTask?.cancel()
            loadTask = nil
            onAppearTask?.cancel()
            onAppearTask = nil
            
            // Reset loading state to prevent stuck UI
            // Only reset if view is still accessible (safety check)
            isLoading = false
            
            // Sync service is disabled, but clean up just in case
            if let pet = selectedPet {
                syncService.stopSyncing(forPetId: pet.id)
            }
        }
        .onChange(of: selectedPet) { oldPet, newPet in
            // Cancel any ongoing load tasks when pet changes
            loadTask?.cancel()
            loadTask = nil
            
            // Reset loading state when pet changes
            isLoading = false
            
            // Sync service is disabled, but clean up just in case
            if let oldPet = oldPet {
                syncService.stopSyncing(forPetId: oldPet.id)
            }
            // Don't toggle refreshTrigger - it causes view recreation and potential loops
            // SwiftUI will automatically update when weightService @Published properties change
        }
        .refreshable {
            // Pull to refresh weight data
            await refreshWeightData()
        }
        .onChange(of: lastRecordedWeightId) { oldValue, newValue in
            // Show undo toast when a weight is recorded
            if newValue != nil {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showingUndoToast = true
                }
                
                // Auto-hide undo toast after 5 seconds
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingUndoToast = false
                        lastRecordedWeightId = nil
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            // Undo toast for recently recorded weight
            if showingUndoToast {
                undoToastView
                    .padding(.bottom, 100)
                    .zIndex(1000) // Ensure toast appears above all other content
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            }
        }
    }
    
    // MARK: - Undo Toast View
    
    private var undoToastView: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(ModernDesignSystem.Typography.title3)
            
            Text("Weight recorded")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Button {
                undoLastWeight()
            } label: {
                Text("UNDO")
                    .font(ModernDesignSystem.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
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
            color: ModernDesignSystem.Shadows.medium.color,
            radius: ModernDesignSystem.Shadows.medium.radius,
            x: ModernDesignSystem.Shadows.medium.x,
            y: ModernDesignSystem.Shadows.medium.y
        )
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
    }
    
    // MARK: - Pet Selection View
    
    private var petSelectionView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Select a Pet")
                .font(ModernDesignSystem.Typography.title2)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text("Choose a pet to view weight management data")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            if !petService.pets.isEmpty {
                LazyVStack(spacing: ModernDesignSystem.Spacing.md) {
                    ForEach(petService.pets) { pet in
                        PetSelectionCard(pet: pet, onTap: {
                            petSelectionService.selectPet(pet)
                            // Load weight data with cache-first pattern when pet is selected
                            loadWeightDataIfNeeded()
                        })
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
    
    // MARK: - Weight Management Content
    
    @ViewBuilder
    private func weightManagementContent(for pet: Pet) -> some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Current Weight Card
                // CRITICAL: Always use weightService.currentWeight(for:) instead of pet.weightKg
                // pet.weightKg may be stale from cache, but currentWeight is always fresh
                CurrentWeightCard(
                    pet: pet,
                    currentWeight: weightService.currentWeight(for: pet.id) ?? pet.weightKg,
                    weightGoal: weightService.activeWeightGoal(for: pet.id)
                )
                // Remove .id() modifier - it causes view recreation and potential infinite loops
                // SwiftUI will automatically update when @Published properties change
                
                // Weight Trend Chart
                // Limit data points on older devices to prevent freezing
                let weightHistory = weightService.weightHistory(for: pet.id)
                let maxPoints = DevicePerformanceHelper.maxChartDataPoints
                let limitedHistory = Array(weightHistory.prefix(maxPoints))
                
                if !limitedHistory.isEmpty {
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {                        
                        WeightTrendChart(
                            weightHistory: limitedHistory,
                            petName: pet.name,
                            pet: pet  // Pass pet for background image
                        )
                    }
                }
                
                // Goal Progress
                if let goal = weightService.activeWeightGoal(for: pet.id) {
                    GoalProgressCard(
                        goal: goal, 
                        currentWeight: weightService.currentWeight(for: pet.id) ?? pet.weightKg, 
                        pet: pet
                    )
                    // Remove .id() modifier - it causes view recreation and potential infinite loops
                    // SwiftUI will automatically update when @Published properties change
                } else {
                    // No goal set - show "Set Goal" card
                    SetGoalCard(pet: pet)
                }
                
                // Recent Weight Entries
                RecentWeightEntriesCard(
                    pet: pet,
                    weightHistory: weightService.weightHistory(for: pet.id),
                    onViewAll: {
                        showingAllWeightEntries = true
                    }
                )
                
                // Recommendations
                if !weightService.recommendations(for: pet.id).isEmpty {
                    RecommendationsCard(recommendations: weightService.recommendations(for: pet.id))
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        .background(ModernDesignSystem.Colors.background)
        .refreshable {
            await loadWeightDataAsync()
        }
    }
    
    // MARK: - Helper Methods
    
    /**
     * Load weight data only when needed
     * 
     * Weight data is static and only changes when:
     * - User adds/deletes a weight entry
     * - User sets/updates a goal
     * - User explicitly refreshes (pull to refresh)
     * 
     * This method should only be called:
     * - First time viewing (no cached data)
     * - After adding/deleting weight entry
     * - After setting/updating goal
     * - On explicit user refresh
     */
    private func loadWeightDataIfNeeded() {
        guard isLoading == false else {
            print("⏭️ Weight data load already in progress, skipping")
            return
        }
        
        guard let pet = selectedPet ?? petService.pets.first else { return }
        
        // Check if we have cached data
        let hasCachedData = weightService.hasCachedWeightData(for: pet.id)
        
        if !hasCachedData {
            // No cache - load from server
            isLoading = true
            
            // Add timeout protection to prevent isLoading from getting stuck
            let loadStartTime = Date()
            let timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                if isLoading {
                    let freezeDuration = Date().timeIntervalSince(loadStartTime)
                    print("⚠️ Weight data load timeout in loadWeightDataIfNeeded - resetting isLoading")
                    // Track UI freeze in PostHog
                    PostHogAnalytics.trackUIFreeze(
                        viewName: "WeightManagementView",
                        duration: freezeDuration,
                        action: "loadWeightDataIfNeeded"
                    )
                    PostHogAnalytics.trackError(
                        error: "Weight data load timeout after \(Int(freezeDuration))s",
                        context: "WeightManagementView.loadWeightDataIfNeeded",
                        severity: "high"
                    )
                    isLoading = false
                }
            }
            
            Task { @MainActor in
                defer {
                    timeoutTask.cancel()
                    isLoading = false
                }
                
                do {
                    try await weightService.loadWeightData(for: pet.id, forceRefresh: false)
                    // Don't toggle refreshTrigger - SwiftUI will update automatically
                } catch {
                    print("⚠️ Failed to load weight data: \(error.localizedDescription)")
                }
            }
        }
        // If we have cached data, it's already in memory - no action needed
    }
    
    
    /**
     * Force load weight data from server
     * Only called when data actually changes:
     * - After adding/deleting weight entry
     * - After setting/updating goal
     * - On explicit user refresh (pull to refresh)
     */
    private func loadWeightData(forceRefresh: Bool = true) {
        guard selectedPet != nil || !petService.pets.isEmpty else { return }
        
        // Cancel any existing load task
        loadTask?.cancel()
        
        loadTask = Task {
            await loadWeightDataAsync(showLoadingIfNeeded: true, forceRefresh: forceRefresh)
        }
    }
    
    private func loadWeightDataAsync(showLoadingIfNeeded: Bool = false, forceRefresh: Bool = false) async {
        guard let pet = selectedPet ?? petService.pets.first else { return }
        
        // Check if we already have data in memory (from cache or previous load) - synchronous
        let hadDataBefore = weightService.hasCachedWeightData(for: pet.id)
        
        // Only show loading if explicitly requested and we don't have data (or force refresh)
        var timeoutTask: Task<Void, Never>?
        
        if showLoadingIfNeeded && (!hadDataBefore || forceRefresh) {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            
            // Add timeout protection to prevent isLoading from getting stuck
            timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
                if isLoading {
                    print("⚠️ Weight data load timeout in loadWeightDataAsync - resetting isLoading")
                    isLoading = false
                }
            }
        }
        
        defer {
            timeoutTask?.cancel()
        }
        
        do {
            // Load data (cache-first, but refresh goals from server if needed)
            // Use forceRefresh when explicitly requested (e.g., after adding new data)
            try await weightService.loadWeightData(for: pet.id, forceRefresh: forceRefresh)
            
            // Check if task was cancelled before updating UI
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isLoading = false
                // Don't toggle refreshTrigger - SwiftUI will update automatically
            }
        } catch {
            // Handle 404 errors gracefully
            if let apiError = error as? APIError,
               case .serverError(let statusCode) = apiError,
               statusCode == 404 {
                // Resource deleted - cache already invalidated by service
                print("⚠️ Weight data resource deleted (404) - cache invalidated")
            }
            
            // Only update UI if task wasn't cancelled
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    /**
     * Force refresh weight data from server (bypasses cache)
     * Used for pull-to-refresh gesture
     */
    private func refreshWeightData() async {
        guard let pet = selectedPet else { return }
        
        do {
            // Force refresh from server
            try await weightService.refreshWeightData(petId: pet.id)
            
            // Don't toggle refreshTrigger - SwiftUI will update automatically when service updates
        } catch {
            await MainActor.run {
                errorMessage = "Failed to refresh weight data: \(error.localizedDescription)"
            }
        }
    }
    
    /**
     * Undo the last recorded weight
     * Deletes the record and updates pet weight to previous value
     */
    private func undoLastWeight() {
        guard let weightId = lastRecordedWeightId, let pet = selectedPet else {
            return
        }
        
        // Hide the undo toast immediately
        withAnimation {
            showingUndoToast = false
        }
        
        Task {
            do {
                // Call the delete API
                try await weightService.deleteWeightRecord(recordId: weightId)
                
                // Refresh the data
                try await weightService.loadWeightData(for: pet.id, forceRefresh: true)
                
                // Refresh pet data to get updated weight
                await MainActor.run {
                    petService.loadPets(forceRefresh: true)
                }
                
                // Wait for refresh
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Update selected pet
                if let updatedPet = petService.pets.first(where: { $0.id == pet.id }) {
                    await MainActor.run {
                        NutritionPetSelectionService.shared.selectPet(updatedPet)
                    }
                }
                
                // Update state - SwiftUI will refresh automatically
                await MainActor.run {
                    lastRecordedWeightId = nil
                }
            } catch {
                // Show error to user
                await MainActor.run {
                    errorMessage = "Failed to undo: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Supporting Views


struct CurrentWeightCard: View {
    let pet: Pet
    let currentWeight: Double?
    let weightGoal: WeightGoal?
    @State private var showingGoalEdit = false
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Text("Current Weight")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if let weight = currentWeight {
                    Text(unitService.formatWeight(weight))
                        .font(ModernDesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                } else {
                    Text("Not recorded")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            
            if let goal = weightGoal {
                HStack {
                    Text("Goal: \(unitService.formatWeight(goal.targetWeightKg ?? 0))")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        if let current = currentWeight, let target = goal.targetWeightKg {
                            let progress = (current / target) * 100
                            Text("\(progress, specifier: "%.0f")%")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .fontWeight(.medium)
                            .foregroundColor(progress >= 95 && progress <= 105 ? 
                                ModernDesignSystem.Colors.primary : 
                                ModernDesignSystem.Colors.goldenYellow)
                        }
                        
                        Button(action: {
                            showingGoalEdit = true
                        }) {
                            Image(systemName: "pencil")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.buttonPrimary)
                        }
                    }
                }
            } else {
                // No goal set - show "Set Goal" button
                HStack {
                    Text("No weight goal set")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Button(action: {
                        showingGoalEdit = true
                    }) {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "plus.circle.fill")
                                .font(ModernDesignSystem.Typography.caption)
                            Text("Set Goal")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(ModernDesignSystem.Colors.buttonPrimary)
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
        .sheet(isPresented: $showingGoalEdit) {
            WeightGoalSettingView(pet: pet, existingGoal: weightGoal)
        }
    }
}

/// Weight Trend Chart Component
///
/// Follows SwiftUI best practices:
/// - Uses `let` properties (immutable data)
/// - Minimizes re-renders by accepting only necessary data
/// - Uses StateObject for shared services
/// - Avoids unnecessary state management
struct WeightTrendChart: View {
    let weightHistory: [WeightRecord]
    let petName: String
    let pet: Pet
    
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    @State private var isChartReady = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Weight Trend")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            // Chart with pet image background
            chartContent
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    /// Chart content with background image
    /// Extracted as computed property for better readability
    @ViewBuilder
    private var chartContent: some View {
        ZStack {
            // Faded pet image background (disabled on older devices)
            if !DevicePerformanceHelper.shouldDisableChartBackgrounds {
                backgroundImage
            }
            
            // Chart overlay
            if isChartReady || !DevicePerformanceHelper.shouldDeferChartRendering {
                weightChart
            } else {
                // Placeholder while chart loads
                ProgressView()
                    .frame(height: 200)
            }
        }
        .onAppear {
            // Defer chart rendering on older devices to prevent freezing
            if DevicePerformanceHelper.shouldDeferChartRendering {
                Task { @MainActor in
                    // Wait for next run loop to allow view to render first
                    await Task.yield()
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                    if !Task.isCancelled {
                        isChartReady = true
                    }
                }
            } else {
                isChartReady = true
            }
        }
    }
    
    /// Background image based on pet species
    private var backgroundImage: some View {
        Image(pet.species == .dog ? "Illustrations/dog-scale" : "Illustrations/cat-scale")
            .resizable()
            .renderingMode(.original)
            .aspectRatio(contentMode: .fit)
            .frame(height: 120)
            .opacity(0.15)
            .offset(y: 20)
    }
    
    /// Weight chart with data visualization
    @ViewBuilder
    private var weightChart: some View {
        PerformanceOptimizer.optimizedChart {
            if #available(iOS 16.0, *) {
                let maxPoints = DevicePerformanceHelper.maxChartDataPoints
                let chartData = weightHistory.prefix(maxPoints)
                let useSimplified = DevicePerformanceHelper.shouldUseSimplifiedCharts
                
                Chart(chartData) { record in
                    // Area under the line (disabled on older devices for performance)
                    if !useSimplified {
                        AreaMark(
                            x: .value("Date", record.recordedAt),
                            y: .value("Weight", record.weightKg)
                        )
                        .foregroundStyle(ModernDesignSystem.Colors.primary.opacity(0.25))
                    }
                    
                    // Main line
                    LineMark(
                        x: .value("Date", record.recordedAt),
                        y: .value("Weight", record.weightKg)
                    )
                    .foregroundStyle(ModernDesignSystem.Colors.primary)
                    .lineStyle(StrokeStyle(lineWidth: useSimplified ? 2 : 3))
                    
                    // Data points (fewer/smaller on older devices)
                    if !useSimplified || chartData.count <= 10 {
                        PointMark(
                            x: .value("Date", record.recordedAt),
                            y: .value("Weight", record.weightKg)
                        )
                        .foregroundStyle(ModernDesignSystem.Colors.primary)
                        .symbolSize(useSimplified ? 40 : 80)
                        .symbol(.circle)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                            .foregroundStyle(ModernDesignSystem.Colors.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text(unitService.formatWeight(weight))
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                }
                .chartBackground { _ in
                    Color.clear
                }
            }
        }
    }
}

struct GoalProgressCard: View {
    let goal: WeightGoal
    let currentWeight: Double?
    let pet: Pet
    @State private var showingGoalEdit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Text("Goal Progress")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Text(goal.goalType.displayName)
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Button(action: {
                        showingGoalEdit = true
                    }) {
                        Image(systemName: "pencil")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.buttonPrimary)
                    }
                }
            }
            
            if let current = currentWeight, let target = goal.targetWeightKg {
                let progress = calculateProgress(current: current, target: target, goalType: goal.goalType)
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    HStack {
                        Text("Progress")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text("\(Int(progress * 100))%")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                    
                    // Enhanced progress visualization
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: progressColor(progress)))
                            .scaleEffect(y: 2) // Make progress bar thicker
                        
                        // Additional progress info
                        HStack {
                            Text("Goal Progress")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            
                            Spacer()
                            
                            if let startingWeight = goal.currentWeightKg {
                                let weightChange = current - startingWeight
                                let changeText = weightChange >= 0 ? "+\(String(format: "%.1f", weightChange))" : "\(String(format: "%.1f", weightChange))"
                                Text(changeText)
                                    .font(ModernDesignSystem.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(weightChange >= 0 ? 
                                        ModernDesignSystem.Colors.primary : 
                                        ModernDesignSystem.Colors.warmCoral)
                            }
                        }
                    }
                }
            } else {
                Text("Set a target weight to track progress")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
        .sheet(isPresented: $showingGoalEdit) {
            WeightGoalSettingView(pet: pet, existingGoal: goal)
        }
    }
    
    private func calculateProgress(current: Double, target: Double, goalType: WeightGoalType) -> Double {
        // Get the starting weight from the goal's currentWeightKg (weight when goal was set)
        let startingWeight: Double
        if let goalStartingWeight = goal.currentWeightKg {
            startingWeight = goalStartingWeight
        } else {
            // If no starting weight, use current weight as starting point
            startingWeight = current
        }
        
        switch goalType {
        case .weightLoss:
            // For weight loss, progress is how much weight has been lost from starting point
            let totalWeightToLose = startingWeight - target
            let weightLost = startingWeight - current
            guard totalWeightToLose > 0 else { 
                return 0.0 
            }
            
            // If no weight has been lost yet (current weight >= starting weight), show 0% progress
            if weightLost <= 0 {
                return 0.0
            }
            
            let progress = min(1.0, max(0.0, weightLost / totalWeightToLose))
            return progress
            
        case .weightGain:
            // For weight gain, progress is how much weight has been gained from starting point
            let totalWeightToGain = target - startingWeight
            let weightGained = current - startingWeight
            guard totalWeightToGain > 0 else { 
                return 0.0 
            }
            
            // If no weight has been gained yet (current weight <= starting weight), show 0% progress
            if weightGained <= 0 {
                return 0.0
            }
            
            let progress = min(1.0, max(0.0, weightGained / totalWeightToGain))
            return progress
            
        case .maintenance, .healthImprovement:
            // For maintenance, progress is how close to target (inverse of distance)
            let distanceFromTarget = abs(current - target)
            let maxDistance = max(abs(startingWeight - target), 1.0) // Avoid division by zero
            let progress = min(1.0, max(0.0, 1.0 - (distanceFromTarget / maxDistance)))
            return progress
        }
    }
    
    private func progressColor(_ progress: Double) -> Color {
        if progress >= 0.8 {
            return ModernDesignSystem.Colors.primary // Deep Forest Green for good progress
        } else if progress >= 0.5 {
            return ModernDesignSystem.Colors.goldenYellow // Golden Yellow for moderate progress
        } else {
            return ModernDesignSystem.Colors.warmCoral // Warm Coral for low progress
        }
    }
}

struct RecentWeightEntriesCard: View {
    let pet: Pet
    let weightHistory: [WeightRecord]
    let onViewAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Text("Recent Entries")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if weightHistory.count > 5 {
                    Button(action: onViewAll) {
                        Text("View All")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.buttonPrimary)
                    }
                }
            }
            
            if weightHistory.isEmpty {
                Text("No weight entries yet. Tap 'Add Weight' to get started.")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, ModernDesignSystem.Spacing.lg)
            } else {
                LazyVStack(spacing: ModernDesignSystem.Spacing.sm) {
                    ForEach(weightHistory.prefix(5)) { record in
                        WeightEntryRow(record: record, pet: pet)
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
}

struct WeightEntryRow: View {
    let record: WeightRecord
    let pet: Pet?
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    @StateObject private var weightService = CachedWeightTrackingService.shared
    @State private var showingDeleteAlert = false
    
    init(record: WeightRecord, pet: Pet? = nil) {
        self.record = record
        self.pet = pet
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(unitService.formatWeight(record.weightKg))
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(record.recordedAt, style: .relative)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            // Delete button (only show if pet is provided for context)
            if pet != nil {
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(ModernDesignSystem.Colors.error)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, ModernDesignSystem.Spacing.xs)
        .alert("Delete Weight Entry", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteWeightRecord()
            }
        } message: {
            Text("Are you sure you want to delete this weight entry? This action cannot be undone.")
        }
    }
    
    /**
     * Delete the weight record
     */
    private func deleteWeightRecord() {
        guard let pet = pet else { return }
        
        Task {
            do {
                try await weightService.deleteWeightRecord(recordId: record.id)
                
                // Refresh weight data
                try await weightService.loadWeightData(for: pet.id, forceRefresh: true)
                
                // Refresh pet data to get updated weight
                await MainActor.run {
                    CachedPetService.shared.loadPets(forceRefresh: true)
                }
            } catch {
                print("❌ Failed to delete weight record: \(error.localizedDescription)")
            }
        }
    }
}

struct EmptyWeightChartCard: View {
    let pet: Pet
    @State private var showingWeightEntry = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Text("Weight Trend")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
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
                }
            }
            
            VStack(alignment: .center, spacing: ModernDesignSystem.Spacing.lg) {
                // Chart placeholder with species-specific image
                ZStack {
                    // Background for the chart area
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                        .fill(ModernDesignSystem.Colors.lightGray)
                        .frame(height: 200)
                    
                    // Centered content
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        // Show species-specific scale image centered
                        Image(pet.species == .dog ? "Illustrations/dog-scale" : "Illustrations/cat-scale")
                            .resizable()
                            .renderingMode(.original)
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 140)
                        
                        Text("No weight data yet")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Text("Record your first weight to see trends and charts")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
        .sheet(isPresented: $showingWeightEntry) {
            WeightEntryView(pet: pet, lastRecordedWeightId: .constant(nil))
        }
    }
}

struct SetGoalCard: View {
    let pet: Pet
    @State private var showingGoalSetting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Text("Weight Goal")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button(action: {
                    showingGoalSetting = true
                }) {
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(ModernDesignSystem.Typography.caption)
                        Text("Set Goal")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(ModernDesignSystem.Colors.buttonPrimary)
                }
            }
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text("Set a weight goal to track your pet's progress")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text("• Weight loss goals")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text("• Weight gain goals")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text("• Maintenance goals")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
        .sheet(isPresented: $showingGoalSetting) {
            WeightGoalSettingView(pet: pet, existingGoal: nil)
        }
    }
}

struct RecommendationsCard: View {
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Recommendations")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            LazyVStack(spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warning)
                            .padding(.top, 2)
                        
                        Text(recommendation)
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
}

// MARK: - Weight Entry View

/**
 * Weight Entry View following Trust & Nature Design System
 * 
 * Features:
 * - Card-based layout with soft cream backgrounds
 * - Trust & Nature color palette throughout
 * - Consistent spacing and typography
 * - Professional, nature-inspired design
 * - Accessible form controls
 * 
 * Design System Compliance:
 * - Uses ModernDesignSystem for all styling
 * - Follows Trust & Nature color palette
 * - Implements consistent spacing scale
 * - Applies proper shadows and corner radius
 * - Maintains accessibility standards
 */
struct WeightEntryView: View {
    let pet: Pet
    @Binding var lastRecordedWeightId: String?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weightService = CachedWeightTrackingService.shared
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    @State private var weight: String = ""
    @State private var notes: String = ""
    @State private var isRecording = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // MARK: - Pet Information Card
                    petInformationCard
                    
                    // MARK: - Weight Information Card
                    weightInformationCard
                    
                    // MARK: - Notes Card
                    notesCard
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Record Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.red.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        recordWeight()
                    }
                    .disabled(weight.isEmpty || isRecording)
                    .foregroundColor(weight.isEmpty || isRecording ? ModernDesignSystem.Colors.textSecondary : ModernDesignSystem.Colors.primary)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
                .foregroundColor(ModernDesignSystem.Colors.primary)
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Pet Information Card
    private var petInformationCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Pet Information")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Pet Name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Pet Name")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        Image(systemName: pet.species.icon)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        Text(pet.name)
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.textSecondary.opacity(0.1))
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Current Weight (if available)
                // CRITICAL: Use weightService.currentWeight(for:) instead of pet.weightKg
                // pet.weightKg may be stale from cache, but currentWeight is always fresh
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Current Weight")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        if let currentWeight = weightService.currentWeight(for: pet.id) ?? pet.weightKg {
                            Text(unitService.formatWeight(currentWeight))
                                .font(ModernDesignSystem.Typography.body)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        } else {
                            Text("Not recorded")
                                .font(ModernDesignSystem.Typography.body)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.textSecondary.opacity(0.1))
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
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
    
    // MARK: - Weight Information Card
    private var weightInformationCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "scalemass.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Weight Information")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Weight Input
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Weight (\(unitService.getUnitSymbol()))")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        TextField("Enter weight", text: $weight)
                            .font(ModernDesignSystem.Typography.body)
                            .keyboardType(.decimalPad)
                            .modernInputField()
                        
                        Text(unitService.getUnitSymbol())
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .padding(.trailing, ModernDesignSystem.Spacing.sm)
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
    
    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Notes (Optional)")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Notes Input
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Add notes about this weight measurement")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Add notes about this weight measurement", text: $notes, axis: .vertical)
                        .font(ModernDesignSystem.Typography.body)
                        .lineLimit(3...6)
                        .modernInputField()
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
    
    private func recordWeight() {
        guard let weightValue = Double(weight), weightValue > 0 else {
            errorMessage = "Please enter a valid weight"
            return
        }
        
        isRecording = true
        
        Task {
            do {
                // Store weight directly in the selected unit (no conversion needed)
                let recordId = try await weightService.recordWeight(
                    petId: pet.id,
                    weight: weightValue,
                    notes: notes.isEmpty ? nil : notes
                )
                
                // Track analytics - convert to kg for tracking
                let weightInKg = unitService.convertToKg(weightValue)
                PostHogAnalytics.trackWeightRecorded(petId: pet.id, weightKg: weightInKg)
                
                await MainActor.run {
                    // Store the record ID for undo functionality
                    // Set this before dismissing to ensure binding propagates
                    lastRecordedWeightId = recordId
                    
                    // Small delay to ensure binding update propagates before dismiss
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRecording = false
                }
            }
        }
    }
}

// MARK: - Weight Goal Setting View

/**
 * Weight Goal Setting View following Trust & Nature Design System
 * 
 * Features:
 * - Card-based layout with soft cream backgrounds
 * - Trust & Nature color palette throughout
 * - Consistent spacing and typography
 * - Professional, nature-inspired design
 * - Accessible form controls
 * 
 * Design System Compliance:
 * - Uses ModernDesignSystem for all styling
 * - Follows Trust & Nature color palette
 * - Implements consistent spacing scale
 * - Applies proper shadows and corner radius
 * - Maintains accessibility standards
 */
struct WeightGoalSettingView: View {
    let pet: Pet
    let existingGoal: WeightGoal?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weightService = CachedWeightTrackingService.shared
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    @State private var goalType: WeightGoalType = .maintenance
    @State private var targetWeight: String = ""
    @State private var targetDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @State private var notes: String = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    private var isEditing: Bool {
        existingGoal != nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // MARK: - Pet Information Card
                    petInformationCard
                    
                    // MARK: - Goal Type Card
                    goalTypeCard
                    
                    // MARK: - Target Weight Card
                    targetWeightCard
                    
                    // MARK: - Target Date Card
                    targetDateCard
                    
                    // MARK: - Notes Card
                    notesCard
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle(isEditing ? "Edit Weight Goal" : "Set Weight Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.red.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createGoal()
                    }
                    .disabled(targetWeight.isEmpty || isCreating)
                    .foregroundColor(targetWeight.isEmpty || isCreating ? ModernDesignSystem.Colors.textSecondary : ModernDesignSystem.Colors.primary)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
                .foregroundColor(ModernDesignSystem.Colors.primary)
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                if let goal = existingGoal {
                    goalType = goal.goalType
                    // Convert goal weight from kg to selected unit for display
                    if let goalWeightKg = goal.targetWeightKg {
                        let convertedWeight = unitService.convertFromKg(goalWeightKg)
                        targetWeight = String(format: "%.1f", convertedWeight)
                    } else {
                        targetWeight = ""
                    }
                    targetDate = goal.targetDate ?? Date().addingTimeInterval(30 * 24 * 60 * 60)
                    notes = goal.notes ?? ""
                }
            }
        }
    }
    
    // MARK: - Pet Information Card
    private var petInformationCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Pet Information")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Pet Name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Pet Name")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        Image(systemName: pet.species.icon)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        Text(pet.name)
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.textSecondary.opacity(0.1))
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
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
    
    // MARK: - Goal Type Card
    private var goalTypeCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "target")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Goal Type")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Goal Type Picker
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Select the type of weight goal")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Picker("Goal Type", selection: $goalType) {
                        ForEach(WeightGoalType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
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
    
    // MARK: - Target Weight Card
    private var targetWeightCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "scalemass.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Target Weight")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Target Weight Input
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Target weight (\(unitService.getUnitSymbol()))")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        TextField("Enter target weight", text: $targetWeight)
                            .font(ModernDesignSystem.Typography.body)
                            .keyboardType(.decimalPad)
                            .modernInputField()
                        
                        Text(unitService.getUnitSymbol())
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .padding(.trailing, ModernDesignSystem.Spacing.sm)
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
    
    // MARK: - Target Date Card
    private var targetDateCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Target Date")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Target Date Picker
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("When do you want to reach this goal?")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    DatePicker("Target Date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                        .font(ModernDesignSystem.Typography.body)
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
    
    // MARK: - Notes Card
    private var notesCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Notes (Optional)")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Notes Input
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Add notes about this goal")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Add notes about this goal", text: $notes, axis: .vertical)
                        .font(ModernDesignSystem.Typography.body)
                        .lineLimit(3...6)
                        .modernInputField()
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
    
    private func createGoal() {
        guard let targetWeightValue = Double(targetWeight), targetWeightValue > 0 else {
            errorMessage = "Please enter a valid target weight"
            return
        }
        
        isCreating = true
        
        Task {
            do {
                // Use upsert method - handles both create and update automatically
                try await weightService.upsertWeightGoal(
                    petId: pet.id,
                    goalType: goalType,
                    targetWeight: targetWeightValue,
                    targetDate: targetDate,
                    notes: notes.isEmpty ? nil : notes
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - All Weight Entries View

/**
 * View showing all weight entries for a pet with delete functionality
 * 
 * Features:
 * - Lists all weight entries in chronological order
 * - Delete functionality for each entry
 * - Swipe-to-delete support
 * - Pull-to-refresh support
 * 
 * Follows SOLID principles with single responsibility for displaying all weight entries
 * Implements DRY by reusing WeightEntryRow component
 * Follows KISS by keeping the interface simple and focused
 */
struct AllWeightEntriesView: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weightService = CachedWeightTrackingService.shared
    @State private var weightHistory: [WeightRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ModernLoadingView(message: "Loading weight entries...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if weightHistory.isEmpty {
                    emptyStateView
                } else {
                    weightEntriesList
                }
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Weight History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
            .refreshable {
                await loadWeightHistory()
            }
            .task {
                await loadWeightHistory()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    /**
     * Empty state view when no weight entries exist
     */
    private var emptyStateView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "scalemass")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            Text("No Weight Entries")
                .font(ModernDesignSystem.Typography.title2)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text("Start tracking your pet's weight to see entries here")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /**
     * List of all weight entries with delete functionality
     */
    private var weightEntriesList: some View {
        List {
            ForEach(weightHistory) { record in
                WeightEntryRow(record: record, pet: pet)
                    .listRowBackground(ModernDesignSystem.Colors.softCream)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteWeightRecord(recordId: record.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    /**
     * Load weight history for the pet
     */
    private func loadWeightHistory() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Ensure we have fresh data
            try await weightService.loadWeightData(for: pet.id, forceRefresh: true)
            
            await MainActor.run {
                weightHistory = weightService.weightHistory(for: pet.id)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load weight entries: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    /**
     * Delete a weight record
     * - Parameter recordId: The ID of the weight record to delete
     */
    private func deleteWeightRecord(recordId: String) {
        Task {
            do {
                try await weightService.deleteWeightRecord(recordId: recordId)
                
                // Refresh weight data
                try await weightService.loadWeightData(for: pet.id, forceRefresh: true)
                
                // Update local history
                await MainActor.run {
                    weightHistory = weightService.weightHistory(for: pet.id)
                }
                
                // Refresh pet data to get updated weight
                await MainActor.run {
                    CachedPetService.shared.loadPets(forceRefresh: true)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete weight entry: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Extensions

extension WeightGoalType {
    var displayName: String {
        switch self {
        case .weightLoss:
            return "Weight Loss"
        case .weightGain:
            return "Weight Gain"
        case .maintenance:
            return "Maintenance"
        case .healthImprovement:
            return "Health Improvement"
        }
    }
}

#Preview {
    WeightManagementView()
        .environmentObject(AuthService.shared)
}
