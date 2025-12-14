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
 * Enhanced Features (Gap #3):
 * - Dog/cat visual indicators with safety badges
 * - Species severity comparison display
 * - Personalized pet context when available
 * - Per-species safety status
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
    
    /// Optional species compatibility for enhanced species display
    var speciesCompatibility: SpeciesCompatibility?
    
    /// Optional current pet for personalized context
    var currentPet: Pet?
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Header with ingredient name and safety badge
            headerSection
            
            // Species safety badges
            if speciesCompatibility != nil || currentPet != nil {
                speciesSafetySection
            }
            
            // Why flagged section
            explanationSection
            
            // Personalized pet alert (if applicable)
            if let pet = currentPet, isPetAffected(pet) {
                personalizedPetAlert(for: pet)
            }
            
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
    
    // MARK: - Species Safety Section
    
    /// Enhanced species safety display with dog/cat visual indicators
    private var speciesSafetySection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Species Safety")
                .font(ModernDesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            HStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Dog safety badge
                SpeciesSafetyBadge(
                    species: .dog,
                    safetyStatus: dogSafetyStatus,
                    isHighlighted: currentPet?.species == .dog
                )
                
                // Cat safety badge
                SpeciesSafetyBadge(
                    species: .cat,
                    safetyStatus: catSafetyStatus,
                    isHighlighted: currentPet?.species == .cat
                )
            }
            
            // Species comparison note (if different safety levels)
            if let comparison = speciesSeverityComparison {
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text(comparison)
                        .font(ModernDesignSystem.Typography.caption)
                }
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .padding(.top, ModernDesignSystem.Spacing.xs)
            }
        }
        .padding(ModernDesignSystem.Spacing.sm)
        .background(ModernDesignSystem.Colors.borderPrimary.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
    }
    
    // MARK: - Explanation Section
    
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            // Why flagged
            Text(explanation.whyFlagged)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Species context (if not obvious and no species safety section shown)
            if speciesCompatibility == nil && explanation.speciesContext != "Suitable for both dogs and cats." {
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
    
    // MARK: - Personalized Pet Alert
    
    /// Shows a personalized alert when the ingredient affects the user's pet
    private func personalizedPetAlert(for pet: Pet) -> some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(alertColorForPet(pet))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Applies to \(pet.name)")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(personalizedMessageForPet(pet))
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.sm)
        .background(alertColorForPet(pet).opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                .stroke(alertColorForPet(pet).opacity(0.3), lineWidth: 1)
        )
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
    
    // MARK: - Species Safety Helpers
    
    /// Determine dog safety status based on species compatibility
    private var dogSafetyStatus: SpeciesSafetyStatus {
        guard let compatibility = speciesCompatibility else {
            return safetyLevel == .safe ? .safe : (safetyLevel == .unsafe ? .unsafe : .caution)
        }
        
        switch compatibility {
        case .both: return safetyLevel == .safe ? .safe : .caution
        case .dogOnly: return .safe
        case .catOnly: return .unsafe
        case .neither: return .unsafe
        }
    }
    
    /// Determine cat safety status based on species compatibility
    private var catSafetyStatus: SpeciesSafetyStatus {
        guard let compatibility = speciesCompatibility else {
            return safetyLevel == .safe ? .safe : (safetyLevel == .unsafe ? .unsafe : .caution)
        }
        
        switch compatibility {
        case .both: return safetyLevel == .safe ? .safe : .caution
        case .catOnly: return .safe
        case .dogOnly: return .unsafe
        case .neither: return .unsafe
        }
    }
    
    /// Generate species severity comparison text when applicable
    private var speciesSeverityComparison: String? {
        guard dogSafetyStatus != catSafetyStatus else { return nil }
        
        if dogSafetyStatus == .unsafe && catSafetyStatus != .unsafe {
            return "More concerning for dogs than cats"
        } else if catSafetyStatus == .unsafe && dogSafetyStatus != .unsafe {
            return "More concerning for cats than dogs"
        } else if dogSafetyStatus == .caution && catSafetyStatus == .safe {
            return "Dogs may be more sensitive than cats"
        } else if catSafetyStatus == .caution && dogSafetyStatus == .safe {
            return "Cats may be more sensitive than dogs"
        }
        return nil
    }
    
    /// Check if the current pet is affected by this ingredient
    private func isPetAffected(_ pet: Pet) -> Bool {
        let status = pet.species == .dog ? dogSafetyStatus : catSafetyStatus
        return status != .safe
    }
    
    /// Get alert color for personalized pet message
    private func alertColorForPet(_ pet: Pet) -> Color {
        let status = pet.species == .dog ? dogSafetyStatus : catSafetyStatus
        switch status {
        case .safe: return ModernDesignSystem.Colors.safe
        case .caution: return ModernDesignSystem.Colors.goldenYellow
        case .unsafe: return ModernDesignSystem.Colors.warmCoral
        }
    }
    
    /// Generate personalized message for the pet
    private func personalizedMessageForPet(_ pet: Pet) -> String {
        let status = pet.species == .dog ? dogSafetyStatus : catSafetyStatus
        let speciesName = pet.species == .dog ? "dogs" : "cats"
        
        switch status {
        case .safe:
            return "This ingredient is generally safe for \(speciesName)."
        case .caution:
            return "Monitor \(pet.name) for any reactions after consuming this."
        case .unsafe:
            return "This ingredient may not be suitable for \(speciesName). Consider alternatives."
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

// MARK: - Species Safety Status

/// Safety status for a specific species
enum SpeciesSafetyStatus {
    case safe
    case caution
    case unsafe
    
    var icon: String {
        switch self {
        case .safe: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.circle.fill"
        case .unsafe: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .safe: return ModernDesignSystem.Colors.safe
        case .caution: return ModernDesignSystem.Colors.goldenYellow
        case .unsafe: return ModernDesignSystem.Colors.warmCoral
        }
    }
    
    var label: String {
        switch self {
        case .safe: return "Safe"
        case .caution: return "Monitor"
        case .unsafe: return "Avoid"
        }
    }
}

// MARK: - Species Safety Badge

/**
 * SpeciesSafetyBadge - Visual indicator showing safety status per species
 * Shows dog or cat icon with checkmark/X safety indicator
 */
struct SpeciesSafetyBadge: View {
    let species: PetSpecies
    let safetyStatus: SpeciesSafetyStatus
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            // Species icon
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: species == .dog ? "dog.fill" : "cat.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isHighlighted ? safetyStatus.color : ModernDesignSystem.Colors.textSecondary)
                
                // Safety indicator overlay
                Image(systemName: safetyStatus.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(safetyStatus.color)
                    .background(
                        Circle()
                            .fill(ModernDesignSystem.Colors.softCream)
                            .frame(width: 14, height: 14)
                    )
                    .offset(x: 4, y: 4)
            }
            
            // Label
            VStack(alignment: .leading, spacing: 0) {
                Text(species == .dog ? "Dogs" : "Cats")
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(safetyStatus.label)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(safetyStatus.color)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
        .padding(.vertical, ModernDesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                .fill(isHighlighted ? safetyStatus.color.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                .stroke(isHighlighted ? safetyStatus.color.opacity(0.3) : Color.clear, lineWidth: 1)
        )
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
    /// Sample pet for personalized previews
    static var sampleDog: Pet {
        Pet(
            id: "preview-dog",
            userId: "user",
            name: "Buddy",
            species: .dog,
            breed: "Golden Retriever",
            birthday: nil,
            weightKg: 30,
            imageUrl: nil,
            knownSensitivities: [],
            vetName: nil,
            vetPhone: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Safe ingredient with species badges
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
                    confidenceLevel: 0.95,
                    speciesCompatibility: .both
                )
                
                // Caution ingredient with personalized pet context
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
                    confidenceLevel: 0.75,
                    speciesCompatibility: .both,
                    currentPet: sampleDog
                )
                
                // Dog-only unsafe ingredient (shows species comparison)
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
                    confidenceLevel: 0.98,
                    speciesCompatibility: .catOnly,
                    currentPet: sampleDog
                )
                
                // Species safety badges standalone preview
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                    Text("Species Safety Badges")
                        .font(ModernDesignSystem.Typography.title3)
                    
                    HStack(spacing: ModernDesignSystem.Spacing.lg) {
                        SpeciesSafetyBadge(species: .dog, safetyStatus: .safe, isHighlighted: true)
                        SpeciesSafetyBadge(species: .cat, safetyStatus: .caution)
                    }
                    
                    HStack(spacing: ModernDesignSystem.Spacing.lg) {
                        SpeciesSafetyBadge(species: .dog, safetyStatus: .unsafe, isHighlighted: true)
                        SpeciesSafetyBadge(species: .cat, safetyStatus: .safe)
                    }
                }
                .padding()
                .background(ModernDesignSystem.Colors.softCream)
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            }
            .padding()
        }
        .background(Color.white)
    }
}
#endif
