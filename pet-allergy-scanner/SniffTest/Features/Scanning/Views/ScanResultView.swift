//
//  ScanResultView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct ScanResultView: View {
    let scan: Scan
    @Environment(\.dismiss) private var dismiss
    @State private var settingsManager = SettingsManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.xl) {
                    if let result = scan.result {
                        // Overall Safety Result
                        SafetyResultCard(result: result, settingsManager: settingsManager)
                        
                        // Ingredients Analysis
                        if !result.ingredientsFound.isEmpty {
                            IngredientsAnalysisSection(result: result)
                        }
                        
                        // Nutritional Analysis (if available)
                        if let nutritionalAnalysis = scan.nutritionalAnalysis {
                            NutritionalAnalysisSection(nutritionalAnalysis: nutritionalAnalysis)
                        }
                        
                        // Analysis Details (only show if detailed reports are enabled)
                        if settingsManager.shouldShowDetailedAnalysis && !result.analysisDetails.isEmpty {
                            AnalysisDetailsSection(details: result.analysisDetails)
                        }
                    } else {
                        // Loading state
                        LoadingStateView()
                    }
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
            .background(ModernDesignSystem.Colors.softCream)
            .navigationTitle("Scan Results")
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
        }
    }
}

struct SafetyResultCard: View {
    let result: ScanResult
    let settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            HStack {
                Image(systemName: iconForSafety(result.overallSafety))
                    .font(.system(size: 40))
                    .foregroundColor(colorForSafety(result.overallSafety))
                    .accessibilityLabel("Safety status: \(result.safetyDisplayName)")
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(result.safetyDisplayName)
                        .font(ModernDesignSystem.Typography.title2)
                        .foregroundColor(colorForSafety(result.overallSafety))
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Overall Safety")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Show confidence score only if detailed reports are enabled
            if settingsManager.shouldShowDetailedAnalysis && result.confidenceScore > 0 {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    HStack {
                        Text("Confidence Score")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("\(Int(result.confidenceScore * 100))%")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                    
                    ProgressView(value: result.confidenceScore)
                        .progressViewStyle(LinearProgressViewStyle(tint: colorForSafety(result.overallSafety)))
                        .accessibilityLabel("Confidence score: \(Int(result.confidenceScore * 100)) percent")
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(colorForSafety(result.overallSafety).opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(colorForSafety(result.overallSafety), lineWidth: 2)
        )
    }
    
    private func colorForSafety(_ safety: String) -> Color {
        switch safety {
        case "safe":
            return ModernDesignSystem.Colors.safe
        case "caution":
            return ModernDesignSystem.Colors.caution
        case "unsafe":
            return ModernDesignSystem.Colors.unsafe
        default:
            return ModernDesignSystem.Colors.unknown
        }
    }
    
    private func iconForSafety(_ safety: String) -> String {
        switch safety {
        case "safe":
            return "checkmark.circle.fill"
        case "caution":
            return "exclamationmark.triangle.fill"
        case "unsafe":
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
}

struct IngredientsAnalysisSection: View {
    let result: ScanResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
            Text("Ingredients Analysis")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            
            if !result.unsafeIngredients.isEmpty {
                UnsafeIngredientsList(ingredients: result.unsafeIngredients)
            }
            
            if !result.safeIngredients.isEmpty {
                SafeIngredientsList(ingredients: result.safeIngredients)
            }
        }
        .modernCard()
    }
}

struct UnsafeIngredientsList: View {
    let ingredients: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    .accessibilityLabel("Warning icon")
                Text("Unsafe Ingredients (\(ingredients.count))")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    .accessibilityAddTraits(.isHeader)
            }
            
            ForEach(ingredients, id: \.self) { ingredient in
                HStack {
                    Text("•")
                        .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    Text(ingredient)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityLabel("Unsafe ingredient: \(ingredient)")
                    Spacer()
                }
                .padding(.leading, ModernDesignSystem.Spacing.md)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.warmCoral.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.warmCoral, lineWidth: 1)
        )
    }
}

struct SafeIngredientsList: View {
    let ingredients: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.safe)
                    .accessibilityLabel("Safe icon")
                Text("Safe Ingredients (\(ingredients.count))")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.safe)
                    .accessibilityAddTraits(.isHeader)
            }
            
            ForEach(ingredients, id: \.self) { ingredient in
                HStack {
                    Text("•")
                        .foregroundColor(ModernDesignSystem.Colors.safe)
                    Text(ingredient)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityLabel("Safe ingredient: \(ingredient)")
                    Spacer()
                }
                .padding(.leading, ModernDesignSystem.Spacing.md)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.safe.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.safe, lineWidth: 1)
        )
    }
}

struct NutritionalAnalysisSection: View {
    let nutritionalAnalysis: NutritionalAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .accessibilityLabel("Nutritional analysis icon")
                Text("Nutritional Analysis")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            
            // Calorie Information
            if let caloriesPerServing = nutritionalAnalysis.caloriesPerServing,
               let servingSize = nutritionalAnalysis.servingSizeG {
                CalorieInfoCard(
                    caloriesPerServing: caloriesPerServing,
                    servingSize: servingSize,
                    caloriesPer100G: nutritionalAnalysis.caloriesPer100G
                )
            }
            
            // Macronutrients
            if hasMacronutrientData() {
                MacronutrientsCard(nutritionalAnalysis: nutritionalAnalysis)
            }
            
            // Minerals
            if hasMineralData() {
                NutritionalMineralsCard(nutritionalAnalysis: nutritionalAnalysis)
            }
        }
        .modernCard()
    }
    
    private func hasMacronutrientData() -> Bool {
        return nutritionalAnalysis.proteinPercent != nil ||
               nutritionalAnalysis.fatPercent != nil ||
               nutritionalAnalysis.fiberPercent != nil ||
               nutritionalAnalysis.moisturePercent != nil ||
               nutritionalAnalysis.ashPercent != nil
    }
    
    private func hasMineralData() -> Bool {
        return nutritionalAnalysis.calciumPercent != nil ||
               nutritionalAnalysis.phosphorusPercent != nil
    }
}

struct CalorieInfoCard: View {
    let caloriesPerServing: Double
    let servingSize: Double
    let caloriesPer100G: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Calorie Information")
                .font(ModernDesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                HStack {
                    Text("Per Serving")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Spacer()
                    Text("\(Int(caloriesPerServing)) kcal")
                        .font(ModernDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                }
                
                HStack {
                    Text("Serving Size")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Spacer()
                    Text("\(Int(servingSize))g")
                        .font(ModernDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                }
                
                if let caloriesPer100G = caloriesPer100G {
                    HStack {
                        Text("Per 100g")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("\(Int(caloriesPer100G)) kcal")
                            .font(ModernDesignSystem.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.primary.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.primary, lineWidth: 1)
        )
    }
}

struct MacronutrientsCard: View {
    let nutritionalAnalysis: NutritionalAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Macronutrients")
                .font(ModernDesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                if let protein = nutritionalAnalysis.proteinPercent {
                    NutrientRow(name: "Protein", value: protein, unit: "%")
                }
                if let fat = nutritionalAnalysis.fatPercent {
                    NutrientRow(name: "Fat", value: fat, unit: "%")
                }
                if let fiber = nutritionalAnalysis.fiberPercent {
                    NutrientRow(name: "Fiber", value: fiber, unit: "%")
                }
                if let moisture = nutritionalAnalysis.moisturePercent {
                    NutrientRow(name: "Moisture", value: moisture, unit: "%")
                }
                if let ash = nutritionalAnalysis.ashPercent {
                    NutrientRow(name: "Ash", value: ash, unit: "%")
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
    }
}

struct NutritionalMineralsCard: View {
    let nutritionalAnalysis: NutritionalAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Minerals")
                .font(ModernDesignSystem.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                if let calcium = nutritionalAnalysis.calciumPercent {
                    NutrientRow(name: "Calcium", value: calcium, unit: "%")
                }
                if let phosphorus = nutritionalAnalysis.phosphorusPercent {
                    NutrientRow(name: "Phosphorus", value: phosphorus, unit: "%")
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
    }
}

struct NutrientRow: View {
    let name: String
    let value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(name)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            Spacer()
            Text("\(String(format: "%.1f", value))\(unit)")
                .font(ModernDesignSystem.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
        }
    }
}

struct AnalysisDetailsSection: View {
    let details: [String: String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Analysis Details")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            
            ForEach(Array(details.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key.capitalized)
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Spacer()
                    Text(details[key] ?? "")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
    }
}

/**
 * Loading state view with Trust & Nature styling
 */
struct LoadingStateView: View {
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(ModernDesignSystem.Colors.primary)
                .accessibilityLabel("Loading")
            
            Text("Analysis in progress...")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .padding(ModernDesignSystem.Spacing.xl)
        .modernCard()
    }
}

#Preview {
    let sampleResult = ScanResult(
        productName: "Sample Pet Food",
        brand: "Sample Brand",
        ingredientsFound: ["chicken", "rice", "corn"],
        unsafeIngredients: ["corn"],
        safeIngredients: ["chicken", "rice"],
        overallSafety: "caution",
        confidenceScore: 0.85,
        analysisDetails: [
            "total_ingredients": "3",
            "unsafe_count": "1",
            "safe_count": "2"
        ]
    )
    
    let sampleNutritionalAnalysis = NutritionalAnalysis(
        servingSizeG: 100.0,
        caloriesPerServing: 350.0,
        caloriesPer100G: 350.0,
        proteinPercent: 25.0,
        fatPercent: 12.0,
        fiberPercent: 3.0,
        moisturePercent: 10.0,
        ashPercent: 6.0,
        calciumPercent: 1.2,
        phosphorusPercent: 0.8
    )
    
    let sampleScan = Scan(
        id: "1",
        userId: "user1",
        petId: "pet1",
        imageUrl: nil,
        rawText: "chicken, rice, corn",
        status: .completed,
        result: sampleResult,
        nutritionalAnalysis: sampleNutritionalAnalysis,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    ScanResultView(scan: sampleScan)
}
