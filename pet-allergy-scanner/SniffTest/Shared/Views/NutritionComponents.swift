//
//  NutritionComponents.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import SwiftUI

/**
 * Pet Selection Card
 * Shared component for displaying pet information in nutrition views
 */
struct PetSelectionCard: View {
    let pet: Pet
    var onTap: (() -> Void)? = nil
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                // Pet avatar
                Circle()
                    .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: pet.species == .dog ? "pawprint.fill" : "cat.fill")
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                            .font(.title3)
                    )
                
                // Pet details
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(pet.name)
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("\(pet.species.rawValue.capitalized) • \(pet.breed ?? "Unknown")")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    if let weight = pet.weightKg {
                        Text(unitService.formatWeight(weight))
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Chevron indicator
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .font(.caption)
                }
            }
            .padding(ModernDesignSystem.Spacing.md)
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
        .buttonStyle(PlainButtonStyle())
    }
}

