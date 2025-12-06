//
//  ScanResultView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct ScanResultView: View {
    let scan: Scan
    let onDismissAll: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var settingsManager = SettingsManager.shared
    @StateObject private var sensitivityService = PetSensitivityService()
    @State private var sensitivityAssessment: SensitivityAssessment?
    @State private var isLoadingSensitivity = false
    @State private var sensitivityError: String?
    @State private var hasAttemptedSensitivityLoad = false
    
    init(scan: Scan, onDismissAll: (() -> Void)? = nil) {
        self.scan = scan
        self.onDismissAll = onDismissAll
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.xl) {
                    if let result = scan.result {
                        // Ingredients Analysis
                        if !result.ingredientsFound.isEmpty {
                            IngredientsAnalysisSection(result: result)
                        } else {
                            // Show a message if no ingredients were found
                            VStack(spacing: ModernDesignSystem.Spacing.md) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(ModernDesignSystem.Colors.warning)
                                
                                Text("No Ingredients Found")
                                    .font(ModernDesignSystem.Typography.title3)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                
                                Text("The scan didn't detect any ingredients. This might be due to image quality or the product not being in our database.")
                                    .font(ModernDesignSystem.Typography.body)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(ModernDesignSystem.Spacing.lg)
                            .modernCard()
                        }
                        
                        // Nutritional Analysis (if available)
                        if let nutritionalAnalysis = scan.nutritionalAnalysis {
                            NutritionalAnalysisSection(nutritionalAnalysis: nutritionalAnalysis)
                        }
                        
                        // Pet Sensitivity Assessment (always visible)
                        if let sensitivityAssessment = sensitivityAssessment {
                            SensitivityAssessmentCard(assessment: sensitivityAssessment)
                        } else if isLoadingSensitivity {
                            SensitivityLoadingView()
                        } else if let error = sensitivityError {
                            SensitivityErrorView(error: error) {
                                loadSensitivityAssessment()
                            }
                        } else {
                            // Show loading state if sensitivity assessment hasn't been attempted yet
                            SensitivityLoadingView()
                        }
                        
                        // Veterinary Disclaimer
                        VeterinaryDisclaimerCard()
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
                        if let onDismissAll = onDismissAll {
                            onDismissAll()
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
            .onAppear {
                print("🔍 ScanResultView: onAppear called")
                if let result = scan.result {
                    print("🔍 ScanResultView: Displaying scan result")
                    print("🔍 ScanResultView: Ingredients found: \(result.ingredientsFound.count)")
                    print("🔍 ScanResultView: Unsafe ingredients: \(result.unsafeIngredients.count)")
                    print("🔍 ScanResultView: Safe ingredients: \(result.safeIngredients.count)")
                } else {
                    print("⚠️ ScanResultView: No scan result available")
                }
                
                // Load sensitivity assessment immediately
                loadSensitivityAssessment()
                
                // Ensure sensitivity assessment loads even if there are timing issues
                // Use Task instead of DispatchQueue for better Swift concurrency
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    if !hasAttemptedSensitivityLoad && !isLoadingSensitivity {
                        print("🔍 ScanResultView: Retrying sensitivity assessment load")
                        loadSensitivityAssessment()
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Load sensitivity assessment for the current scan
     */
    private func loadSensitivityAssessment() {
        guard scan.result != nil else { 
            print("⚠️ ScanResultView: No scan result available for sensitivity assessment")
            isLoadingSensitivity = false
            hasAttemptedSensitivityLoad = true
            return 
        }
        
        // Prevent multiple simultaneous loads
        guard !isLoadingSensitivity else {
            print("⚠️ ScanResultView: Sensitivity assessment already loading")
            return
        }
        
        hasAttemptedSensitivityLoad = true
        isLoadingSensitivity = true
        sensitivityError = nil
        
        print("🔍 ScanResultView: Starting sensitivity assessment for scan")
        
        // Add timeout protection to prevent isLoadingSensitivity from getting stuck
        let timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            if isLoadingSensitivity {
                print("⚠️ ScanResultView: Sensitivity assessment timeout - resetting isLoadingSensitivity")
                isLoadingSensitivity = false
            }
        }
        
        Task {
            defer {
                timeoutTask.cancel()
            }
            
            do {
                let assessment = try await sensitivityService.assessSensitivities(for: scan)
                await MainActor.run {
                    print("✅ ScanResultView: Sensitivity assessment completed successfully")
                    self.sensitivityAssessment = assessment
                    self.isLoadingSensitivity = false
                }
            } catch {
                await MainActor.run {
                    print("❌ ScanResultView: Sensitivity assessment failed: \(error.localizedDescription)")
                    self.sensitivityError = error.localizedDescription
                    self.isLoadingSensitivity = false
                }
            }
        }
    }
}

/**
 * Safety result card displaying overall safety assessment
 * 
 * Overall Safety Calculation:
 * - "dangerous" if any dangerous ingredients are found
 * - "caution" if any caution ingredients are found (and no dangerous ones)
 * - "unknown" if any unknown ingredients are found (and no dangerous/caution ones)
 * - "safe" if all ingredients are safe
 */
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
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
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
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
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
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
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
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
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
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
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
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
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

/**
 * Loading view for sensitivity assessment
 */
struct SensitivityLoadingView: View {
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .accessibilityLabel("Pet sensitivity icon")
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Sensitivity Assessment")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Analyzing for your pet...")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(ModernDesignSystem.Colors.primary)
                    .accessibilityLabel("Loading sensitivity assessment")
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.primary.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.primary, lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
}

/**
 * Error view for sensitivity assessment
 */
struct SensitivityErrorView: View {
    let error: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    .accessibilityLabel("Error icon")
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Sensitivity Assessment")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Unable to load")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            Text(error)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.leading)
            
            Button("Retry") {
                retryAction()
            }
            .modernButton(style: .secondary)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.warmCoral.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.warmCoral, lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
}

/**
 * Veterinary disclaimer card reminding users to consult their vet
 * 
 * Displays an important disclaimer that this app does not replace
 * professional veterinary assessment and users should always consult
 * with their veterinarian.
 */
struct VeterinaryDisclaimerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "stethoscope")
                    .font(.system(size: 20))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .accessibilityLabel("Veterinary icon")
                
                Text("Important Disclaimer")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text("This analysis is for informational purposes only and does not replace professional veterinary assessment.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                
                Text("Always consult with your veterinarian before making any changes to your pet's diet or if you have concerns about your pet's health.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.primary.opacity(0.05))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.primary.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
}
