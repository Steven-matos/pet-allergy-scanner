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
                if let imageUrl = pet.imageUrl, let image = loadLocalImage(from: imageUrl) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(ModernDesignSystem.Colors.deepForestGreen, lineWidth: 1.5))
                } else {
                    Image(systemName: pet.species.icon)
                        .font(.system(size: 24))
                        .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                        .frame(width: 40, height: 40)
                        .background(ModernDesignSystem.Colors.deepForestGreen.opacity(0.1))
                        .cornerRadius(20)
                }
                
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
