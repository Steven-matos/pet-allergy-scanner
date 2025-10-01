//
//  EditPetView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI

/// View for editing an existing pet's information
struct EditPetView: View {
    let pet: Pet
    
    @EnvironmentObject var petService: PetService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var breed = ""
    @State private var birthYear: Int?
    @State private var birthMonth: Int?
    @State private var weightKg: Double?
    @State private var selectedImage: UIImage?
    @State private var knownSensitivities: [String] = []
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var newSensitivity = ""
    @State private var showingAlert = false
    @State private var validationErrors: [String] = []
    @State private var showingYearPicker = false
    @State private var showingMonthPicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Pet Photo Section
                Section {
                    HStack {
                        Spacer()
                        PetImagePickerView(
                            selectedImage: $selectedImage,
                            species: pet.species
                        )
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
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
                    
                    // Species is not editable
                    HStack {
                        Text("Species")
                        Spacer()
                        HStack {
                            Image(systemName: pet.species.icon)
                            Text(pet.species.displayName)
                        }
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
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
                
                // Sensitivities Section
                Section("Food Sensitivities") {
                    ForEach(knownSensitivities, id: \.self) { sensitivity in
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                            Text(sensitivity)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            Spacer()
                            Button("Remove") {
                                knownSensitivities.removeAll { $0 == sensitivity }
                            }
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                            .font(.caption)
                        }
                    }
                    
                    HStack {
                        TextField("Add sensitivity", text: $newSensitivity)
                        Button("Add") {
                            if !newSensitivity.isEmpty {
                                knownSensitivities.append(newSensitivity)
                                newSensitivity = ""
                            }
                        }
                        .disabled(newSensitivity.isEmpty)
                    }
                }
                
                // Veterinary Information Section
                Section("Veterinary Information (Optional)") {
                    TextField("Vet Name", text: $vetName)
                    TextField("Vet Phone", text: $vetPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updatePet()
                    }
                    .disabled(!isFormValid)
                    .accessibilityIdentifier("savePetButton")
                    .accessibilityLabel("Save pet changes")
                    .accessibilityHint("Updates the pet information")
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
            .onAppear {
                loadPetData()
            }
        }
    }
    
    /// Load pet data into form fields
    private func loadPetData() {
        name = pet.name
        breed = pet.breed ?? ""
        weightKg = pet.weightKg
        knownSensitivities = pet.knownSensitivities
        vetName = pet.vetName ?? ""
        vetPhone = pet.vetPhone ?? ""
        
        // Load pet image if available
        if let imageUrl = pet.imageUrl {
            selectedImage = UIImage(contentsOfFile: imageUrl)
        }
        
        // Extract year and month from birthday
        if let birthday = pet.birthday {
            let calendar = Calendar.current
            birthYear = calendar.component(.year, from: birthday)
            birthMonth = calendar.component(.month, from: birthday)
        }
    }
    
    /// Check if form is valid
    private var isFormValid: Bool {
        let petCreate = PetCreate(
            name: name,
            species: pet.species, // Species doesn't change
            breed: breed.isEmpty ? nil : breed,
            birthday: createBirthday(year: birthYear, month: birthMonth),
            weightKg: weightKg,
            imageUrl: nil, // Not validating image URL
            knownSensitivities: knownSensitivities,
            vetName: vetName.isEmpty ? nil : vetName,
            vetPhone: vetPhone.isEmpty ? nil : vetPhone
        )
        return petCreate.isValid
    }
    
    /// Validate form and update error messages
    private func validateForm() {
        let petCreate = PetCreate(
            name: name,
            species: pet.species,
            breed: breed.isEmpty ? nil : breed,
            birthday: createBirthday(year: birthYear, month: birthMonth),
            weightKg: weightKg,
            imageUrl: nil, // Not validating image URL
            knownSensitivities: knownSensitivities,
            vetName: vetName.isEmpty ? nil : vetName,
            vetPhone: vetPhone.isEmpty ? nil : vetPhone
        )
        validationErrors = petCreate.validationErrors
    }
    
    /// Update the pet with the new data
    private func updatePet() {
        // Save new image if changed
        let newImageUrl: String?
        if let selectedImage = selectedImage {
            // Check if image changed by comparing with existing
            let existingImage = pet.imageUrl.flatMap { UIImage(contentsOfFile: $0) }
            if existingImage == nil || !imagesAreEqual(selectedImage, existingImage) {
                newImageUrl = saveImageLocally(selectedImage)
            } else {
                newImageUrl = nil // No change
            }
        } else if pet.imageUrl != nil {
            // Image was removed
            newImageUrl = ""
        } else {
            newImageUrl = nil // No change
        }
        
        let petUpdate = PetUpdate(
            name: name != pet.name ? name : nil,
            breed: breed != (pet.breed ?? "") ? (breed.isEmpty ? nil : breed) : nil,
            birthday: createBirthday(year: birthYear, month: birthMonth),
            weightKg: weightKg != pet.weightKg ? weightKg : nil,
            imageUrl: newImageUrl,
            knownSensitivities: knownSensitivities != pet.knownSensitivities ? knownSensitivities : nil,
            vetName: vetName != (pet.vetName ?? "") ? (vetName.isEmpty ? nil : vetName) : nil,
            vetPhone: vetPhone != (pet.vetPhone ?? "") ? (vetPhone.isEmpty ? nil : vetPhone) : nil
        )
        
        petService.updatePet(id: pet.id, petUpdate: petUpdate)
        
        // Dismiss after successful update
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if petService.errorMessage == nil {
                dismiss()
            }
        }
    }
    
    /// Save image locally with optimization and return file URL
    /// - Parameter image: The UIImage to save
    /// - Returns: Local file URL string or nil
    private func saveImageLocally(_ image: UIImage?) -> String? {
        guard let image = image else { return nil }
        
        // Optimize image before saving
        let optimizedResult: OptimizedImageResult
        do {
            optimizedResult = try ImageOptimizer.optimizeForUpload(image: image)
            print("📸 Image optimized for local storage: \(optimizedResult.summary)")
        } catch {
            print("⚠️ Image optimization failed: \(error), using default compression")
            // Fallback to simple compression if optimization fails
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                return nil
            }
            return saveImageData(imageData)
        }
        
        return saveImageData(optimizedResult.data)
    }
    
    /// Save image data to local file system
    /// - Parameter data: The image data to save
    /// - Returns: Local file path string or nil
    private func saveImageData(_ data: Data) -> String? {
        // Create a unique filename
        let filename = "\(UUID().uuidString).jpg"
        
        // Get documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        // Create pet images directory if needed
        let petImagesDirectory = documentsDirectory.appendingPathComponent("PetImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: petImagesDirectory, withIntermediateDirectories: true)
        
        // Create full file URL
        let fileURL = petImagesDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }
    
    /// Compare two images for equality
    /// - Parameters:
    ///   - image1: First image
    ///   - image2: Second image
    /// - Returns: True if images are equal
    private func imagesAreEqual(_ image1: UIImage, _ image2: UIImage?) -> Bool {
        guard let image2 = image2 else { return false }
        guard let data1 = image1.pngData(), let data2 = image2.pngData() else { return false }
        return data1 == data2
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
    let mockPet = Pet(
        id: "1",
        userId: "user1",
        name: "Max",
        species: .dog,
        breed: "Golden Retriever",
        birthday: Calendar.current.date(from: DateComponents(year: 2020, month: 3))!,
        weightKg: 25.5,
        knownSensitivities: ["Chicken", "Wheat"],
        vetName: "Dr. Smith",
        vetPhone: "555-1234",
        createdAt: Date(),
        updatedAt: Date()
    )
    
    return EditPetView(pet: mockPet)
        .environmentObject(PetService.shared)
}

