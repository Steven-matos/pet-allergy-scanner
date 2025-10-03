//
//  PetSelectionView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct PetSelectionView: View {
    @EnvironmentObject var petService: PetService
    @Environment(\.dismiss) private var dismiss
    let onPetSelected: (Pet) -> Void
    let onAddPet: (() -> Void)?
    
    init(onPetSelected: @escaping (Pet) -> Void, onAddPet: (() -> Void)? = nil) {
        self.onPetSelected = onPetSelected
        self.onAddPet = onAddPet
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if petService.pets.isEmpty {
                    EmptyPetsView {
                        onAddPet?()
                    }
                } else {
                    List(petService.pets) { pet in
                        PetSelectionRowView(pet: pet) {
                            onPetSelected(pet)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Select Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PetSelectionRowView: View {
    let pet: Pet
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Pet Photo or Species Icon
                RemoteImageView(petImageUrl: pet.imageUrl, species: pet.species)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ModernDesignSystem.Colors.deepForestGreen, lineWidth: 1.5))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(pet.species.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let breed = pet.breed {
                        Text(breed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
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
    .environmentObject(PetService.shared)
}
