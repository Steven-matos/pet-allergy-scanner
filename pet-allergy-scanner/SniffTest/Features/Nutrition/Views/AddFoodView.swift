//
//  AddFoodView.swift
//  SniffTest
//
//  Created by AI Assistant on 1/15/25.
//

import SwiftUI

/**
 * Add Food View
 * 
 * Interface for manually adding new food items to the database
 * 
 * Features:
 * - Food name and brand entry
 * - Optional barcode
 * - Nutritional information input
 * - Category selection
 * - Validation before submission
 * 
 * Follows SOLID principles with single responsibility for food creation
 * Implements DRY by reusing common form patterns
 * Follows KISS by keeping the form simple and focused
 */
struct AddFoodView: View {
    let onFoodAdded: (FoodItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var foodService = FoodService.shared
    
    // Form fields
    @State private var foodName = ""
    @State private var brand = ""
    @State private var barcode = ""
    @State private var selectedCategory: String?
    
    // Nutritional info
    @State private var caloriesPer100g = ""
    @State private var proteinPercentage = ""
    @State private var fatPercentage = ""
    @State private var fiberPercentage = ""
    @State private var moisturePercentage = ""
    @State private var ashPercentage = ""
    
    // Ingredients
    @State private var ingredientsText = ""
    @State private var commonSensitivitiesText = ""
    
    // UI state
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showValidationErrors = false
    
    private let categories = ["Dry Food", "Wet Food", "Treats", "Supplements", "Raw Food", "Other"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: ModernDesignSystem.Spacing.lg) {
                        // Header
                        headerSection
                        
                        // Basic Information
                        basicInfoSection
                        
                        // Nutritional Information
                        nutritionalInfoSection
                        
                        // Ingredients
                        ingredientsSection
                        
                        // Submit Button
                        submitButton
                    }
                    .padding(ModernDesignSystem.Spacing.lg)
                }
                .formKeyboardAvoidance()
                
                if isSubmitting {
                    LoadingOverlay(message: "Adding food...")
                }
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Add New Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
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
    }
    
    // MARK: - Header Section
    
    /**
     * Header section with icon and description
     */
    private var headerSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Add Pet Food to Database")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text("Help us grow our database by adding nutritional information")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, ModernDesignSystem.Spacing.md)
    }
    
    // MARK: - Basic Info Section
    
    /**
     * Basic information section
     */
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            SectionHeader(title: "Basic Information", icon: "info.circle.fill")
            
            // Food name
            FormField(
                label: "Food Name *",
                placeholder: "e.g., Premium Adult Dog Food",
                text: $foodName,
                isValid: !showValidationErrors || !foodName.isEmpty
            )
            
            // Brand
            FormField(
                label: "Brand",
                placeholder: "e.g., Blue Buffalo",
                text: $brand,
                isValid: true
            )
            
            // Barcode
            FormField(
                label: "Barcode/UPC",
                placeholder: "e.g., 7896543210987",
                text: $barcode,
                isValid: true,
                keyboardType: .numberPad
            )
            
            // Category
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text("Category")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        ForEach(categories, id: \.self) { category in
                            CategoryChip(
                                title: category,
                                isSelected: selectedCategory == category,
                                onTap: {
                                    selectedCategory = category
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.surface)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Nutritional Info Section
    
    /**
     * Nutritional information section
     */
    private var nutritionalInfoSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            SectionHeader(title: "Nutritional Information", icon: "chart.bar.fill")
            
            Text("All values are per 100g. Enter as many as you know.")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            // Two column grid for nutritional values
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    NutritionalField(
                        label: "Calories",
                        unit: "kcal",
                        text: $caloriesPer100g
                    )
                    
                    NutritionalField(
                        label: "Protein",
                        unit: "%",
                        text: $proteinPercentage
                    )
                }
                
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    NutritionalField(
                        label: "Fat",
                        unit: "%",
                        text: $fatPercentage
                    )
                    
                    NutritionalField(
                        label: "Fiber",
                        unit: "%",
                        text: $fiberPercentage
                    )
                }
                
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    NutritionalField(
                        label: "Moisture",
                        unit: "%",
                        text: $moisturePercentage
                    )
                    
                    NutritionalField(
                        label: "Ash",
                        unit: "%",
                        text: $ashPercentage
                    )
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.surface)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Ingredients Section
    
    /**
     * Ingredients and sensitivity triggers section
     */
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            SectionHeader(title: "Ingredients & Common Sensitivities", icon: "list.bullet")
            
            // Ingredients
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text("Ingredients")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Separate each ingredient with a comma")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                TextEditor(text: $ingredientsText)
                    .frame(height: 100)
                    .padding(ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.background)
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                            .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                    )
            }
            
            // Common Sensitivity Triggers
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text("Common Sensitivity Triggers")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Separate each ingredient with a comma (e.g., chicken, beef, corn)")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                TextEditor(text: $commonSensitivitiesText)
                    .frame(height: 60)
                    .padding(ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.background)
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                            .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                    )
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.surface)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Submit Button
    
    /**
     * Submit button
     */
    private var submitButton: some View {
        Button(action: submitFood) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Add Food to Database")
            }
            .frame(maxWidth: .infinity)
            .modernButton(style: .primary)
        }
        .disabled(!isFormValid || isSubmitting)
        .padding(.top, ModernDesignSystem.Spacing.md)
    }
    
    // MARK: - Helper Methods
    
    /**
     * Check if form is valid
     */
    private var isFormValid: Bool {
        !foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /**
     * Submit the new food
     */
    private func submitFood() {
        showValidationErrors = true
        
        guard isFormValid else {
            errorMessage = "Please enter a food name"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                // Parse ingredients
                let ingredients = ingredientsText
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                // Parse common sensitivity triggers
                let allergens = commonSensitivitiesText
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                // Create nutritional info
                let nutritionalInfo = NutritionalInfo(
                    caloriesPer100g: Double(caloriesPer100g),
                    proteinPercentage: Double(proteinPercentage),
                    fatPercentage: Double(fatPercentage),
                    fiberPercentage: Double(fiberPercentage),
                    moisturePercentage: Double(moisturePercentage),
                    ashPercentage: Double(ashPercentage),
                    ingredients: ingredients.isEmpty ? nil : ingredients,
                    allergens: allergens.isEmpty ? nil : allergens
                )
                
                // Create food item request
                let request = FoodItemRequest(
                    name: foodName.trimmingCharacters(in: .whitespacesAndNewlines),
                    brand: brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespacesAndNewlines),
                    barcode: barcode.isEmpty ? nil : barcode.trimmingCharacters(in: .whitespacesAndNewlines),
                    nutritionalInfo: nutritionalInfo
                )
                
                // Submit to backend
                let createdFood = try await foodService.createFoodItem(request)
                
                await MainActor.run {
                    isSubmitting = false
                    onFoodAdded(createdFood)
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to add food: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Supporting Views

/**
 * Section header with icon
 */
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text(title)
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
        }
    }
}

/**
 * Form field with validation
 */
struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let isValid: Bool
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            Text(label)
                .font(ModernDesignSystem.Typography.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .modernInputField()
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                        .stroke(isValid ? ModernDesignSystem.Colors.borderPrimary : ModernDesignSystem.Colors.error, lineWidth: 1)
                )
            
            if !isValid {
                Text("This field is required")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.error)
            }
        }
    }
}

/**
 * Nutritional value field
 */
struct NutritionalField: View {
    let label: String
    let unit: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            Text(label)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            HStack {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                
                Text(unit)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding(ModernDesignSystem.Spacing.sm)
            .background(ModernDesignSystem.Colors.background)
            .cornerRadius(ModernDesignSystem.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }
}

/**
 * Category selection chip
 */
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(ModernDesignSystem.Typography.subheadline)
                .foregroundColor(isSelected ? ModernDesignSystem.Colors.textOnPrimary : ModernDesignSystem.Colors.textPrimary)
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                .background(isSelected ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.background)
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: isSelected ? 0 : 1)
                )
        }
    }
}

/**
 * Loading overlay
 */
struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                ProgressView()
                    .tint(ModernDesignSystem.Colors.textOnPrimary)
                
                Text(message)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
            }
            .padding(ModernDesignSystem.Spacing.xl)
            .background(ModernDesignSystem.Colors.primary)
            .cornerRadius(ModernDesignSystem.CornerRadius.large)
        }
    }
}

#Preview {
    AddFoodView { _ in }
}

