//
//  PetsView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/// Main view for displaying and managing user's pets
/// Follows Trust & Nature Design System for consistent styling
struct PetsView: View {
    @EnvironmentObject var petService: PetService
    @State private var showingAddPet = false
    @State private var showingEditPet: Pet?
    @State private var petToDelete: Pet?
    @State private var showingDeleteAlert = false
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if petService.isLoading {
                    ModernLoadingView(message: "Loading pets...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if petService.pets.isEmpty {
                    EmptyPetsView {
                        showingAddPet = true
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: ModernDesignSystem.Spacing.md) {
                            ForEach(petService.pets) { pet in
                                PetCardView(
                                    pet: pet,
                                    onEdit: {
                                        showingEditPet = pet
                                    },
                                    onDelete: {
                                        petToDelete = pet
                                        showingDeleteAlert = true
                                    }
                                )
                            }
                        }
                        .padding(ModernDesignSystem.Spacing.md)
                    }
                }
            }
            .navigationTitle("My Pets")
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddPet = true
                    }) {
                        Image(systemName: "plus")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                    }
                    .accessibilityLabel("Add new pet")
                    .accessibilityHint("Opens the add pet form")
                }
            }
            .sheet(isPresented: $showingAddPet) {
                AddPetView()
            }
            .sheet(item: $showingEditPet) { pet in
                EditPetView(pet: pet)
            }
            .alert("Delete Pet", isPresented: $showingDeleteAlert, presenting: petToDelete) { pet in
                Button("Cancel", role: .cancel) {
                    petToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let pet = petToDelete {
                        petService.deletePet(id: pet.id)
                        petToDelete = nil
                    }
                }
            } message: { pet in
                Text("Are you sure you want to delete \(pet.name)? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(petService.errorMessage ?? "An error occurred")
            }
            .onChange(of: petService.errorMessage) { _, errorMessage in
                if errorMessage != nil {
                    showingAlert = true
                }
            }
        }
    }
}

/// Enhanced pet card view with detailed information and action buttons
/// Follows Trust & Nature Design System card patterns
struct PetCardView: View {
    let pet: Pet
    let onEdit: () -> Void
    let onDelete: () -> Void
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero Pet Image Section - Focal Point
            ZStack(alignment: .topTrailing) {
                // Large Pet Image as focal point
                RemoteImageView(petImageUrl: pet.imageUrl, species: pet.species)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                
                // Action Buttons positioned over the image with Trust & Nature styling
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(ModernDesignSystem.Colors.textPrimary.opacity(0.8))
                            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                            .shadow(
                                color: ModernDesignSystem.Shadows.small.color,
                                radius: ModernDesignSystem.Shadows.small.radius,
                                x: ModernDesignSystem.Shadows.small.x,
                                y: ModernDesignSystem.Shadows.small.y
                            )
                    }
                    .accessibilityLabel("Edit \(pet.name)")
                    .accessibilityHint("Opens the edit pet form")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(ModernDesignSystem.Colors.warmCoral.opacity(0.9))
                            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                            .shadow(
                                color: ModernDesignSystem.Shadows.small.color,
                                radius: ModernDesignSystem.Shadows.small.radius,
                                x: ModernDesignSystem.Shadows.small.x,
                                y: ModernDesignSystem.Shadows.small.y
                            )
                    }
                    .accessibilityLabel("Delete \(pet.name)")
                    .accessibilityHint("Deletes this pet from your profile")
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            
            // Pet Name and Species with Trust & Nature colors
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(pet.name)
                    .font(ModernDesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(pet.species.displayName)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.bottom, ModernDesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Pet Details Grid with consistent spacing
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                // Breed and Age Row with Trust & Nature spacing
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    if let breed = pet.breed, !breed.isEmpty {
                        InfoPillView(
                            icon: "pawprint.fill",
                            label: "Breed",
                            value: breed
                        )
                    }
                    
                    if let ageDescription = pet.ageDescription {
                        InfoPillView(
                            icon: "calendar",
                            label: "Age",
                            value: ageDescription
                        )
                    }
                }
                
                // Weight and Allergies Row with Trust & Nature spacing
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    if let weightKg = pet.weightKg {
                        InfoPillView(
                            icon: "scalemass.fill",
                            label: "Weight",
                            value: unitService.formatWeight(weightKg)
                        )
                    }
                    
                    if !pet.knownSensitivities.isEmpty {
                        InfoPillView(
                            icon: "exclamationmark.triangle.fill",
                            label: "Sensitivities",
                            value: "\(pet.knownSensitivities.count)",
                            isWarning: true
                        )
                    }
                }
                
                // Sensitivities List with Trust & Nature styling
                if !pet.knownSensitivities.isEmpty {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        Text("Food Sensitivities")
                            .font(ModernDesignSystem.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .textCase(.uppercase)
                        
                        PetTagFlowLayout(spacing: ModernDesignSystem.Spacing.sm) {
                            ForEach(pet.knownSensitivities, id: \.self) { sensitivity in
                                Text(sensitivity)
                                    .font(ModernDesignSystem.Typography.caption)
                                    .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                                    .background(ModernDesignSystem.Colors.warmCoral.opacity(0.1))
                                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                            }
                        }
                    }
                }
                
                // Veterinary Information with Trust & Nature styling
                if (pet.vetName != nil && !pet.vetName!.isEmpty) || (pet.vetPhone != nil && !pet.vetPhone!.isEmpty) {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        Text("Veterinary Information")
                            .font(ModernDesignSystem.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .textCase(.uppercase)
                        
                        if let vetName = pet.vetName, !vetName.isEmpty {
                            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                Image(systemName: "cross.case.fill")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                Text(vetName)
                                    .font(ModernDesignSystem.Typography.subheadline)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            }
                        }
                        
                        if let vetPhone = pet.vetPhone, !vetPhone.isEmpty {
                            if let phoneURL = URL(string: "tel://\(vetPhone.replacingOccurrences(of: " ", with: ""))") {
                                Link(destination: phoneURL) {
                                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                        Image(systemName: "phone.fill")
                                            .font(ModernDesignSystem.Typography.caption)
                                            .foregroundColor(ModernDesignSystem.Colors.primary)
                                        Text(vetPhone)
                                            .font(ModernDesignSystem.Typography.subheadline)
                                            .foregroundColor(ModernDesignSystem.Colors.primary)
                                            .underline()
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(ModernDesignSystem.Typography.caption2)
                                            .foregroundColor(ModernDesignSystem.Colors.primary)
                                    }
                                }
                                .accessibilityLabel("Call \(vetPhone)")
                                .accessibilityHint("Opens phone to call vet")
                            } else {
                                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                    Image(systemName: "phone.fill")
                                        .font(ModernDesignSystem.Typography.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    Text(vetPhone)
                                        .font(ModernDesignSystem.Typography.subheadline)
                                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        // Apply Trust & Nature card styling with enhanced shadow for hero image
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                .stroke(ModernDesignSystem.Colors.borderPrimary.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.large)
        .shadow(
            color: ModernDesignSystem.Shadows.medium.color,
            radius: ModernDesignSystem.Shadows.medium.radius,
            x: ModernDesignSystem.Shadows.medium.x,
            y: ModernDesignSystem.Shadows.medium.y
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pet card for \(pet.name)")
    }
    
}

/// Reusable info pill component for displaying pet details
/// Follows Trust & Nature Design System styling
struct InfoPillView: View {
    let icon: String
    let label: String
    let value: String
    var isWarning: Bool = false
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(ModernDesignSystem.Typography.caption2)
                .foregroundColor(isWarning ? ModernDesignSystem.Colors.warmCoral : ModernDesignSystem.Colors.primary)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs / 2) {
                Text(label)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text(value)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isWarning ? ModernDesignSystem.Colors.warmCoral : ModernDesignSystem.Colors.primary).opacity(0.08))
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
    }
}

/// Flow layout for wrapping allergy tags
struct PetTagFlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    PetsView()
        .environmentObject(PetService.shared)
}
