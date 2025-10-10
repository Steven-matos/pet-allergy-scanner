//
//  EmptyPetsView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/// View displayed when user has no pets added
/// Follows Trust & Nature Design System for consistent styling
struct EmptyPetsView: View {
    let onAddPet: () -> Void
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            Spacer()
            
            // Empty State Icon with Trust & Nature styling
            Image(systemName: "pawprint.circle")
                .font(.system(size: 80))
                .foregroundColor(ModernDesignSystem.Colors.primary.opacity(0.4))
            
            // Empty State Text with proper typography
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Text("No Pets Added")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Add your pet's profile to start scanning ingredient labels for allergies and safety.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ModernDesignSystem.Spacing.xl)
            }
            
            // Add Pet Button with Trust & Nature styling
            Button(action: onAddPet) {
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Your First Pet")
                }
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textOnAccent)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.vertical, ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.goldenYellow)
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            }
            .accessibilityLabel("Add your first pet")
            .accessibilityHint("Opens the add pet form")
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.lg)
    }
}

#Preview {
    EmptyPetsView {
        print("Add pet tapped")
    }
}

