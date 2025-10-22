//
//  EditPetView.swift
//  SniffTest
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI

/**
 * Edit Pet View following Trust & Nature Design System
 * 
 * Features:
 * - Card-based layout with soft cream backgrounds
 * - Trust & Nature color palette throughout
 * - Consistent spacing and typography
 * - Professional, nature-inspired design
 * - Accessible form controls
 * 
 * Design System Compliance:
 * - Uses ModernDesignSystem for all styling
 * - Follows Trust & Nature color palette
 * - Implements consistent spacing scale
 * - Applies proper shadows and corner radius
 * - Maintains accessibility standards
 */
struct EditPetView: View {
    let pet: Pet
    
    @EnvironmentObject var petService: PetService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var breed = ""
    @State private var birthYear: Int?
    @State private var birthMonth: Int?
    @State private var weightKg: Double?
    @State private var activityLevel: PetActivityLevel = .moderate
    @State private var selectedImage: UIImage?
    @State private var imageRemoved = false
    @State private var knownSensitivities: [String] = []
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var newSensitivity = ""
    @State private var showingAlert = false
    @State private var validationErrors: [String] = []
    @State private var showingYearPicker = false
    @State private var showingMonthPicker = false
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // MARK: - Pet Photo Card
                    petPhotoCard
                    
                    // MARK: - Basic Information Card
                    basicInformationCard
                    
                    // MARK: - Physical Information Card
                    physicalInformationCard
                    
                    // MARK: - Food Sensitivities Card
                    foodSensitivitiesCard
                    
                    // MARK: - Veterinary Information Card
                    veterinaryInformationCard
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Edit Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updatePet()
                    }
                    .disabled(!isFormValid)
                    .foregroundColor(isFormValid ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
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
    
    // MARK: - Pet Photo Card
    private var petPhotoCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "camera.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Pet Photo")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            // Pet Image Picker
            HStack {
                Spacer()
                PetProfileImagePickerView(
                    selectedImage: $selectedImage,
                    currentImageUrl: pet.imageUrl,
                    species: pet.species,
                    onImageRemoved: {
                        imageRemoved = true
                    }
                )
                Spacer()
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Basic Information Card
    private var basicInformationCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Basic Information")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Pet Name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Pet Name")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter pet name", text: $name)
                        .font(ModernDesignSystem.Typography.body)
                        .modernInputField()
                        .accessibilityIdentifier("petNameTextField")
                        .accessibilityLabel("Pet name")
                        .onChange(of: name) { _, _ in
                            validateForm()
                        }
                    
                    if validationErrors.contains(where: { $0.contains("name") }) {
                        Text(validationErrors.first(where: { $0.contains("name") }) ?? "")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                            .accessibilityIdentifier("petNameError")
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .animation(.easeInOut(duration: 0.2), value: validationErrors)
                    }
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Species (read-only)
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Species")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        Image(systemName: pet.species.icon)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        Text(pet.species.displayName)
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.textSecondary.opacity(0.1))
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Breed
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Breed (Optional)")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter breed", text: $breed)
                        .font(ModernDesignSystem.Typography.body)
                        .modernInputField()
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Physical Information Card
    private var physicalInformationCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Physical Information")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Birthday Section
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Birthday (Optional)")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack(spacing: ModernDesignSystem.Spacing.md) {
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Year")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Button(action: {
                                showingYearPicker = true
                            }) {
                                HStack {
                                    Text(birthYear != nil ? "\(birthYear!, specifier: "%d")" : "Select Year")
                                        .font(ModernDesignSystem.Typography.body)
                                        .foregroundColor(birthYear != nil ? ModernDesignSystem.Colors.textPrimary : ModernDesignSystem.Colors.textSecondary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                        .font(ModernDesignSystem.Typography.caption)
                                }
                                .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                                .background(ModernDesignSystem.Colors.textSecondary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                        .stroke(ModernDesignSystem.Colors.textSecondary.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(ModernDesignSystem.CornerRadius.small)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Month")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Button(action: {
                                showingMonthPicker = true
                            }) {
                                HStack {
                                    Text(birthMonth != nil ? monthName(for: birthMonth!) : "Select Month")
                                        .font(ModernDesignSystem.Typography.body)
                                        .foregroundColor(birthMonth != nil ? ModernDesignSystem.Colors.textPrimary : ModernDesignSystem.Colors.textSecondary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                        .font(ModernDesignSystem.Typography.caption)
                                }
                                .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                                .background(ModernDesignSystem.Colors.textSecondary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                        .stroke(ModernDesignSystem.Colors.textSecondary.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(ModernDesignSystem.CornerRadius.small)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    if let birthYear = birthYear, let birthMonth = birthMonth {
                        if let birthday = createBirthday(year: birthYear, month: birthMonth) {
                            let age = calculateAge(from: birthday)
                            Text("Age: \(age)")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                    }
                    
                    if validationErrors.contains(where: { $0.contains("Birthday") }) {
                        Text(validationErrors.first(where: { $0.contains("Birthday") }) ?? "")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Weight Section
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Weight")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        TextField(unitService.getUnitSymbol(), value: $weightKg, format: .number)
                            .font(ModernDesignSystem.Typography.body)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .modernInputField()
                            .onChange(of: weightKg) { _, _ in
                                validateForm()
                            }
                    }
                    
                    if validationErrors.contains(where: { $0.contains("Weight") }) {
                        Text(validationErrors.first(where: { $0.contains("Weight") }) ?? "")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Activity Level Section
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Activity Level")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(PetActivityLevel.allCases, id: \.self) { level in
                            VStack(alignment: .leading) {
                                Text(level.displayName)
                                    .font(ModernDesignSystem.Typography.body)
                                Text(level.description)
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Food Sensitivities Card
    private var foodSensitivitiesCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Food Sensitivities")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Existing Sensitivities
                ForEach(knownSensitivities, id: \.self) { sensitivity in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                            .font(ModernDesignSystem.Typography.caption)
                        Text(sensitivity)
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                        Button("Remove") {
                            knownSensitivities.removeAll { $0 == sensitivity }
                        }
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                }
                
                if !knownSensitivities.isEmpty {
                    Divider()
                        .background(ModernDesignSystem.Colors.borderPrimary)
                }
                
                // Add New Sensitivity
                HStack {
                    TextField("Add sensitivity", text: $newSensitivity)
                        .font(ModernDesignSystem.Typography.body)
                        .modernInputField()
                    Button("Add") {
                        if !newSensitivity.isEmpty {
                            knownSensitivities.append(newSensitivity)
                            newSensitivity = ""
                        }
                    }
                    .disabled(newSensitivity.isEmpty)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Veterinary Information Card
    private var veterinaryInformationCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "stethoscope")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Veterinary Information (Optional)")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Vet Name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Vet Name")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter vet name", text: $vetName)
                        .font(ModernDesignSystem.Typography.body)
                        .modernInputField()
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Vet Phone
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Vet Phone")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter vet phone", text: $vetPhone)
                        .font(ModernDesignSystem.Typography.body)
                        .keyboardType(.phonePad)
                        .modernInputField()
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    /// Load pet data into form fields
    private func loadPetData() {
        print("🔍 EditPetView: Loading pet data - imageUrl: \(pet.imageUrl ?? "nil")")
        name = pet.name
        breed = pet.breed ?? ""
        // Convert stored kg weight to selected unit for display
        weightKg = pet.weightKg != nil ? unitService.convertFromKg(pet.weightKg!) : nil
        activityLevel = pet.effectiveActivityLevel
        knownSensitivities = pet.knownSensitivities
        vetName = pet.vetName ?? ""
        vetPhone = pet.vetPhone ?? ""
        
        // Note: Pet image loading is now handled by PetProfileImagePickerView
        // No need to load image here as it's managed by the picker component
        
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
            activityLevel: activityLevel,
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
            activityLevel: activityLevel,
            imageUrl: nil, // Not validating image URL
            knownSensitivities: knownSensitivities,
            vetName: vetName.isEmpty ? nil : vetName,
            vetPhone: vetPhone.isEmpty ? nil : vetPhone
        )
        validationErrors = petCreate.validationErrors
    }
    
    /// Update the pet with the new data
    private func updatePet() {
        Task {
            do {
                var newImageUrl: String? = nil
                
                // Handle image changes
                if let selectedImage = selectedImage {
                    // User selected a new image - upload it
                    guard let userId = AuthService.shared.currentUser?.id else {
                        petService.errorMessage = "User not authenticated"
                        return
                    }
                    
                    // Replace old image with new one (deletes old, uploads new)
                    newImageUrl = try await StorageService.shared.replacePetImage(
                        oldImageUrl: pet.imageUrl,
                        newImage: selectedImage,
                        userId: userId,
                        petId: pet.id
                    )
                    
                    print("📸 Pet image replaced in Supabase: \(newImageUrl ?? "nil")")
                } else if imageRemoved {
                    // User explicitly removed the image - delete old image and set to empty
                    if let oldUrl = pet.imageUrl, oldUrl.contains(Configuration.supabaseURL) {
                        do {
                            try await StorageService.shared.deletePetImage(path: oldUrl)
                            print("🗑️ Pet image removed from Supabase: \(oldUrl)")
                        } catch {
                            print("⚠️ Failed to delete old image: \(error)")
                        }
                    }
                    newImageUrl = ""
                } else {
                    // No image change - keep existing image (don't include imageUrl in update)
                    newImageUrl = nil
                }
                
                // Convert weight to kg for storage (backend expects kg)
                let weightInKg = weightKg != nil ? unitService.convertToKg(weightKg!) : nil
                let originalWeightInKg = pet.weightKg
                
                let petUpdate = PetUpdate(
                    name: name != pet.name ? name : nil,
                    breed: breed != (pet.breed ?? "") ? (breed.isEmpty ? nil : breed) : nil,
                    birthday: createBirthday(year: birthYear, month: birthMonth),
                    weightKg: weightInKg != originalWeightInKg ? weightInKg : nil,
                    activityLevel: activityLevel != pet.effectiveActivityLevel ? activityLevel : nil,
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
            } catch {
                petService.errorMessage = "Failed to upload image: \(error.localizedDescription)"
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
        activityLevel: .high,
        imageUrl: nil,
        knownSensitivities: ["Chicken", "Wheat"],
        vetName: "Dr. Smith",
        vetPhone: "555-1234",
        createdAt: Date(),
        updatedAt: Date()
    )
    
    EditPetView(pet: mockPet)
        .environmentObject(PetService.shared)
}

