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
    @State private var birthYear: Int?
    @State private var birthMonth: Int?
    @State private var weightKg: Double?
    @State private var knownAllergies: [String] = []
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var newAllergy = ""
    @State private var showingAlert = false
    @State private var validationErrors: [String] = []
    @State private var showingYearPicker = false
    @State private var showingMonthPicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Information Section
                Section("Basic Information") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Pet Name", text: $name)
                            .accessibilityIdentifier("petNameTextField")
                            .accessibilityLabel("Pet name")
                            .onChange(of: name) { _, _ in
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
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Birthday (Optional)")
                            .font(.headline)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Year")
                                    .font(.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                
                                Button(action: {
                                    showingYearPicker = true
                                }) {
                                    HStack {
                                        Text(birthYear != nil ? "\(birthYear!, specifier: "%d")" : "Select Year")
                                            .foregroundColor(birthYear != nil ? ModernDesignSystem.Colors.textPrimary : ModernDesignSystem.Colors.textSecondary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(ModernDesignSystem.Colors.lightGray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(ModernDesignSystem.Colors.lightGray.opacity(0.3), lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Month")
                                    .font(.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                
                                Button(action: {
                                    showingMonthPicker = true
                                }) {
                                    HStack {
                                        Text(birthMonth != nil ? monthName(for: birthMonth!) : "Select Month")
                                            .foregroundColor(birthMonth != nil ? ModernDesignSystem.Colors.textPrimary : ModernDesignSystem.Colors.textSecondary)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(ModernDesignSystem.Colors.lightGray.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(ModernDesignSystem.Colors.lightGray.opacity(0.3), lineWidth: 1)
                                    )
                                    .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        if let birthYear = birthYear, let birthMonth = birthMonth {
                            if let birthday = createBirthday(year: birthYear, month: birthMonth) {
                                let age = calculateAge(from: birthday)
                                Text("Age: \(age)")
                                    .font(.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                        }
                        
                        if validationErrors.contains(where: { $0.contains("Birthday") }) {
                            Text(validationErrors.first(where: { $0.contains("Birthday") }) ?? "")
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
                                .onChange(of: weightKg) { _, _ in
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
            .onChange(of: petService.errorMessage) { _, errorMessage in
                if errorMessage != nil {
                    showingAlert = true
                }
            }
            .overlay(
                Group {
                    if showingYearPicker {
                        YearPickerView(selectedYear: $birthYear, availableYears: availableYears, showingYearPicker: $showingYearPicker)
                            .transition(.opacity)
                    }
                    if showingMonthPicker {
                        MonthPickerView(selectedMonth: $birthMonth, showingMonthPicker: $showingMonthPicker)
                            .transition(.opacity)
                    }
                }
            )
        }
    }
    
    /// Check if form is valid
    private var isFormValid: Bool {
        let petCreate = PetCreate(
            name: name,
            species: species,
            breed: breed.isEmpty ? nil : breed,
            birthday: createBirthday(year: birthYear, month: birthMonth),
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
            birthday: createBirthday(year: birthYear, month: birthMonth),
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
            birthday: createBirthday(year: birthYear, month: birthMonth),
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
    
    // MARK: - Computed Properties
    
    /// Available years for selection (from 1900 to current year)
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(1900...currentYear).reversed()
    }
    
    // MARK: - Helper Functions
    
    /// Create a Date from year and month inputs
    private func createBirthday(year: Int?, month: Int?) -> Date? {
        guard let year = year, let month = month else { return nil }
        
        // Validate year and month
        let currentYear = Calendar.current.component(.year, from: Date())
        guard year >= 1900 && year <= currentYear else { return nil }
        guard month >= 1 && month <= 12 else { return nil }
        
        // Create date with first day of the month at midnight UTC
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        
        return Calendar.current.date(from: components)
    }
    
    /// Calculate age description from birthday
    private func calculateAge(from birthday: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: birthday, to: now)
        
        guard let years = components.year, let months = components.month else { return "Unknown" }
        
        if years == 0 {
            return "\(months) month\(months == 1 ? "" : "s") old"
        } else if months == 0 {
            return "\(years) year\(years == 1 ? "" : "s") old"
        } else {
            return "\(years) year\(years == 1 ? "" : "s"), \(months) month\(months == 1 ? "" : "s") old"
        }
    }
    
    /// Get month name for display
    private func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: month, day: 1))!
        return formatter.string(from: date)
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
