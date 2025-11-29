//
//  WeightManagementView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import Charts

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
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var refreshTrigger = false
    @State private var lastRecordedWeightId: String?
    @State private var showingUndoToast = false
    
    // MARK: - Computed Properties
    
    private var selectedPet: Pet? {
        petSelectionService.selectedPet
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ModernLoadingView(message: "Loading weight data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                        // Refresh weight data when the entry sheet is dismissed
                        loadWeightData()
                        // Enable fast polling to quickly pick up changes
                        syncService.enableFastPolling()
                        // Force UI refresh
                        refreshTrigger.toggle()
                        
                        // Show undo toast if a weight was recorded
                        if lastRecordedWeightId != nil {
                            showingUndoToast = true
                            
                            // Auto-hide undo toast after 5 seconds
                            Task {
                                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                                await MainActor.run {
                                    if showingUndoToast {
                                        showingUndoToast = false
                                        lastRecordedWeightId = nil
                                    }
                                }
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingGoalSetting) {
            if let pet = selectedPet {
                WeightGoalSettingView(pet: pet, existingGoal: nil)
                    .onDisappear {
                        // After creating a goal, the goal is already stored locally in weightService
                        // We just need to refresh the UI to show it
                        // Don't immediately fetch from backend as it might not be saved yet
                        Task {
                            // Small delay to ensure backend has processed the goal
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            
                            // Now refresh from server to get the latest goal data
                            await loadWeightDataAsync(showLoadingIfNeeded: false)
                        }
                        // Enable fast polling to quickly pick up changes
                        syncService.enableFastPolling()
                        // Force UI refresh immediately to show the locally stored goal
                        refreshTrigger.toggle()
                    }
            }
        }
        .onAppear {
            loadWeightDataIfNeeded()
            // Start auto-syncing when view appears
            if let pet = selectedPet {
                syncService.startSyncing(forPetId: pet.id)
            }
        }
        .onDisappear {
            // Stop syncing when view disappears
            if let pet = selectedPet {
                syncService.stopSyncing(forPetId: pet.id)
            }
        }
        .onChange(of: selectedPet) { oldPet, newPet in
            // Stop syncing old pet, start syncing new pet
            if let oldPet = oldPet {
                syncService.stopSyncing(forPetId: oldPet.id)
            }
            if let newPet = newPet {
                syncService.startSyncing(forPetId: newPet.id)
            }
        }
        .refreshable {
            // Pull to refresh weight data
            await refreshWeightData()
        }
        .overlay(alignment: .bottom) {
            // Undo toast for recently recorded weight
            if showingUndoToast {
                undoToastView
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
                            loadWeightData()
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
                CurrentWeightCard(
                    pet: pet,
                    currentWeight: weightService.currentWeights[pet.id] ?? pet.weightKg,
                    weightGoal: weightService.activeWeightGoal(for: pet.id)
                )
                .id(refreshTrigger) // Force refresh when trigger changes
                
                // Weight Trend Chart
                let weightHistory = weightService.weightHistory(for: pet.id)
                let _ = print("📊 [UI RENDER] Weight history count for \(pet.name): \(weightHistory.count)")
                
                if !weightHistory.isEmpty {
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        // Debug info banner (temporary for troubleshooting)
                        HStack {
                            Text("📊 \(weightHistory.count) record(s) loaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Force Refresh") {
                                Task {
                                    print("🔄 Manual force refresh triggered")
                                    await refreshWeightData()
                                }
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        WeightTrendChart(
                            weightHistory: weightHistory,
                            petName: pet.name,
                            pet: pet  // Pass pet for background image
                        )
                    }
                } else {
                    // No weight data - show empty state with chart preview
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        // Debug info banner (temporary for troubleshooting)
                        HStack {
                            Text("⚠️ No weight records loaded")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer()
                            Button("Force Refresh") {
                                Task {
                                    print("🔄 Manual force refresh triggered (empty state)")
                                    await refreshWeightData()
                                }
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        
                        EmptyWeightChartCard(pet: pet)
                    }
                }
                
                // Goal Progress
                if let goal = weightService.activeWeightGoal(for: pet.id) {
                    GoalProgressCard(
                        goal: goal, 
                        currentWeight: weightService.currentWeights[pet.id] ?? pet.weightKg, 
                        pet: pet
                    )
                    .id("\(goal.id)-\(weightService.currentWeights[pet.id] ?? 0)-\(refreshTrigger)") // Force refresh when weight changes
                } else {
                    // No goal set - show "Set Goal" card
                    SetGoalCard(pet: pet)
                }
                
                // Recent Weight Entries
                RecentWeightEntriesCard(
                    pet: pet,
                    weightHistory: weightService.weightHistory(for: pet.id)
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
     * Load weight data only if not already cached
     * This prevents unnecessary server calls when data is already available
     */
    private func loadWeightDataIfNeeded() {
        guard let pet = selectedPet else { return }
        
        print("📊 [loadWeightDataIfNeeded] Checking if need to load for \(pet.name)")
        
        // Check if we have data in memory
        let hasData = weightService.hasCachedWeightData(for: pet.id)
        print("📊 [loadWeightDataIfNeeded] Has cached data: \(hasData)")
        
        // Always load on first appearance to ensure fresh data
        // The service will check its in-memory cache first
        Task {
            print("📊 [loadWeightDataIfNeeded] Starting load task...")
            await loadWeightDataAsync(showLoadingIfNeeded: !hasData)
        }
    }
    
    /**
     * Force load weight data from server
     * Used when new data is added (weight entry, goal setting)
     */
    private func loadWeightData() {
        guard selectedPet != nil else { return }
        
        Task {
            await loadWeightDataAsync(showLoadingIfNeeded: true)
        }
    }
    
    private func loadWeightDataAsync(showLoadingIfNeeded: Bool = false) async {
        guard let pet = selectedPet else {
            print("⚠️ [loadWeightDataAsync] No selected pet, cannot load weight data")
            return
        }
        
        print("📊 === Starting weight data load for \(pet.name) (ID: \(pet.id)) ===")
        print("📊 [loadWeightDataAsync] showLoadingIfNeeded: \(showLoadingIfNeeded)")
        
        // Check if we already have data in memory (from cache or previous load)
        let hadDataBefore = weightService.hasCachedWeightData(for: pet.id)
        let recordsBeforeCount = weightService.weightHistory(for: pet.id).count
        let goalBeforeCount = weightService.activeWeightGoal(for: pet.id) != nil ? 1 : 0
        print("📊 [loadWeightDataAsync] Before load - hadData: \(hadDataBefore), records: \(recordsBeforeCount), goal: \(goalBeforeCount)")
        
        // Only show loading if explicitly requested and we don't have data
        if showLoadingIfNeeded && !hadDataBefore {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
            }
            print("⏳ [loadWeightDataAsync] Showing loading indicator")
        }
        
        do {
            // Force refresh from server to ensure we have the latest data including goals
            print("📊 [loadWeightDataAsync] Calling loadWeightData with forceRefresh=true")
            try await weightService.loadWeightData(for: pet.id, forceRefresh: true)
            
            // Check if we have data now
            let hasDataAfter = weightService.hasCachedWeightData(for: pet.id)
            let weightHistoryCount = weightService.weightHistory(for: pet.id).count
            let weightHistory = weightService.weightHistory(for: pet.id)
            let hasGoal = weightService.activeWeightGoal(for: pet.id) != nil
            
            print("✅ [loadWeightDataAsync] Weight data loaded successfully")
            print("   - Has data after: \(hasDataAfter)")
            print("   - Records count: \(weightHistoryCount)")
            print("   - Has goal: \(hasGoal)")
            print("   - Actual records: \(weightHistory.map { "\($0.weightKg)kg on \($0.recordedAt)" })")
            
            // If we still don't have data, log warning
            if !hasDataAfter {
                print("⚠️ [loadWeightDataAsync] WARNING: Load completed but still no data!")
                print("   This might indicate:")
                print("   1. No data exists in database for this pet")
                print("   2. API call failed silently")
                print("   3. Data not being stored in @Published properties")
            }
            
            await MainActor.run {
                isLoading = false
                refreshTrigger.toggle()
                print("🔄 [loadWeightDataAsync] Toggled refreshTrigger to force UI update")
            }
        } catch {
            print("❌ [loadWeightDataAsync] Failed to load weight data: \(error)")
            print("   Error type: \(type(of: error))")
            print("   Error details: \(error.localizedDescription)")
            
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
        
        print("📊 === Finished weight data load ===")
    }
    
    /**
     * Force refresh weight data from server (bypasses cache)
     * Used for pull-to-refresh gesture
     */
    private func refreshWeightData() async {
        guard let pet = selectedPet else { return }
        
        print("🔄 Force refreshing weight data for pet: \(pet.name)")
        
        do {
            // Force refresh from server
            try await weightService.refreshWeightData(petId: pet.id)
            
            await MainActor.run {
                refreshTrigger.toggle() // Force UI refresh
                print("✅ Weight data refreshed successfully")
            }
        } catch {
            print("❌ Failed to refresh weight data: \(error.localizedDescription)")
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
                
                // Trigger UI refresh
                await MainActor.run {
                    refreshTrigger.toggle()
                    lastRecordedWeightId = nil
                }
                
                print("✅ Weight record undone successfully")
            } catch {
                print("❌ Failed to undo weight: \(error.localizedDescription)")
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
            // Faded pet image background
            backgroundImage
            
            // Chart overlay
            weightChart
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
                Chart(weightHistory.prefix(30)) { record in
                    // Area under the line
                    AreaMark(
                        x: .value("Date", record.recordedAt),
                        y: .value("Weight", record.weightKg)
                    )
                    .foregroundStyle(ModernDesignSystem.Colors.primary.opacity(0.25))
                    
                    // Main line
                    LineMark(
                        x: .value("Date", record.recordedAt),
                        y: .value("Weight", record.weightKg)
                    )
                    .foregroundStyle(ModernDesignSystem.Colors.primary)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    // Data points
                    PointMark(
                        x: .value("Date", record.recordedAt),
                        y: .value("Weight", record.weightKg)
                    )
                    .foregroundStyle(ModernDesignSystem.Colors.primary)
                    .symbolSize(80)
                    .symbol(.circle)
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
            print("⚠️ Warning: No starting weight found for goal, using current weight: \(startingWeight)")
        }
        
        print("📊 Progress calculation - Current: \(current), Target: \(target), Starting: \(startingWeight), GoalType: \(goalType)")
        
        switch goalType {
        case .weightLoss:
            // For weight loss, progress is how much weight has been lost from starting point
            let totalWeightToLose = startingWeight - target
            let weightLost = startingWeight - current
            guard totalWeightToLose > 0 else { 
                print("📊 Weight loss: Invalid target (target >= starting weight)")
                return 0.0 
            }
            
            // If no weight has been lost yet (current weight >= starting weight), show 0% progress
            if weightLost <= 0 {
                print("📊 Weight loss: No progress yet (current: \(current), starting: \(startingWeight))")
                return 0.0
            }
            
            let progress = min(1.0, max(0.0, weightLost / totalWeightToLose))
            print("📊 Weight loss progress: \(progress * 100)% (lost: \(weightLost), total to lose: \(totalWeightToLose))")
            return progress
            
        case .weightGain:
            // For weight gain, progress is how much weight has been gained from starting point
            let totalWeightToGain = target - startingWeight
            let weightGained = current - startingWeight
            guard totalWeightToGain > 0 else { 
                print("📊 Weight gain: Invalid target (target <= starting weight)")
                return 0.0 
            }
            
            // If no weight has been gained yet (current weight <= starting weight), show 0% progress
            if weightGained <= 0 {
                print("📊 Weight gain: No progress yet (current: \(current), starting: \(startingWeight))")
                return 0.0
            }
            
            let progress = min(1.0, max(0.0, weightGained / totalWeightToGain))
            print("📊 Weight gain progress: \(progress * 100)% (gained: \(weightGained), total to gain: \(totalWeightToGain))")
            return progress
            
        case .maintenance, .healthImprovement:
            // For maintenance, progress is how close to target (inverse of distance)
            let distanceFromTarget = abs(current - target)
            let maxDistance = max(abs(startingWeight - target), 1.0) // Avoid division by zero
            let progress = min(1.0, max(0.0, 1.0 - (distanceFromTarget / maxDistance)))
            print("📊 Maintenance progress: \(progress * 100)% (distance: \(distanceFromTarget), max distance: \(maxDistance))")
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Text("Recent Entries")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if weightHistory.count > 5 {
                    Text("View All")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.buttonPrimary)
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
                        WeightEntryRow(record: record)
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
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
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
        }
        .padding(.vertical, ModernDesignSystem.Spacing.xs)
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
                    .foregroundColor(ModernDesignSystem.Colors.primary)
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
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Current Weight")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        if let currentWeight = pet.weightKg {
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
                
                await MainActor.run {
                    // Store the record ID for undo functionality
                    lastRecordedWeightId = recordId
                    dismiss()
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
                    .foregroundColor(ModernDesignSystem.Colors.primary)
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
