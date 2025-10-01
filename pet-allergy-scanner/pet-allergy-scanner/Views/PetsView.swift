//
//  PetsView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/// Main view for displaying and managing user's pets
struct PetsView: View {
    @EnvironmentObject var petService: PetService
    @State private var showingAddPet = false
    @State private var showingEditPet: Pet?
    @State private var petToDelete: Pet?
    @State private var showingDeleteAlert = false
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if petService.isLoading {
                    ProgressView("Loading pets...")
                        .tint(ModernDesignSystem.Colors.deepForestGreen)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if petService.pets.isEmpty {
                    EmptyPetsView {
                        showingAddPet = true
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
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
                        .padding()
                    }
                }
            }
            .navigationTitle("My Pets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddPet = true
                    }) {
                        Image(systemName: "plus")
                    }
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
struct PetCardView: View {
    let pet: Pet
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with Pet Name and Actions
            HStack(spacing: 12) {
                // Pet Photo or Icon
                if let imageUrl = pet.imageUrl, let image = loadLocalImage(from: imageUrl) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(ModernDesignSystem.Colors.deepForestGreen, lineWidth: 2))
                } else {
                    Image(systemName: pet.species.icon)
                        .font(.system(size: 28))
                        .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                        .frame(width: 56, height: 56)
                        .background(ModernDesignSystem.Colors.deepForestGreen.opacity(0.1))
                        .cornerRadius(28)
                }
                
                // Pet Name and Species
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text(pet.species.displayName)
                        .font(.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                            .frame(width: 36, height: 36)
                            .background(ModernDesignSystem.Colors.deepForestGreen.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .accessibilityLabel("Edit \(pet.name)")
                    .accessibilityHint("Opens the edit pet form")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                            .frame(width: 36, height: 36)
                            .background(ModernDesignSystem.Colors.warmCoral.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .accessibilityLabel("Delete \(pet.name)")
                    .accessibilityHint("Deletes this pet from your profile")
                }
            }
            .padding()
            
            Divider()
                .padding(.horizontal)
            
            // Pet Details Grid
            VStack(spacing: 12) {
                // Breed and Age Row
                HStack(spacing: 12) {
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
                
                // Weight and Allergies Row
                HStack(spacing: 12) {
                    if let weightKg = pet.weightKg {
                        InfoPillView(
                            icon: "scalemass.fill",
                            label: "Weight",
                            value: "\(String(format: "%.1f", weightKg)) kg"
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
                
                // Sensitivities List
                if !pet.knownSensitivities.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Food Sensitivities")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .textCase(.uppercase)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(pet.knownSensitivities, id: \.self) { sensitivity in
                                Text(sensitivity)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(ModernDesignSystem.Colors.warmCoral.opacity(0.1))
                                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                
                // Veterinary Information
                if (pet.vetName != nil && !pet.vetName!.isEmpty) || (pet.vetPhone != nil && !pet.vetPhone!.isEmpty) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Veterinary Information")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .textCase(.uppercase)
                        
                        if let vetName = pet.vetName, !vetName.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "cross.case.fill")
                                    .font(.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                Text(vetName)
                                    .font(.subheadline)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            }
                        }
                        
                        if let vetPhone = pet.vetPhone, !vetPhone.isEmpty {
                            if let phoneURL = URL(string: "tel://\(vetPhone.replacingOccurrences(of: " ", with: ""))") {
                                Link(destination: phoneURL) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "phone.fill")
                                            .font(.caption)
                                            .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                        Text(vetPhone)
                                            .font(.subheadline)
                                            .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                            .underline()
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption2)
                                            .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                    }
                                }
                                .accessibilityLabel("Call \(vetPhone)")
                                .accessibilityHint("Opens phone to call vet")
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "phone.fill")
                                        .font(.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    Text(vetPhone)
                                        .font(.subheadline)
                                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pet card for \(pet.name)")
    }
    
    /// Load image from local file path
    /// - Parameter path: The local file path
    /// - Returns: UIImage if successfully loaded
    private func loadLocalImage(from path: String) -> UIImage? {
        // Check if path is a URL string or file path
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            // Remote URL - would need async loading (not implemented here)
            return nil
        } else {
            // Local file path
            return UIImage(contentsOfFile: path)
        }
    }
}

/// Reusable info pill component for displaying pet details
struct InfoPillView: View {
    let icon: String
    let label: String
    let value: String
    var isWarning: Bool = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(isWarning ? ModernDesignSystem.Colors.warmCoral : ModernDesignSystem.Colors.deepForestGreen)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isWarning ? ModernDesignSystem.Colors.warmCoral : ModernDesignSystem.Colors.deepForestGreen).opacity(0.08))
        .cornerRadius(10)
    }
}

/// Flow layout for wrapping allergy tags
struct FlowLayout: Layout {
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
