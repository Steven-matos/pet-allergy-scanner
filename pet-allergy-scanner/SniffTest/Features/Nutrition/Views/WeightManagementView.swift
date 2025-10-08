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
 * Follows SOLID principles with single responsibility for weight management
 * Implements DRY by reusing common UI components
 * Follows KISS by keeping the interface intuitive and focused
 */
struct WeightManagementView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var weightService = CachedWeightTrackingService.shared
    @StateObject private var petService = PetService.shared
    @StateObject private var petSelectionService = NutritionPetSelectionService.shared
    @State private var showingWeightEntry = false
    @State private var showingGoalSetting = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var refreshTrigger = false
    
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
                WeightEntryView(pet: pet)
                    .onDisappear {
                        // Refresh weight data when the entry sheet is dismissed
                        loadWeightData()
                        // Force UI refresh
                        refreshTrigger.toggle()
                    }
            }
        }
        .sheet(isPresented: $showingGoalSetting) {
            if let pet = selectedPet {
                WeightGoalSettingView(pet: pet, existingGoal: nil)
                    .onDisappear {
                        // Refresh weight data when the goal setting sheet is dismissed
                        loadWeightData()
                        // Force UI refresh
                        refreshTrigger.toggle()
                    }
            }
        }
        .onAppear {
            loadWeightData()
        }
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
                if !weightService.weightHistory(for: pet.id).isEmpty {
                    WeightTrendChart(
                        weightHistory: weightService.weightHistory(for: pet.id),
                        petName: pet.name
                    )
                } else {
                    // No weight data - show empty state with chart preview
                    EmptyWeightChartCard(pet: pet)
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
    
    private func loadWeightData() {
        guard selectedPet != nil else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            await loadWeightDataAsync()
        }
    }
    
    private func loadWeightDataAsync() async {
        guard let pet = selectedPet else { return }
        
        do {
            try await weightService.loadWeightData(for: pet.id)
            await MainActor.run {
                isLoading = false
                refreshTrigger.toggle() // Trigger UI refresh
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
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

struct WeightTrendChart: View {
    let weightHistory: [WeightRecord]
    let petName: String
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Weight Trend")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            PerformanceOptimizer.optimizedChart {
                if #available(iOS 16.0, *) {
                    Chart(weightHistory.prefix(30)) { record in
                        // Area under the line for better visual appeal
                        AreaMark(
                            x: .value("Date", record.recordedAt),
                            y: .value("Weight", record.weightKg)
                        )
                        .foregroundStyle(ModernDesignSystem.Colors.primary.opacity(0.2))
                        
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
                        .symbolSize(60)
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
                    .chartBackground { chartProxy in
                        // Add subtle grid lines
                        Rectangle()
                            .fill(ModernDesignSystem.Colors.lightGray.opacity(0.3))
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
                // Chart placeholder with sample data visualization
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Text("📊")
                        .font(.system(size: 40))
                    
                    Text("No weight data yet")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Text("Record your first weight to see trends and charts")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                        .fill(ModernDesignSystem.Colors.lightGray)
                        .overlay(
                            // Sample chart visualization
                            VStack {
                                Spacer()
                                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                                    ForEach(0..<7, id: \.self) { index in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(ModernDesignSystem.Colors.primary.opacity(0.3))
                                            .frame(width: 8, height: CGFloat(20 + (index * 8)))
                                    }
                                }
                                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                                Spacer()
                            }
                        )
                )
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
            WeightEntryView(pet: pet)
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
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weightService = WeightTrackingService.shared
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
                try await weightService.recordWeight(
                    petId: pet.id,
                    weight: weightValue,
                    notes: notes.isEmpty ? nil : notes
                )
                
                await MainActor.run {
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
    @StateObject private var weightService = WeightTrackingService.shared
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
