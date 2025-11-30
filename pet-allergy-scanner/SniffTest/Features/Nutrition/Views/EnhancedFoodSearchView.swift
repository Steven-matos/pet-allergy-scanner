//
//  EnhancedFoodSearchView.swift
//  SniffTest
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

/**
 * Enhanced Food Search View
 * 
 * Comprehensive food search interface with:
 * - Database search functionality
 * - Real-time search results
 * - Ability to add new foods not in database
 * - Multi-select for comparison
 * - Filter by brand and category
 * 
 * Follows SOLID principles with single responsibility for food search
 * Implements DRY by reusing common search patterns
 * Follows KISS by keeping the interface intuitive
 */
struct EnhancedFoodSearchView: View {
    @Binding var selectedFoods: Set<String>
    @Environment(\.dismiss) private var dismiss
    @StateObject private var foodService = FoodService.shared
    
    @State private var searchText = ""
    @State private var searchResults: [FoodItem] = []
    @State private var isSearching = false
    @State private var showingAddFoodView = false
    @State private var showingFilters = false
    @State private var selectedBrand: String?
    @State private var selectedCategory: String?
    @State private var errorMessage: String?
    @State private var hasSearched = false
    
    private let maxSelectableItems = 10
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Filter Bar
                if showingFilters {
                    filterBar
                }
                
                // Content
                if isSearching {
                    ModernLoadingView(message: "Searching foods...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && hasSearched {
                    noResultsView
                } else if searchResults.isEmpty {
                    initialStateView
                } else {
                    resultsListView
                }
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Search Foods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.red.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .disabled(selectedFoods.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingAddFoodView) {
            AddFoodView { newFood in
                // Add the newly created food to selection
                selectedFoods.insert(newFood.id)
                // Refresh search results to include new food
                performSearch()
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Search Bar
    
    /**
     * Search bar with real-time search capability
     */
    private var searchBar: some View {
        VStack(spacing: ModernDesignSystem.Spacing.sm) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    TextField("Search pet foods...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                            hasSearched = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.softCream)
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                
                Button(action: { performSearch() }) {
                    Text("Search")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.primary)
                        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                }
                .disabled(searchText.isEmpty)
            }
            
            // Filter button
            Button(action: { showingFilters.toggle() }) {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filters")
                    if selectedBrand != nil || selectedCategory != nil {
                        Text("(\(filterCount))")
                            .font(ModernDesignSystem.Typography.caption)
                    }
                }
                .font(ModernDesignSystem.Typography.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.primary)
            }
            .padding(.bottom, ModernDesignSystem.Spacing.xs)
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        .padding(.vertical, ModernDesignSystem.Spacing.md)
    }
    
    // MARK: - Filter Bar
    
    /**
     * Filter bar for brand and category selection
     */
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Filters")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    // Clear filters
                    if selectedBrand != nil || selectedCategory != nil {
                        Button(action: clearFilters) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear")
                            }
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.error)
                            .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                            .padding(.vertical, 6)
                            .background(ModernDesignSystem.Colors.error.opacity(0.1))
                            .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        }
                    }
                    
                    // Category filters
                    ForEach(foodService.getFoodCategories(), id: \.self) { category in
                        SearchFilterChip(
                            title: category,
                            isSelected: selectedCategory == category,
                            onTap: {
                                selectedCategory = selectedCategory == category ? nil : category
                                if hasSearched {
                                    performSearch()
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        .padding(.bottom, ModernDesignSystem.Spacing.md)
    }
    
    // MARK: - Initial State View
    
    /**
     * Initial state before any search
     */
    private var initialStateView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            Spacer()
            
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(ModernDesignSystem.Colors.primary.opacity(0.3))
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text("Search Pet Foods")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Search our database of pet foods\nto compare nutritional values")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            if !selectedFoods.isEmpty {
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Text("\(selectedFoods.count) food\(selectedFoods.count == 1 ? "" : "s") selected")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    Text("Add \(max(0, 2 - selectedFoods.count)) more to compare")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.primary.opacity(0.1))
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            }
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.xl)
    }
    
    // MARK: - No Results View
    
    /**
     * View shown when search returns no results
     */
    private var noResultsView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            Spacer()
            
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.warning)
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text("No Results Found")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("We couldn't find \"\(searchText)\" in our database")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Button(action: { showingAddFoodView = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add This Food")
                    }
                    .frame(maxWidth: .infinity)
                    .modernButton(style: .primary)
                }
                
                Text("Help us grow our database!")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.xl)
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.xl)
    }
    
    // MARK: - Results List View
    
    /**
     * List of search results
     */
    private var resultsListView: some View {
        VStack(spacing: 0) {
            // Results header
            HStack {
                Text("\(searchResults.count) result\(searchResults.count == 1 ? "" : "s")")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Spacer()
                
                if !selectedFoods.isEmpty {
                    Text("\(selectedFoods.count) selected")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(ModernDesignSystem.Colors.primary)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.vertical, ModernDesignSystem.Spacing.sm)
            
            // Results list
            ScrollView {
                LazyVStack(spacing: ModernDesignSystem.Spacing.sm) {
                    ForEach(searchResults) { food in
                        SearchResultCard(
                            food: food,
                            isSelected: selectedFoods.contains(food.id),
                            onTap: {
                                toggleFoodSelection(food.id)
                            }
                        )
                    }
                    
                    // Add food button
                    Button(action: { showingAddFoodView = true }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Don't see your food? Add it!")
                        }
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(ModernDesignSystem.Colors.primary.opacity(0.1))
                        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                    }
                    .padding(.top, ModernDesignSystem.Spacing.md)
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /**
     * Perform search with current query and filters
     */
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        errorMessage = nil
        
        Task {
            do {
                let results: [FoodItem]
                
                if selectedBrand != nil || selectedCategory != nil {
                    results = try await foodService.searchFoodsWithFilters(
                        query: searchText,
                        brand: selectedBrand,
                        category: selectedCategory
                    )
                } else {
                    results = try await foodService.searchFoods(query: searchText)
                }
                
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Search failed: \(error.localizedDescription)"
                    isSearching = false
                    searchResults = []
                }
            }
        }
    }
    
    /**
     * Toggle food selection
     * - Parameter foodId: ID of the food to toggle
     */
    private func toggleFoodSelection(_ foodId: String) {
        if selectedFoods.contains(foodId) {
            selectedFoods.remove(foodId)
        } else {
            // Check if we've reached the maximum
            if selectedFoods.count >= maxSelectableItems {
                errorMessage = "Maximum \(maxSelectableItems) foods can be selected for comparison"
                return
            }
            selectedFoods.insert(foodId)
        }
    }
    
    /**
     * Clear all filters
     */
    private func clearFilters() {
        selectedBrand = nil
        selectedCategory = nil
        if hasSearched {
            performSearch()
        }
    }
    
    /**
     * Get count of active filters
     */
    private var filterCount: Int {
        var count = 0
        if selectedBrand != nil { count += 1 }
        if selectedCategory != nil { count += 1 }
        return count
    }
}

// MARK: - Search Result Card

/**
 * Search result card showing food item details
 */
struct SearchResultCard: View {
    let food: FoodItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? ModernDesignSystem.Colors.success : ModernDesignSystem.Colors.textSecondary)
                
                // Food details
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(food.name)
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                    
                    if let brand = food.brand {
                        Text(brand)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    // Nutritional highlights
                    if let nutritionalInfo = food.nutritionalInfo {
                        HStack(spacing: ModernDesignSystem.Spacing.sm) {
                            if let calories = nutritionalInfo.caloriesPer100g {
                                NutritionPill(
                                    value: "\(Int(calories))",
                                    unit: "kcal",
                                    color: ModernDesignSystem.Colors.warning
                                )
                            }
                            
                            if let protein = nutritionalInfo.proteinPercentage {
                                NutritionPill(
                                    value: "\(Int(protein))",
                                    unit: "% protein",
                                    color: ModernDesignSystem.Colors.success
                                )
                            }
                            
                            if let fat = nutritionalInfo.fatPercentage {
                                NutritionPill(
                                    value: "\(Int(fat))",
                                    unit: "% fat",
                                    color: ModernDesignSystem.Colors.primary
                                )
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(ModernDesignSystem.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
        .background(isSelected ? ModernDesignSystem.Colors.success.opacity(0.05) : ModernDesignSystem.Colors.surface)
        .modernCard()
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(isSelected ? ModernDesignSystem.Colors.success : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Nutrition Pill

/**
 * Small pill showing nutritional value
 */
struct NutritionPill: View {
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(value)
                .font(ModernDesignSystem.Typography.caption)
                .fontWeight(.semibold)
            Text(unit)
                .font(ModernDesignSystem.Typography.caption2)
        }
        .foregroundColor(color)
        .padding(.horizontal, ModernDesignSystem.Spacing.xs)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
    }
}

// MARK: - Search Filter Chip

/**
 * Filter chip for category selection
 */
struct SearchFilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(isSelected ? ModernDesignSystem.Colors.textOnPrimary : ModernDesignSystem.Colors.textPrimary)
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                .padding(.vertical, 6)
                .background(isSelected ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.softCream)
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        }
    }
}

#Preview {
    EnhancedFoodSearchView(selectedFoods: .constant([]))
}

