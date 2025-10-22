//
//  SensitivityAssessmentCard.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import SwiftUI

/**
 * Card component for displaying pet sensitivity assessment results
 * 
 * Shows personalized warnings and recommendations based on the pet's
 * known sensitivities and scanned ingredients.
 * 
 * Follows Trust & Nature Design System standards with proper
 * color coding and accessibility features.
 */
struct SensitivityAssessmentCard: View {
    let assessment: SensitivityAssessment
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
            // Header with pet name and severity indicator
            HStack {
                Image(systemName: iconForSeverity(assessment.severityLevel))
                    .font(.system(size: 24))
                    .foregroundColor(colorForSeverity(assessment.severityLevel))
                    .accessibilityLabel("Sensitivity status: \(assessment.severityLevel.displayName)")
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Sensitivity Assessment")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("for \(assessment.petName)")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Primary warning message
            if let warning = assessment.primaryWarning {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(colorForSeverity(assessment.severityLevel))
                        .accessibilityLabel("Warning icon")
                    
                    Text(warning)
                        .font(ModernDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(colorForSeverity(assessment.severityLevel))
                        .accessibilityLabel("Warning: \(warning)")
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(colorForSeverity(assessment.severityLevel).opacity(0.1))
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            }
            
            // Details (always visible)
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
                // Matched sensitivities
                if !assessment.matchedSensitivities.isEmpty {
                    MatchedSensitivitiesList(sensitivities: assessment.matchedSensitivities)
                }
                
                // Safe ingredients
                if !assessment.safeIngredients.isEmpty {
                    SensitivitySafeIngredientsList(ingredients: assessment.safeIngredients)
                }
                
                // Recommendations
                if !assessment.recommendations.isEmpty {
                    RecommendationsList(recommendations: assessment.recommendations)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(backgroundForSeverity(assessment.severityLevel))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(colorForSeverity(assessment.severityLevel), lineWidth: 2)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Helper Methods
    
    private func colorForSeverity(_ severity: SensitivitySeverity) -> Color {
        switch severity {
        case .none:
            return ModernDesignSystem.Colors.safe
        case .low:
            return ModernDesignSystem.Colors.caution
        case .moderate:
            return ModernDesignSystem.Colors.warmCoral
        case .high:
            return ModernDesignSystem.Colors.unsafe
        }
    }
    
    private func iconForSeverity(_ severity: SensitivitySeverity) -> String {
        switch severity {
        case .none:
            return "checkmark.circle.fill"
        case .low:
            return "exclamationmark.triangle.fill"
        case .moderate:
            return "exclamationmark.octagon.fill"
        case .high:
            return "xmark.octagon.fill"
        }
    }
    
    private func backgroundForSeverity(_ severity: SensitivitySeverity) -> Color {
        switch severity {
        case .none:
            return ModernDesignSystem.Colors.safe.opacity(0.1)
        case .low:
            return ModernDesignSystem.Colors.caution.opacity(0.1)
        case .moderate:
            return ModernDesignSystem.Colors.warmCoral.opacity(0.1)
        case .high:
            return ModernDesignSystem.Colors.unsafe.opacity(0.1)
        }
    }
}

// MARK: - Supporting Views

struct MatchedSensitivitiesList: View {
    let sensitivities: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    .accessibilityLabel("Warning icon")
                Text("Matched Sensitivities (\(sensitivities.count))")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    .accessibilityAddTraits(.isHeader)
            }
            
            ForEach(sensitivities, id: \.self) { sensitivity in
                HStack {
                    Text("•")
                        .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    Text(sensitivity.capitalized)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityLabel("Sensitivity: \(sensitivity.capitalized)")
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

struct SensitivitySafeIngredientsList: View {
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
                    Text(ingredient.capitalized)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityLabel("Safe ingredient: \(ingredient.capitalized)")
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

struct RecommendationsList: View {
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                    .accessibilityLabel("Recommendations icon")
                Text("Recommendations")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                    .accessibilityAddTraits(.isHeader)
            }
            
            ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .font(ModernDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                        .accessibilityHidden(true)
                    
                    Text(recommendation)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityLabel("Recommendation \(index + 1): \(recommendation)")
                    
                    Spacer()
                }
                .padding(.leading, ModernDesignSystem.Spacing.md)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.goldenYellow.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.goldenYellow, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    let sampleAssessment = SensitivityAssessment(
        petId: "pet-1",
        petName: "Buddy",
        hasSensitivityMatches: true,
        matchedSensitivities: ["chicken", "wheat"],
        safeIngredients: ["rice", "carrots", "peas"],
        warningIngredients: ["chicken meal", "wheat flour"],
        recommendations: [
            "⚠️ This product contains ingredients that may cause sensitivity reactions in Buddy",
            "Consider avoiding this product or consulting with your veterinarian",
            "The problematic ingredients are: Chicken, Wheat",
            "Always monitor Buddy for any adverse reactions when trying new foods"
        ]
    )
    
    ScrollView {
        SensitivityAssessmentCard(assessment: sampleAssessment)
            .padding()
    }
    .background(ModernDesignSystem.Colors.softCream)
}
