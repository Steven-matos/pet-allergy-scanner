//
//  FoodSelectionView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import SwiftUI

/**
 * Food Selection View
 * 
 * Interface for users to select or scan food items for feeding logs.
 * Follows SOLID principles with single responsibility for food selection
 * Implements DRY by reusing common UI components
 * Follows KISS by keeping the interface simple and intuitive
 */
struct FoodSelectionView: View {
    @Binding var selectedFood: FoodItem?
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var foodService = FoodService.shared
    @State private var searchText = ""
    @State private var showingScanner = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var filteredFoods: [FoodItem] {
        if searchText.isEmpty {
            return foodService.recentFoods
        } else {
            return foodService.recentFoods.filter { food in
                food.name.localizedCaseInsensitiveContains(searchText) ||
                (food.brand?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                if isLoading {
                    ModernLoadingView(message: "Loading foods...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    foodList
                }
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Select Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Scan") {
                        showingScanner = true
                    }
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            FoodScannerView { scannedFood in
                selectedFood = scannedFood
                dismiss()
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
        .onAppear {
            loadRecentFoods()
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            TextField("Search foods...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .font(ModernDesignSystem.Typography.caption)
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .padding(ModernDesignSystem.Spacing.lg)
    }
    
    // MARK: - Food List
    
    private var foodList: some View {
        ScrollView {
            LazyVStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Scan Option
                scanOptionCard
                
                // Recent Foods
                if !filteredFoods.isEmpty {
                    recentFoodsSection
                } else if !searchText.isEmpty {
                    noResultsView
                } else {
                    emptyStateView
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
    }
    
    // MARK: - Scan Option Card
    
    private var scanOptionCard: some View {
        VStack {
            Button(action: { showingScanner = true }) {
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .font(.title2)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Scan Barcode")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text("Scan your pet's food package")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .font(.caption)
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Recent Foods Section
    
    private var recentFoodsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Text(searchText.isEmpty ? "Recent Foods" : "Search Results")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Spacer()
                
                Text("\(filteredFoods.count) items")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            ForEach(filteredFoods) { food in
                FoodItemCard(
                    food: food,
                    isSelected: selectedFood?.id == food.id,
                    onTap: {
                        selectedFood = food
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary.opacity(0.3))
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text("No Recent Foods")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Scan a barcode to start tracking your pet's food")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Scan First Food") {
                showingScanner = true
            }
            .modernButton(style: .primary)
        }
        .padding(ModernDesignSystem.Spacing.xl)
    }
    
    // MARK: - No Results View
    
    private var noResultsView: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text("No Results Found")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Try scanning a barcode or check your spelling")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(ModernDesignSystem.Spacing.xl)
    }
    
    // MARK: - Helper Methods
    
    /**
     * Load recent foods from the service
     */
    private func loadRecentFoods() {
        isLoading = true
        
        Task {
            do {
                try await foodService.loadRecentFoods()
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to load foods: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Food Item Card

/**
 * Food Item Card
 * Displays individual food items with nutritional info
 */
struct FoodItemCard: View {
    let food: FoodItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack {
            Button(action: onTap) {
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    // Food icon or image placeholder
                    Circle()
                        .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .foregroundColor(ModernDesignSystem.Colors.primary)
                                .font(.title3)
                        )
                    
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
                                    NutritionalBadge(
                                        value: "\(Int(calories))",
                                        unit: "kcal",
                                        color: ModernDesignSystem.Colors.warning
                                    )
                                }
                                
                                if let protein = nutritionalInfo.proteinPercentage {
                                    NutritionalBadge(
                                        value: "\(Int(protein))",
                                        unit: "%",
                                        color: ModernDesignSystem.Colors.success
                                    )
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.success)
                            .font(.title3)
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .font(.caption)
                    }
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .modernCard()
    }
}

// MARK: - Nutritional Badge

/**
 * Small badge showing nutritional values
 */
struct NutritionalBadge: View {
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(value)
                .font(ModernDesignSystem.Typography.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(unit)
                .font(ModernDesignSystem.Typography.caption2)
                .foregroundColor(color)
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.xs)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
    }
}

// MARK: - Food Scanner View

/**
 * Barcode scanner for food items
 */
struct FoodScannerView: View {
    let onFoodScanned: (FoodItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Barcode Scanner")
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Point your camera at the barcode")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Spacer()
                
                // Scanner placeholder - would integrate with actual barcode scanning
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .fill(ModernDesignSystem.Colors.softCream)
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(ModernDesignSystem.Colors.primary)
                            
                            Text("Scanner Coming Soon")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                    )
                
                Spacer()
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .navigationTitle("Scan Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FoodSelectionView(selectedFood: .constant(nil))
}
