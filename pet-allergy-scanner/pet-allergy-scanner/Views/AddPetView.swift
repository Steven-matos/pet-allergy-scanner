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
    @State private var validationErrors: [String] = []
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Information Section
                Section("Basic Information") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Pet Name", text: $name)
                            .accessibilityIdentifier("petNameTextField")
                            .accessibilityLabel("Pet name")
                            .onChange(of: name) { _ in
                                validateForm()
                            }
                        
                        if validationErrors.contains(where: { $0.contains("name") }) {
                            Text(validationErrors.first(where: { $0.contains("name") }) ?? "")
                                .font(.caption)
                                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                                .accessibilityIdentifier("petNameError")
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .animation(.easeInOut(duration: 0.2), value: validationErrors)
                        }
                    }
                    
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
                    .accessibilityIdentifier("speciesPicker")
                    .accessibilityLabel("Pet species")
                    
                    TextField("Breed (Optional)", text: $breed)
                }
                
                // Physical Information Section
                Section("Physical Information") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Age")
                            Spacer()
                            TextField("Months", value: $ageMonths, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: ageMonths) { _ in
                                    validateForm()
                                }
                        }
                        
                        if validationErrors.contains(where: { $0.contains("Age") }) {
                            Text(validationErrors.first(where: { $0.contains("Age") }) ?? "")
                                .font(.caption)
                                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Weight")
                            Spacer()
                            TextField("kg", value: $weightKg, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: weightKg) { _ in
                                    validateForm()
                                }
                        }
                        
                        if validationErrors.contains(where: { $0.contains("Weight") }) {
                            Text(validationErrors.first(where: { $0.contains("Weight") }) ?? "")
                                .font(.caption)
                                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                        }
                    }
                }
                
                // Allergies Section
                Section("Known Allergies") {
                    ForEach(knownAllergies, id: \.self) { allergy in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                            Text(allergy)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            Spacer()
                            Button("Remove") {
                                knownAllergies.removeAll { $0 == allergy }
                            }
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
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
                    .disabled(!isFormValid)
                    .accessibilityIdentifier("savePetButton")
                    .accessibilityLabel("Save pet profile")
                    .accessibilityHint("Saves the pet information to your profile")
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
    
    /// Check if form is valid
    private var isFormValid: Bool {
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
        return petCreate.isValid
    }
    
    /// Validate form and update error messages
    private func validateForm() {
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
        validationErrors = petCreate.validationErrors
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

#Preview("With Mock Data") {
    let petService = PetService.shared
    // Note: Using shared instance for preview purposes
    
    return AddPetView()
        .environmentObject(petService)
}
