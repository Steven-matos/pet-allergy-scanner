//
//  FoodComparisonView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import Charts

/**
 * Food Comparison View
 * 
 * Comprehensive food comparison interface with support for:
 * - Side-by-side food comparison
 * - Nutritional value analysis
 * - Cost per nutritional value analysis
 * - Recommendation engine
 * - Comparison history and saved comparisons
 * 
 * Follows SOLID principles with single responsibility for food comparison
 * Implements DRY by reusing common comparison components
 * Follows KISS by keeping the interface intuitive and data-focused
 */
struct FoodComparisonView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var comparisonService = FoodComparisonService.shared
    @StateObject private var nutritionService = NutritionService.shared
    @State private var selectedFoods: Set<String> = []
    @State private var comparisonName: String = ""
    @State private var showingFoodSelector = false
    @State private var showingComparisonResults = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var comparisonResults: FoodComparisonResults?
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ModernLoadingView(message: "Comparing foods...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if showingComparisonResults, let results = comparisonResults {
                comparisonResultsView(results)
            } else {
                comparisonSetupView
            }
        }
        .background(ModernDesignSystem.Colors.background)
        .sheet(isPresented: $showingFoodSelector) {
            FoodSelectorView(
                selectedFoods: $selectedFoods,
                availableFoods: []
            )
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Comparison Setup View
    
    private var comparisonSetupView: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Header
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 60))
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    Text("Compare Pet Foods")
                        .font(ModernDesignSystem.Typography.title2)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("Select 2-10 foods to compare nutritional values, cost, and compatibility")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(ModernDesignSystem.Spacing.lg)
                
                // Comparison Name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Comparison Name")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter a name for this comparison", text: $comparisonName)
                        .modernInputField()
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                
                // Selected Foods
                if !selectedFoods.isEmpty {
                    selectedFoodsSection
                }
                
                // Add Foods Button
                Button(action: {
                    showingFoodSelector = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(selectedFoods.isEmpty ? "Add Foods to Compare" : "Add More Foods")
                    }
                    .frame(maxWidth: .infinity)
                    .modernButton(style: .primary)
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                
                // Recent Comparisons
                if !comparisonService.recentComparisons.isEmpty {
                    recentComparisonsSection
                }
            }
        }
    }
    
    // MARK: - Selected Foods Section
    
    private var selectedFoodsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Text("Selected Foods (\(selectedFoods.count))")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if selectedFoods.count >= 2 {
                    Text("Ready to compare")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, ModernDesignSystem.Spacing.xs)
                        .background(ModernDesignSystem.Colors.primary)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                }
            }
            
            LazyVStack(spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(Array(selectedFoods), id: \.self) { foodId in
                    // TODO: Re-implement food lookup when NutritionService has getFood method
                    /*if let food = nutritionService.getFood(by: foodId) {
                        SelectedFoodRow(
                            food: food,
                            onRemove: {
                                selectedFoods.remove(foodId)
                            }
                        )
                    }*/
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
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
    
    // MARK: - Recent Comparisons Section
    
    private var recentComparisonsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Recent Comparisons")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            LazyVStack(spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(comparisonService.recentComparisons) { comparison in
                    RecentComparisonRow(comparison: comparison) {
                        loadComparison(comparison.id)
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
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
    
    // MARK: - Comparison Results View
    
    @ViewBuilder
    private func comparisonResultsView(_ results: FoodComparisonResults) -> some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Results Header
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                    Text(results.comparisonName)
                        .font(ModernDesignSystem.Typography.title2)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("Comparison Results")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ModernDesignSystem.Spacing.lg)
                
                // Best Options
                bestOptionsSection(results)
                
                // Nutritional Comparison Chart
                if #available(iOS 16.0, *) {
                    NutritionalComparisonChart(foods: results.foods)
                }
                
                // Detailed Metrics
                detailedMetricsSection(results)
                
                // Recommendations
                if !results.recommendations.isEmpty {
                    recommendationsSection(results)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    showingComparisonResults = false
                    comparisonResults = nil
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveComparison(results)
                }
            }
        }
    }
    
    // MARK: - Best Options Section
    
    private func bestOptionsSection(_ results: FoodComparisonResults) -> some View {
        VStack(spacing: 12) {
            Text("Best Options")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                BestOptionCard(
                    title: "Best Overall",
                    foodName: results.bestOverall,
                    icon: "star.fill",
                    color: .yellow
                )
                
                BestOptionCard(
                    title: "Best Value",
                    foodName: results.bestValue,
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                BestOptionCard(
                    title: "Best Nutrition",
                    foodName: results.bestNutrition,
                    icon: "heart.fill",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    // MARK: - Detailed Metrics Section
    
    private func detailedMetricsSection(_ results: FoodComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Comparison")
                .font(.headline)
            
            // Nutritional Values Table
            nutritionalValuesTable(results)
            
            // Cost Analysis
            costAnalysisSection(results)
            
            // Compatibility Scores
            compatibilityScoresSection(results)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private func nutritionalValuesTable(_ results: FoodComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nutritional Values (per 100g)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVStack(spacing: 4) {
                ForEach(results.foods) { food in
                    HStack {
                        Text(food.foodName)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(Int(food.caloriesPer100g)) kcal")
                            .font(.caption)
                            .frame(width: 60)
                        
                        Text("\(Int(food.proteinPercentage))%")
                            .font(.caption)
                            .frame(width: 40)
                        
                        Text("\(Int(food.fatPercentage))%")
                            .font(.caption)
                            .frame(width: 40)
                        
                        Text("\(Int(food.fiberPercentage))%")
                            .font(.caption)
                            .frame(width: 40)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private func costAnalysisSection(_ results: FoodComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cost Analysis")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVStack(spacing: 4) {
                ForEach(results.foods) { food in
                    HStack {
                        Text(food.foodName)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("$\(results.costPerCalorie[food.id] ?? 0, specifier: "%.3f")/kcal")
                            .font(.caption)
                            .frame(width: 80)
                        
                        Text("$\(results.nutritionalDensity[food.id] ?? 0, specifier: "%.1f")")
                            .font(.caption)
                            .frame(width: 60)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private func compatibilityScoresSection(_ results: FoodComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Compatibility Scores")
                .font(.subheadline)
                .fontWeight(.medium)
            
            LazyVStack(spacing: 4) {
                ForEach(results.foods) { food in
                    HStack {
                        Text(food.foodName)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(Int(results.compatibilityScores[food.id] ?? 0))%")
                            .font(.caption)
                            .frame(width: 40)
                        
                        ProgressView(value: results.compatibilityScores[food.id] ?? 0, total: 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: compatibilityColor(results.compatibilityScores[food.id] ?? 0)))
                            .frame(width: 100)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
    
    private func recommendationsSection(_ results: FoodComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Recommendations")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            LazyVStack(spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(results.recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
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
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
    
    // MARK: - Helper Methods
    
    private func performComparison() {
        guard selectedFoods.count >= 2 else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await comparisonService.compareFoods(
                    foodIds: Array(selectedFoods),
                    comparisonName: comparisonName.isEmpty ? "Food Comparison" : comparisonName
                )
                
                await MainActor.run {
                    comparisonResults = results
                    showingComparisonResults = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func loadComparison(_ comparisonId: String) {
        // Load existing comparison
        // Implementation would load from comparison service
    }
    
    private func saveComparison(_ results: FoodComparisonResults) {
        // Save comparison to history
        // Implementation would save via comparison service
    }
    
    private func compatibilityColor(_ score: Double) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Supporting Views

struct SelectedFoodRow: View {
    let food: FoodAnalysis
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.foodName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let brand = food.brand {
                    Text(brand)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(Int(food.caloriesPer100g)) kcal/100g")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecentComparisonRow: View {
    let comparison: SavedComparison
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(comparison.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(comparison.foodCount) foods • \(comparison.createdAt, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BestOptionCard: View {
    let title: String
    let foodName: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(foodName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct NutritionalComparisonChart: View {
    let foods: [FoodAnalysis]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutritional Comparison")
                .font(.headline)
            
            PerformanceOptimizer.optimizedChart {
                if #available(iOS 16.0, *) {
                    Chart(foods) { food in
                        BarMark(
                            x: .value("Food", food.foodName),
                            y: .value("Calories", food.caloriesPer100g)
                        )
                        .foregroundStyle(.orange)
                        
                        BarMark(
                            x: .value("Food", food.foodName),
                            y: .value("Protein", food.proteinPercentage)
                        )
                        .foregroundStyle(.red)
                        
                        BarMark(
                            x: .value("Food", food.foodName),
                            y: .value("Fat", food.fatPercentage)
                        )
                        .foregroundStyle(.blue)
                    }
                    .frame(height: 200)
                    .chartLegend(position: .top)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

struct FoodSelectorView: View {
    @Binding var selectedFoods: Set<String>
    let availableFoods: [FoodAnalysis]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var filteredFoods: [FoodAnalysis] {
        if searchText.isEmpty {
            return availableFoods
        } else {
            return availableFoods.filter { food in
                food.foodName.localizedCaseInsensitiveContains(searchText) ||
                (food.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $searchText)
                
                List {
                    ForEach(filteredFoods) { food in
                        FoodSelectionRow(
                            food: food,
                            isSelected: selectedFoods.contains(food.id),
                            onToggle: {
                                if selectedFoods.contains(food.id) {
                                    selectedFoods.remove(food.id)
                                } else {
                                    selectedFoods.insert(food.id)
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Select Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FoodSelectionRow: View {
    let food: FoodAnalysis
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.foodName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let brand = food.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("\(Int(food.caloriesPer100g)) kcal/100g • \(Int(food.proteinPercentage))% protein")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search foods...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Data Models

struct SavedComparison: Identifiable {
    let id: String
    let name: String
    let foodCount: Int
    let createdAt: Date
}

#Preview {
    FoodComparisonView()
        .environmentObject(AuthService.shared)
}
