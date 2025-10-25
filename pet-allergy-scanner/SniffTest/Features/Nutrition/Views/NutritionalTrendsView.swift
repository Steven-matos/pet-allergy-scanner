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
    @StateObject private var petService = CachedPetService.shared
    @StateObject private var petSelectionService = NutritionPetSelectionService.shared
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    @Binding var selectedPeriod: TrendPeriod
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPeriodSelector = false
    @State private var showingFeedingLog = false
    
    private var selectedPet: Pet? {
        petSelectionService.selectedPet
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ModernLoadingView(message: "Loading trends...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let pet = selectedPet {
                trendsContent(for: pet)
            } else {
                petSelectionView
            }
        }
        .background(ModernDesignSystem.Colors.background)
        .sheet(isPresented: $showingPeriodSelector) {
            PeriodSelectionView(selectedPeriod: $selectedPeriod)
        }
        .sheet(isPresented: $showingFeedingLog) {
            FeedingLogView()
                .onDisappear {
                    // Refresh trends data when the feeding log sheet is dismissed
                    loadTrendsData()
                }
        }
        .onAppear {
            loadTrendsDataIfNeeded()
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
                
                // Quick Action Card - Log Feeding
                quickActionCard
                
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
    
    // MARK: - Quick Action Card
    
    private var quickActionCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title2)
                
                Text("Quick Actions")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            Button(action: {
                showingFeedingLog = true
            }) {
                HStack {
                    Image(systemName: "fork.knife")
                        .font(.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                    
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Log Feeding Session")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                        
                        Text("Record what your pet ate today")
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
    
    // MARK: - Helper Methods
    
    /**
     * Load trends data only if not already cached
     * This prevents unnecessary server calls when data is already available
     */
    private func loadTrendsDataIfNeeded() {
        guard let pet = selectedPet else { return }
        
        // Check if we already have cached trends data for this pet
        if trendsService.hasCachedTrendsData(for: pet.id) {
            // We have cached data, no need to show loading or make server calls
            return
        } else {
            // No cached data, load from server
            loadTrendsData()
        }
    }
    
    /**
     * Force load trends data from server
     * Used when new data is added (feeding log, weight entry)
     */
    private func loadTrendsData() {
        guard selectedPet != nil else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            await loadTrendsDataAsync()
        }
    }
    
    private func loadTrendsDataAsync() async {
        guard let pet = selectedPet else { return }
        
        do {
            try await trendsService.loadTrendsData(for: pet.id, period: selectedPeriod)
            await MainActor.run {
                isLoading = false
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

// MARK: - Data Models




#Preview {
    NutritionalTrendsView(selectedPeriod: .constant(.thirtyDays))
        .environmentObject(AuthService.shared)
}
