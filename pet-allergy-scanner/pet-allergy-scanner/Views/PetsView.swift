//
//  PetsView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct PetsView: View {
    @EnvironmentObject var petService: PetService
    @State private var showingAddPet = false
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if petService.isLoading {
                    ProgressView("Loading pets...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if petService.pets.isEmpty {
                    EmptyPetsView {
                        showingAddPet = true
                    }
                } else {
                    List {
                        ForEach(petService.pets) { pet in
                            PetRowView(pet: pet)
                        }
                        .onDelete(perform: deletePets)
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
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(petService.errorMessage ?? "An error occurred")
            }
            .onChange(of: petService.errorMessage) { errorMessage in
                if errorMessage != nil {
                    showingAlert = true
                }
            }
        }
    }
    
    private func deletePets(offsets: IndexSet) {
        for index in offsets {
            let pet = petService.pets[index]
            petService.deletePet(id: pet.id)
        }
    }
}

struct PetRowView: View {
    let pet: Pet
    
    var body: some View {
        HStack(spacing: 16) {
            // Pet Icon
            Image(systemName: pet.species.icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(20)
            
            // Pet Info
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
            
            // Allergies Count
            if !pet.knownAllergies.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(pet.knownAllergies.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    Text("allergies")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PetsView()
        .environmentObject(PetService.shared)
}
