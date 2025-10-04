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
    @StateObject private var trendsService = NutritionalTrendsService.shared
    @StateObject private var petService = PetService.shared
    @State private var selectedPet: Pet?
    @State private var selectedPeriod: TrendPeriod = .thirtyDays
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPeriodSelector = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading trends...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let pet = selectedPet {
                    trendsContent(for: pet)
                } else {
                    petSelectionView
                }
            }
            .navigationTitle("Nutritional Trends")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(selectedPeriod.displayName) {
                        showingPeriodSelector = true
                    }
                    .disabled(selectedPet == nil)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadTrendsData()
                    }
                    .disabled(selectedPet == nil || isLoading)
                }
            }
        }
        .sheet(isPresented: $showingPeriodSelector) {
            PeriodSelectionView(selectedPeriod: $selectedPeriod)
        }
        .onAppear {
            loadTrendsData()
        }
    }
    
    // MARK: - Pet Selection View
    
    private var petSelectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Select a Pet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose a pet to view nutritional trends")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !petService.pets.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(petService.pets) { pet in
                        PetSelectionCard(pet: pet) {
                            selectedPet = pet
                            loadTrendsData()
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                Text("No pets found. Add a pet to get started.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Trends Content
    
    @ViewBuilder
    private func trendsContent(for pet: Pet) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Cards
                summaryCardsSection(for: pet)
                
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
            .padding()
        }
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
        ], spacing: 12) {
            // Average Daily Calories
            SummaryCard(
                title: "Avg Daily Calories",
                value: "\(Int(trendsService.averageDailyCalories(for: pet.id)))",
                unit: "kcal",
                trend: trendsService.calorieTrend(for: pet.id),
                color: .orange
            )
            
            // Feeding Frequency
            SummaryCard(
                title: "Feeding Frequency",
                value: "\(trendsService.averageFeedingFrequency(for: pet.id), specifier: "%.1f")",
                unit: "times/day",
                trend: trendsService.feedingTrend(for: pet.id),
                color: .green
            )
            
            // Nutritional Balance
            SummaryCard(
                title: "Nutritional Balance",
                value: "\(Int(trendsService.nutritionalBalanceScore(for: pet.id)))",
                unit: "%",
                trend: trendsService.balanceTrend(for: pet.id),
                color: .blue
            )
            
            // Weight Change
            SummaryCard(
                title: "Weight Change",
                value: "\(trendsService.totalWeightChange(for: pet.id), specifier: "%.1f")",
                unit: "kg",
                trend: trendsService.weightChangeTrend(for: pet.id),
                color: .purple
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTrendsData() {
        guard let pet = selectedPet else { return }
        
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

struct PetSelectionCard: View {
    let pet: Pet
    let onTap: () -> Void
    
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
                        .foregroundColor(.blue)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(pet.species.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                trendIcon
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    @ViewBuilder
    private var trendIcon: some View {
        switch trend {
        case .increasing:
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundColor(.green)
        case .decreasing:
            Image(systemName: "arrow.down.right")
                .font(.caption)
                .foregroundColor(.red)
        case .stable:
            Image(systemName: "minus")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct CalorieTrendsChart: View {
    let trends: [CalorieTrend]
    let petName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calorie Trends")
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart(trends) { trend in
                    LineMark(
                        x: .value("Date", trend.date),
                        y: .value("Calories", trend.calories)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("Date", trend.date),
                        y: .value("Calories", trend.calories)
                    )
                    .foregroundStyle(.orange.opacity(0.2))
                    
                    if let target = trend.target {
                        RuleMark(y: .value("Target", target))
                            .foregroundStyle(.green)
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
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct MacronutrientTrendsChart: View {
    let trends: [MacronutrientTrend]
    let petName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macronutrient Trends")
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart(trends) { trend in
                    LineMark(
                        x: .value("Date", trend.date),
                        y: .value("Protein", trend.protein)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    LineMark(
                        x: .value("Date", trend.date),
                        y: .value("Fat", trend.fat)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    LineMark(
                        x: .value("Date", trend.date),
                        y: .value("Fiber", trend.fiber)
                    )
                    .foregroundStyle(.green)
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
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct FeedingPatternsChart: View {
    let patterns: [FeedingPattern]
    let petName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feeding Patterns")
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart(patterns) { pattern in
                    BarMark(
                        x: .value("Date", pattern.date),
                        y: .value("Feedings", pattern.feedingCount)
                    )
                    .foregroundStyle(.green)
                    
                    LineMark(
                        x: .value("Date", pattern.date),
                        y: .value("Compatibility", pattern.compatibilityScore)
                    )
                    .foregroundStyle(.blue)
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
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct WeightCorrelationCard: View {
    let correlation: WeightCorrelation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight Correlation")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Correlation Strength")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(correlation.strength.capitalized)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(correlationColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Correlation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(correlation.correlation, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            Text(correlation.interpretation)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var correlationColor: Color {
        switch correlation.strength {
        case "strong":
            return .green
        case "moderate":
            return .orange
        case "weak":
            return .red
        default:
            return .gray
        }
    }
}

struct InsightsCard: View {
    let insights: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(.top, 2)
                        
                        Text(insight)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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

enum TrendPeriod: CaseIterable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    
    var displayName: String {
        switch self {
        case .sevenDays:
            return "7 Days"
        case .thirtyDays:
            return "30 Days"
        case .ninetyDays:
            return "90 Days"
        }
    }
}

enum TrendDirection {
    case increasing
    case decreasing
    case stable
}

struct CalorieTrend: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let target: Double?
}

struct MacronutrientTrend: Identifiable {
    let id = UUID()
    let date: Date
    let protein: Double
    let fat: Double
    let fiber: Double
}

struct FeedingPattern: Identifiable {
    let id = UUID()
    let date: Date
    let feedingCount: Int
    let compatibilityScore: Double
}

struct WeightCorrelation {
    let correlation: Double
    let strength: String
    let interpretation: String
}

#Preview {
    NutritionalTrendsView()
        .environmentObject(AuthService.shared)
}
