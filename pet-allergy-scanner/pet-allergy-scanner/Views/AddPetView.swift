//
//  AddPetView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct AddPetView: View {
    @EnvironmentObject var petService: PetService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var species = PetSpecies.dog
    @State private var breed = ""
    @State private var ageMonths: Int?
    @State private var weightKg: Double?
    @State private var knownAllergies: [String] = []
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var newAllergy = ""
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information Section
                Section("Basic Information") {
                    TextField("Pet Name", text: $name)
                    
                    Picker("Species", selection: $species) {
                        ForEach(PetSpecies.allCases, id: \.self) { species in
                            HStack {
                                Image(systemName: species.icon)
                                Text(species.displayName)
                            }
                            .tag(species)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("Breed (Optional)", text: $breed)
                }
                
                // Physical Information Section
                Section("Physical Information") {
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Months", value: $ageMonths, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // Allergies Section
                Section("Known Allergies") {
                    ForEach(knownAllergies, id: \.self) { allergy in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(allergy)
                            Spacer()
                            Button("Remove") {
                                knownAllergies.removeAll { $0 == allergy }
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }
                    
                    HStack {
                        TextField("Add allergy", text: $newAllergy)
                        Button("Add") {
                            if !newAllergy.isEmpty {
                                knownAllergies.append(newAllergy)
                                newAllergy = ""
                            }
                        }
                        .disabled(newAllergy.isEmpty)
                    }
                }
                
                // Veterinary Information Section
                Section("Veterinary Information (Optional)") {
                    TextField("Vet Name", text: $vetName)
                    TextField("Vet Phone", text: $vetPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Add Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePet()
                    }
                    .disabled(name.isEmpty)
                }
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
    
    private func savePet() {
        let petCreate = PetCreate(
            name: name,
            species: species,
            breed: breed.isEmpty ? nil : breed,
            ageMonths: ageMonths,
            weightKg: weightKg,
            knownAllergies: knownAllergies,
            vetName: vetName.isEmpty ? nil : vetName,
            vetPhone: vetPhone.isEmpty ? nil : vetPhone
        )
        
        petService.createPet(petCreate)
        
        // Dismiss after successful creation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if petService.errorMessage == nil {
                dismiss()
            }
        }
    }
}

#Preview {
    AddPetView()
        .environmentObject(PetService.shared)
}
