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
    
    var body: some View {
        NavigationView {
            VStack {
                if petService.pets.isEmpty {
                    EmptyPetsView()
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
                Image(systemName: pet.species.icon)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(20)
                
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
    PetSelectionView { pet in
        print("Selected pet: \(pet.name)")
    }
    .environmentObject(PetService.shared)
}
