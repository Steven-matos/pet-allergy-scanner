//
//  ScanResultView.swift
//  pet-allergy-scanner
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
                VStack(alignment: .leading, spacing: 20) {
                    // Overall Safety Result
                    if let result = scan.result {
                        SafetyResultCard(result: result, settingsManager: settingsManager)
                        
                        // Ingredients Analysis
                        if !result.ingredientsFound.isEmpty {
                            IngredientsAnalysisSection(result: result)
                        }
                        
                        // Analysis Details (only show if detailed reports are enabled)
                        if settingsManager.shouldShowDetailedAnalysis && !result.analysisDetails.isEmpty {
                            AnalysisDetailsSection(details: result.analysisDetails)
                        }
                    } else {
                        Text("Analysis in progress...")
                            .font(.headline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Results")
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

struct SafetyResultCard: View {
    let result: ScanResult
    let settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: iconForSafety(result.overallSafety))
                    .font(.system(size: 40))
                    .foregroundColor(colorForSafety(result.overallSafety))
                    .accessibilityLabel("Safety status: \(result.safetyDisplayName)")
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.safetyDisplayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(colorForSafety(result.overallSafety))
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Overall Safety")
                        .font(.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Show confidence score only if detailed reports are enabled
            if settingsManager.shouldShowDetailedAnalysis && result.confidenceScore > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Confidence Score")
                            .font(.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("\(Int(result.confidenceScore * 100))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                    
                    ProgressView(value: result.confidenceScore)
                        .progressViewStyle(LinearProgressViewStyle(tint: colorForSafety(result.overallSafety)))
                        .accessibilityLabel("Confidence score: \(Int(result.confidenceScore * 100)) percent")
                }
            }
        }
        .padding()
        .background(colorForSafety(result.overallSafety).opacity(0.1))
        .cornerRadius(12)
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Ingredients Analysis")
                .font(.headline)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if !result.unsafeIngredients.isEmpty {
                UnsafeIngredientsList(ingredients: result.unsafeIngredients)
            }
            
            if !result.safeIngredients.isEmpty {
                SafeIngredientsList(ingredients: result.safeIngredients)
            }
        }
    }
}

struct UnsafeIngredientsList: View {
    let ingredients: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    .accessibilityLabel("Warning icon")
                Text("Unsafe Ingredients (\(ingredients.count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    .accessibilityAddTraits(.isHeader)
            }
            
            ForEach(ingredients, id: \.self) { ingredient in
                HStack {
                    Text("•")
                        .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    Text(ingredient)
                        .font(.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityLabel("Unsafe ingredient: \(ingredient)")
                    Spacer()
                }
                .padding(.leading, 16)
            }
        }
        .padding()
        .background(ModernDesignSystem.Colors.warmCoral.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SafeIngredientsList: View {
    let ingredients: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.safe)
                    .accessibilityLabel("Safe icon")
                Text("Safe Ingredients (\(ingredients.count))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.safe)
                    .accessibilityAddTraits(.isHeader)
            }
            
            ForEach(ingredients, id: \.self) { ingredient in
                HStack {
                    Text("•")
                        .foregroundColor(ModernDesignSystem.Colors.safe)
                    Text(ingredient)
                        .font(.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityLabel("Safe ingredient: \(ingredient)")
                    Spacer()
                }
                .padding(.leading, 16)
            }
        }
        .padding()
        .background(ModernDesignSystem.Colors.safe.opacity(0.1))
        .cornerRadius(8)
    }
}

struct AnalysisDetailsSection: View {
    let details: [String: String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Details")
                .font(.headline)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            ForEach(Array(details.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key.capitalized)
                        .font(.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Spacer()
                    Text(details[key] ?? "")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                }
            }
        }
        .padding()
        .background(ModernDesignSystem.Colors.surfaceVariant)
        .cornerRadius(8)
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
    
    let sampleScan = Scan(
        id: "1",
        userId: "user1",
        petId: "pet1",
        imageUrl: nil,
        rawText: "chicken, rice, corn",
        status: .completed,
        result: sampleResult,
        createdAt: Date(),
        updatedAt: Date()
    )
    
    ScanResultView(scan: sampleScan)
}
