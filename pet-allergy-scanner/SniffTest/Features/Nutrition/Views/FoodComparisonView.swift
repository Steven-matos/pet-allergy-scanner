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
    @EnvironmentObject var petService: CachedPetService
    @StateObject private var comparisonService = FoodComparisonService.shared
    @StateObject private var nutritionService = NutritionService.shared
    @StateObject private var petSelectionService = NutritionPetSelectionService.shared
    @State private var selectedFoods: Set<String> = []
    @State private var comparisonName: String = ""
    @State private var showingFoodSelector = false
    @State private var showingComparisonResults = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var comparisonResults: FoodComparisonResults?
    @State private var showingSensitivityInfo = false
    
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
            EnhancedFoodSearchView(selectedFoods: $selectedFoods)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Common Sensitivity Triggers", isPresented: $showingSensitivityInfo) {
            Button("OK") {
                showingSensitivityInfo = false
            }
        } message: {
            Text("""
            Common sensitivity triggers are ingredients that frequently cause reactions in pets. This data comes from:
            
            • OpenPetFoodFacts database
            • Scientific research on pet allergies
            • Food manufacturer disclosures
            • Veterinary studies
            
            Common triggers include:
            - Proteins: chicken, beef, dairy, eggs, fish
            - Grains: wheat, corn, soy
            - Additives: artificial colors, preservatives
            
            Note: This is different from YOUR pet's specific sensitivities. We check your pet's known sensitivities separately and show warnings if we find matches.
            """)
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
                    
                    Text("Select 2-3 foods to compare nutritional values and ingredients")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(ModernDesignSystem.Spacing.lg)
                
                // Comparison Name (Optional)
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Comparison Name (Optional)")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("Give this comparison a name to save it for later")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    TextField("e.g., High Protein Foods", text: $comparisonName)
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
                
                // Compare Button (only show when 2-3 foods selected)
                if selectedFoods.count >= 2 && selectedFoods.count <= 3 {
                    Button(action: {
                        performComparison()
                    }) {
                        HStack {
                            Image(systemName: "chart.bar.xaxis")
                            Text("Compare \(selectedFoods.count) Foods")
                        }
                        .frame(maxWidth: .infinity)
                        .modernButton(style: .secondary)
                    }
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    .padding(.top, ModernDesignSystem.Spacing.sm)
                }
                
                // Warning when more than 3 foods selected
                if selectedFoods.count > 3 {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        
                        Text("Maximum 3 foods allowed. Please remove \(selectedFoods.count - 3) food(s).")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(ModernDesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                }
                
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
                
                // Pet Allergy Alert (if applicable)
                if results.petAllergiesChecked, let petName = results.petName {
                    petAllergyAlertSection(results, petName: petName)
                }
                
                // Best Options
                bestOptionsSection(results)
                
                // Nutritional Comparison Chart (only if we have nutritional data)
                if #available(iOS 16.0, *), hasNutritionalData(results.foods) {
                    NutritionalComparisonChart(foods: results.foods)
                }
                
                // Nutritional Values Table (only if we have data)
                if hasNutritionalData(results.foods) {
                    nutritionalMetricsSection(results)
                }
                
                // Ingredient Comparison (always show if ingredients exist)
                if hasIngredients(results.foods) {
                    ingredientComparisonSectionStandalone(results)
                }
                
                // Common Sensitivity Triggers (always show)
                allergenAnalysisSectionStandalone(results)
                
                // Recommendations
                if !results.recommendations.isEmpty {
                    recommendationsSection(results)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    // Go back to comparison setup with current selections intact
                    showingComparisonResults = false
                    comparisonResults = nil
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Clear everything and start fresh
                    showingComparisonResults = false
                    comparisonResults = nil
                    selectedFoods = []
                    comparisonName = ""
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("New")
                    }
                }
            }
        }
    }
    
    // MARK: - Pet Allergy Alert Section
    
    /// Shows a prominent alert if any foods contain ingredients the pet is sensitive to
    private func petAllergyAlertSection(_ results: FoodComparisonResults, petName: String) -> some View {
        let foodsWithSensitivities = results.foods.filter { $0.hasPetAllergyWarning }
        let hasDangerousFoods = !foodsWithSensitivities.isEmpty
        
        return VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: hasDangerousFoods ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                    .font(.title2)
                    .foregroundColor(hasDangerousFoods ? .red : .green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(hasDangerousFoods ? "⚠️ Sensitivity Warning for \(petName)" : "✓ Safe for \(petName)")
                        .font(ModernDesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(hasDangerousFoods ? .red : .green)
                    
                    if hasDangerousFoods {
                        Text("\(foodsWithSensitivities.count) food(s) contain ingredients \(petName) is sensitive to")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    } else {
                        Text("All foods are safe based on \(petName)'s known sensitivities")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
            }
            
            // List foods with sensitivities
            if hasDangerousFoods {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    ForEach(foodsWithSensitivities) { food in
                        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.foodName)
                                    .font(ModernDesignSystem.Typography.subheadline)
                                    .fontWeight(.medium)
                                
                                if let warnings = food.petAllergyWarnings, !warnings.isEmpty {
                                    Text("Contains: \(warnings.joined(separator: ", "))")
                                        .font(ModernDesignSystem.Typography.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding(ModernDesignSystem.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(hasDangerousFoods ? Color.red.opacity(0.05) : Color.green.opacity(0.05))
        .cornerRadius(ModernDesignSystem.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                .stroke(hasDangerousFoods ? Color.red : Color.green, lineWidth: 2)
        )
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
    
    // MARK: - Best Options Section
    
    private func bestOptionsSection(_ results: FoodComparisonResults) -> some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("Best Options")
                    .font(.headline)
                
                if results.petAllergiesChecked {
                    Text("Only foods safe for \(results.petName ?? "your pet") are recommended")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            // Check if all foods have sensitivities
            let allHaveSensitivities = results.bestOverall.contains("⚠️")
            
            if allHaveSensitivities {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No Safe Options")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text("All compared foods contain ingredients your pet is sensitive to")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    BestOptionCard(
                        title: "Highest Protein",
                        foodName: results.bestNutrition,
                        icon: "flame.fill",
                        color: .red
                    )
                    
                    BestOptionCard(
                        title: "Most Balanced",
                        foodName: results.bestOverall,
                        icon: "star.fill",
                        color: .yellow
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    // MARK: - Nutritional Metrics Section
    
    private func nutritionalMetricsSection(_ results: FoodComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nutritional Values")
                .font(.headline)
            
            // Nutritional Values Table
            nutritionalValuesTable(results)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private func nutritionalValuesTable(_ results: FoodComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutritional Values (per 100g)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            // Header Row
            HStack {
                Text("Food")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Calories")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 55)
                
                Text("Protein")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 50)
                
                Text("Fat")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 40)
                
                Text("Fiber")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 40)
            }
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(6)
            
            // Data Rows
            LazyVStack(spacing: 8) {
                ForEach(results.foods) { food in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(food.foodName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            if let brand = food.brand {
                                Text(brand)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(Int(food.caloriesPer100g))")
                            .font(.caption)
                            .frame(width: 55)
                            .foregroundColor(getHighlightColor(food.caloriesPer100g, in: results.foods.map { $0.caloriesPer100g }, higher: true))
                        
                        Text("\(String(format: "%.1f", food.proteinPercentage))%")
                            .font(.caption)
                            .frame(width: 50)
                            .foregroundColor(getHighlightColor(food.proteinPercentage, in: results.foods.map { $0.proteinPercentage }, higher: true))
                        
                        Text("\(String(format: "%.1f", food.fatPercentage))%")
                            .font(.caption)
                            .frame(width: 40)
                            .foregroundColor(getHighlightColor(food.fatPercentage, in: results.foods.map { $0.fatPercentage }, higher: false))
                        
                        Text("\(String(format: "%.1f", food.fiberPercentage))%")
                            .font(.caption)
                            .frame(width: 40)
                            .foregroundColor(getHighlightColor(food.fiberPercentage, in: results.foods.map { $0.fiberPercentage }, higher: true))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.systemGray5), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    /// Standalone ingredient comparison section (always visible if ingredients exist)
    private func ingredientComparisonSectionStandalone(_ results: FoodComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ingredient Comparison")
                .font(.headline)
            
            ingredientComparisonContent(results)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    /// Compares ingredients across all selected foods
    /// Highlights ingredients that match pet's sensitivities in RED
    private func ingredientComparisonContent(_ results: FoodComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if results.petAllergiesChecked {
                Text("Ingredients matching \(results.petName ?? "your pet")'s sensitivities are highlighted in red")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
            
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(results.foods) { food in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(food.foodName)
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text("\(food.ingredients.count) ingredients")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if !food.ingredients.isEmpty {
                            FlowLayout(spacing: 4) {
                                ForEach(food.ingredients, id: \.self) { ingredient in
                                    // Check if this ingredient matches pet's sensitivities
                                    let isPetSensitive = food.petAllergyWarnings?.contains(ingredient) ?? false
                                    
                                    Text(ingredient)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isPetSensitive ? Color.red.opacity(0.15) : Color(.systemGray6))
                                        .foregroundColor(isPetSensitive ? .red : .primary)
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(isPetSensitive ? Color.red : Color.clear, lineWidth: 1)
                                        )
                                }
                            }
                        } else {
                            Text("No ingredient information available")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(food.hasPetAllergyWarning ? Color.red.opacity(0.3) : Color(.systemGray5), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    /// Standalone allergen analysis section
    private func allergenAnalysisSectionStandalone(_ results: FoodComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            allergenAnalysisContent(results)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    /// Analyzes and displays common sensitivity triggers
    /// Highlights foods with fewer problematic ingredients
    /// Note: This shows ingredients that are commonly known to cause sensitivities in pets
    /// (e.g., chicken, beef, dairy, grains, corn, soy, wheat)
    private func allergenAnalysisContent(_ results: FoodComparisonResults) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text("Common Sensitivity Triggers")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {
                    showingSensitivityInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Based on OpenPetFoodFacts database. Tap info for details.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
            
            LazyVStack(spacing: 8) {
                ForEach(results.foods) { food in
                    let commonTriggers = findCommonTriggers(in: food.ingredients)
                    
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(food.foodName)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            if !commonTriggers.isEmpty {
                                FlowLayout(spacing: 4) {
                                    ForEach(commonTriggers, id: \.self) { sensitivity in
                                        HStack(spacing: 4) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                            
                                            Text(sensitivity)
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(4)
                                    }
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    
                                    Text("No common sensitivity triggers found")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(commonTriggers.isEmpty ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    /// Helper function to highlight best/worst values in comparison
    /// - Parameters:
    ///   - value: The value to check
    ///   - values: All values to compare against
    ///   - higher: Whether higher is better (true) or worse (false)
    /// - Returns: Color to highlight the value
    private func getHighlightColor(_ value: Double, in values: [Double], higher: Bool) -> Color {
        guard let max = values.max(), let min = values.min(), max != min else {
            return .primary
        }
        
        if higher {
            if value == max {
                return .green
            } else if value == min {
                return .red
            }
        } else {
            if value == min {
                return .green
            } else if value == max {
                return .red
            }
        }
        
        return .primary
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
    
    /// Check if foods have nutritional data worth displaying
    private func hasNutritionalData(_ foods: [FoodAnalysis]) -> Bool {
        return foods.contains { food in
            food.caloriesPer100g > 0 ||
            food.proteinPercentage > 0 ||
            food.fatPercentage > 0 ||
            food.fiberPercentage > 0
        }
    }
    
    /// Check if foods have ingredients
    private func hasIngredients(_ foods: [FoodAnalysis]) -> Bool {
        return foods.contains { food in
            !food.ingredients.isEmpty
        }
    }
    
    /// Common sensitivity triggers - ingredients known to cause reactions in pets
    private let commonSensitivityTriggers: Set<String> = [
        // Proteins
        "chicken", "beef", "dairy", "milk", "cheese", "eggs", "egg", "fish", "salmon", "tuna",
        "pork", "lamb", "turkey", "duck", "venison", "rabbit",
        // Grains
        "wheat", "corn", "soy", "rice", "barley", "oats", "rye",
        // Other common triggers
        "yeast", "gluten", "potato", "tomato", "peas", "lentils"
    ]
    
    /// Find common sensitivity triggers in a food's ingredients
    private func findCommonTriggers(in ingredients: [String]) -> [String] {
        var foundTriggers: [String] = []
        
        for ingredient in ingredients {
            let normalizedIngredient = ingredient.lowercased().trimmingCharacters(in: .whitespaces)
            
            // Check if ingredient contains any common trigger
            for trigger in commonSensitivityTriggers {
                if normalizedIngredient.contains(trigger) {
                    foundTriggers.append(ingredient)
                    break
                }
            }
        }
        
        return foundTriggers
    }
    
    private func performComparison() {
        guard selectedFoods.count >= 2 else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Get the selected pet for allergy checking
                let selectedPet = petSelectionService.selectedPet ?? petService.pets.first
                
                let results = try await comparisonService.compareFoods(
                    foodIds: Array(selectedFoods),
                    comparisonName: comparisonName.isEmpty ? "Food Comparison" : comparisonName,
                    pet: selectedPet
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
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let results = try await comparisonService.loadComparison(comparisonId: comparisonId)
                
                await MainActor.run {
                    comparisonResults = results
                    showingComparisonResults = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load comparison: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func saveComparison(_ results: FoodComparisonResults) {
        // Comparison is already automatically saved in the service
        // This method is called from the toolbar "Save" button
        // Could show a confirmation message here if needed
        Task {
            await MainActor.run {
                // Show success message or dismiss
                showingComparisonResults = false
                comparisonResults = nil
                selectedFoods = []
                comparisonName = ""
            }
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
    
    // Filter foods that have nutritional data
    private var foodsWithData: [FoodAnalysis] {
        foods.filter { food in
            food.caloriesPer100g > 0 ||
            food.proteinPercentage > 0 ||
            food.fatPercentage > 0
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutritional Comparison")
                .font(.headline)
            
            if foodsWithData.isEmpty {
                Text("No nutritional data available for these foods")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                PerformanceOptimizer.optimizedChart {
                    if #available(iOS 16.0, *) {
                        Chart(foodsWithData) { food in
                            // Calories
                            BarMark(
                                x: .value("Food", food.foodName),
                                y: .value("Calories", food.caloriesPer100g)
                            )
                            .foregroundStyle(.orange)
                            
                            // Protein
                            BarMark(
                                x: .value("Food", food.foodName),
                                y: .value("Protein %", food.proteinPercentage)
                            )
                            .foregroundStyle(.red)
                            
                            // Fat
                            BarMark(
                                x: .value("Food", food.foodName),
                                y: .value("Fat %", food.fatPercentage)
                            )
                            .foregroundStyle(.blue)
                        }
                        .frame(height: 200)
                        .chartLegend(position: .top)
                        .chartXAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let foodName = value.as(String.self) {
                                        Text(foodName)
                                            .font(.caption2)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }
                        }
                    }
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
