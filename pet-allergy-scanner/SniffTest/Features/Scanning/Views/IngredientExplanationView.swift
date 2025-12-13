//
//  IngredientExplanationView.swift
//  SniffTest
//
//  Created for Gap #3: Analysis Trust Framing
//  Explainability layer for flagged ingredients
//

import SwiftUI

/**
 * IngredientExplanationView - Trust Framing for Ingredient Analysis
 *
 * Displays clear, calm explanations for why an ingredient is flagged:
 * - Why was this flagged?
 * - For which species?
 * - At what confidence level?
 *
 * Design Principles:
 * - Calm language (not alarmist)
 * - Clear reasoning (not absolute)
 * - Actionable guidance (what to do)
 *
 * Examples of calm language:
 * - "Common allergen in dogs" (not "DANGEROUS!")
 * - "Unsafe for cats only" (not "TOXIC!")
 * - "Generally safe, but monitor if sensitive" (not "PROCEED WITH CAUTION!")
 */
struct IngredientExplanationView: View {
    let ingredientName: String
    let explanation: IngredientExplanation
    let safetyLevel: IngredientSafety
    let confidenceLevel: Double?
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Header with ingredient name and safety badge
            headerSection
            
            // Why flagged section
            explanationSection
            
            // Expandable details
            if isExpanded {
                detailsSection
            }
            
            // Expand/collapse button
            expandButton
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(backgroundColor)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.md) {
            // Safety icon
            Image(systemName: safetyIcon)
                .font(.system(size: 24))
                .foregroundColor(safetyColor)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(ingredientName)
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                // Safety badge
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Text(safetyLevel.displayName)
                        .font(ModernDesignSystem.Typography.caption)
                        .fontWeight(.medium)
                    
                    if let confidence = confidenceLevel {
                        Text("•")
                        Text(confidenceText(confidence))
                            .font(ModernDesignSystem.Typography.caption)
                    }
                }
                .foregroundColor(safetyColor)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Explanation Section
    
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            // Why flagged
            Text(explanation.whyFlagged)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Species context (if not obvious)
            if explanation.speciesContext != "Suitable for both dogs and cats." {
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 12))
                    Text(explanation.speciesContext)
                        .font(ModernDesignSystem.Typography.subheadline)
                }
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Divider()
            
            // Confidence statement
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Label("Confidence", systemImage: "chart.bar.fill")
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text(explanation.confidenceStatement)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                // Confidence bar
                if let level = confidenceLevel {
                    ConfidenceBar(level: level)
                }
            }
            
            // Action suggestion
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Label("What to Do", systemImage: "lightbulb.fill")
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text(explanation.actionSuggestion)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Expand Button
    
    private var expandButton: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
            HStack {
                Text(isExpanded ? "Show Less" : "Learn More")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12))
            }
            .foregroundColor(ModernDesignSystem.Colors.primary)
        }
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        switch explanation.severity {
        case .safe:
            return ModernDesignSystem.Colors.safe.opacity(0.05)
        case .informational:
            return ModernDesignSystem.Colors.softCream
        case .moderate:
            return ModernDesignSystem.Colors.goldenYellow.opacity(0.05)
        case .concern:
            return ModernDesignSystem.Colors.warmCoral.opacity(0.05)
        }
    }
    
    private var borderColor: Color {
        switch explanation.severity {
        case .safe:
            return ModernDesignSystem.Colors.safe.opacity(0.2)
        case .informational:
            return ModernDesignSystem.Colors.borderPrimary.opacity(0.5)
        case .moderate:
            return ModernDesignSystem.Colors.goldenYellow.opacity(0.3)
        case .concern:
            return ModernDesignSystem.Colors.warmCoral.opacity(0.3)
        }
    }
    
    private var safetyColor: Color {
        switch safetyLevel {
        case .safe:
            return ModernDesignSystem.Colors.safe
        case .caution:
            return ModernDesignSystem.Colors.goldenYellow
        case .unsafe:
            return ModernDesignSystem.Colors.warmCoral
        case .unknown:
            return ModernDesignSystem.Colors.textSecondary
        }
    }
    
    private var safetyIcon: String {
        switch safetyLevel {
        case .safe:
            return "checkmark.circle.fill"
        case .caution:
            return "exclamationmark.circle.fill"
        case .unsafe:
            return "xmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    private func confidenceText(_ level: Double) -> String {
        switch level {
        case 0.9...: return "High confidence"
        case 0.7..<0.9: return "Moderate"
        case 0.5..<0.7: return "Low confidence"
        default: return "Very low"
        }
    }
}

// MARK: - Confidence Bar

/// Visual confidence indicator
private struct ConfidenceBar: View {
    let level: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(ModernDesignSystem.Colors.borderPrimary.opacity(0.3))
                
                // Fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(fillColor)
                    .frame(width: geometry.size.width * CGFloat(level))
            }
        }
        .frame(height: 6)
    }
    
    private var fillColor: Color {
        switch level {
        case 0.9...: return ModernDesignSystem.Colors.safe
        case 0.7..<0.9: return ModernDesignSystem.Colors.primary
        case 0.5..<0.7: return ModernDesignSystem.Colors.goldenYellow
        default: return ModernDesignSystem.Colors.warmCoral
        }
    }
}

// MARK: - Compact Explanation Badge

/**
 * Compact badge for inline ingredient explanation
 * Used in lists where full explanation would be too verbose
 */
struct IngredientExplanationBadge: View {
    let explanation: IngredientExplanation
    let safetyLevel: IngredientSafety
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Image(systemName: badgeIcon)
                .font(.system(size: 12))
            
            Text(badgeText)
                .font(ModernDesignSystem.Typography.caption)
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
        .padding(.vertical, ModernDesignSystem.Spacing.xs)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
    }
    
    private var badgeIcon: String {
        switch explanation.severity {
        case .safe: return "checkmark"
        case .informational: return "info.circle"
        case .moderate: return "exclamationmark"
        case .concern: return "exclamationmark.triangle"
        }
    }
    
    private var badgeText: String {
        switch explanation.severity {
        case .safe: return "Safe"
        case .informational: return "Info"
        case .moderate: return "Monitor"
        case .concern: return "Caution"
        }
    }
    
    private var badgeColor: Color {
        switch explanation.severity {
        case .safe: return ModernDesignSystem.Colors.safe
        case .informational: return ModernDesignSystem.Colors.primary
        case .moderate: return ModernDesignSystem.Colors.goldenYellow
        case .concern: return ModernDesignSystem.Colors.warmCoral
        }
    }
}

// MARK: - Explanation List Item

/**
 * List item showing ingredient with inline explanation
 * For use in scan results ingredient lists
 */
struct IngredientWithExplanation: View {
    let ingredient: Ingredient
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ingredient.name)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    // Brief explanation
                    Text(briefExplanation)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                IngredientExplanationBadge(
                    explanation: ingredient.explanation,
                    safetyLevel: ingredient.safetyLevel
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                ScrollView {
                    IngredientExplanationView(
                        ingredientName: ingredient.name,
                        explanation: ingredient.explanation,
                        safetyLevel: ingredient.safetyLevel,
                        confidenceLevel: ingredient.confidenceLevel
                    )
                    .padding()
                }
                .background(ModernDesignSystem.Colors.softCream)
                .navigationTitle("Ingredient Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showingDetail = false }
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    private var briefExplanation: String {
        // Return shortened version of why flagged
        let full = ingredient.explanation.whyFlagged
        if full.count > 50 {
            return String(full.prefix(47)) + "..."
        }
        return full
    }
}

// MARK: - Preview Provider

#if DEBUG
struct IngredientExplanationView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Safe ingredient
                IngredientExplanationView(
                    ingredientName: "Chicken",
                    explanation: IngredientExplanation(
                        whyFlagged: "Generally considered safe for pets.",
                        speciesContext: "Suitable for both dogs and cats.",
                        confidenceStatement: "High confidence based on extensive research.",
                        actionSuggestion: "No special precautions needed.",
                        severity: .safe
                    ),
                    safetyLevel: .safe,
                    confidenceLevel: 0.95
                )
                
                // Caution ingredient
                IngredientExplanationView(
                    ingredientName: "Wheat",
                    explanation: IngredientExplanation(
                        whyFlagged: "Common allergen in dogs. Watch for itching, digestive upset, or skin reactions.",
                        speciesContext: "More commonly affects dogs than cats.",
                        confidenceStatement: "Moderate confidence based on available studies.",
                        actionSuggestion: "Monitor for any changes in behavior, appetite, or digestion for 24-48 hours.",
                        severity: .moderate
                    ),
                    safetyLevel: .caution,
                    confidenceLevel: 0.75
                )
                
                // Unsafe ingredient
                IngredientExplanationView(
                    ingredientName: "Xylitol",
                    explanation: IngredientExplanation(
                        whyFlagged: "Known to be harmful to dogs. Avoid feeding to dogs.",
                        speciesContext: "Unsafe for dogs. Cats are less sensitive but still avoid.",
                        confidenceStatement: "High confidence based on extensive research.",
                        actionSuggestion: "Consider alternative foods or consult your veterinarian.",
                        severity: .concern
                    ),
                    safetyLevel: .unsafe,
                    confidenceLevel: 0.98
                )
            }
            .padding()
        }
        .background(Color.white)
    }
}
#endif
