//
//  PetSelectionView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/// Pet selection view with Trust & Nature Design System styling
struct PetSelectionView: View {
    @EnvironmentObject var petService: CachedPetService
    @Environment(\.dismiss) private var dismiss
    let onPetSelected: (Pet) -> Void
    let onAddPet: (() -> Void)?
    
    init(onPetSelected: @escaping (Pet) -> Void, onAddPet: (() -> Void)? = nil) {
        self.onPetSelected = onPetSelected
        self.onAddPet = onAddPet
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if petService.pets.isEmpty {
                    EmptyPetsView {
                        onAddPet?()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: ModernDesignSystem.Spacing.md) {
                            ForEach(petService.pets) { pet in
                                PetSelectionCardView(pet: pet) {
                                    onPetSelected(pet)
                                    dismiss()
                                }
                            }
                        }
                        .padding(ModernDesignSystem.Spacing.md)
                    }
                }
            }
            .navigationTitle("Select Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
        }
    }
}

/// Pet selection card view with Trust & Nature Design System styling
struct PetSelectionCardView: View {
    let pet: Pet
    let onTap: () -> Void
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                // Pet Photo or Species Icon with Trust & Nature styling
                RemoteImageView(petImageUrl: pet.imageUrl, species: pet.species)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(ModernDesignSystem.Colors.primary, lineWidth: 2)
                    )
                
                // Pet Information with proper typography
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(pet.name)
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text(pet.species.displayName)
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    if let breed = pet.breed, !breed.isEmpty {
                        Text(breed)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    if let weight = pet.weightKg {
                        Text(unitService.formatWeight(weight))
                            .font(ModernDesignSystem.Typography.caption2)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Chevron indicator with Trust & Nature styling
                Image(systemName: "chevron.right")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        .buttonStyle(PlainButtonStyle())
        // Apply Trust & Nature card styling
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
        .accessibilityLabel("Select \(pet.name)")
        .accessibilityHint("Selects this pet for the current action")
    }
}

#Preview {
    PetSelectionView(
        onPetSelected: { pet in
            print("Selected pet: \(pet.name)")
        },
        onAddPet: {
            print("Add pet tapped")
        }
    )
    .environmentObject(CachedPetService.shared)
}
