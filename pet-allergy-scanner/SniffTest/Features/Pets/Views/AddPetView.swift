//
//  AddPetView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/**
 * Add Pet View following Trust & Nature Design System
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
struct AddPetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var species = PetSpecies.dog
    @State private var breed = ""
    @State private var birthYear: Int?
    @State private var birthMonth: Int?
    @State private var weightKg: Double?
    @State private var activityLevel: PetActivityLevel = .moderate
    @State private var selectedImage: UIImage?
    @State private var knownSensitivities: [String] = []
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var newSensitivity = ""
    @State private var showingAlert = false
    @State private var validationErrors: [String] = []
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    @StateObject private var gatekeeper = SubscriptionGatekeeper.shared
    @State private var showingPaywall = false
    
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
            .navigationTitle("Add Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.red.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePet()
                    }
                    .disabled(!isFormValid)
                    .foregroundColor(isFormValid ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
                    .accessibilityIdentifier("savePetButton")
                    .accessibilityLabel("Save pet profile")
                    .accessibilityHint("Saves the pet information to your profile")
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(CachedPetService.shared.errorMessage ?? "An error occurred")
            }
            .onChange(of: CachedPetService.shared.errorMessage) { _, errorMessage in
                if errorMessage != nil {
                    showingAlert = true
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: Binding(
                get: { gatekeeper.showingUpgradePrompt && !showingPaywall },
                set: { gatekeeper.showingUpgradePrompt = $0 }
            )) {
                UpgradePromptView(
                    title: gatekeeper.upgradePromptTitle,
                    message: gatekeeper.upgradePromptMessage
                )
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
                PetImagePickerView(
                    selectedImage: $selectedImage,
                    species: species
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
                
                // Species
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Species")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Picker("Species", selection: $species) {
                        ForEach(PetSpecies.allCases, id: \.self) { speciesOption in
                            Text(speciesOption.displayName)
                                .tag(speciesOption)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("speciesPicker")
                    .accessibilityLabel("Pet species")
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
                            
                            Picker("Year", selection: $birthYear) {
                                Text("Select Year").tag(nil as Int?)
                                ForEach(availableYears, id: \.self) { year in
                                    Text(String(format: "%d", year)).tag(year as Int?)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                            .padding(.vertical, ModernDesignSystem.Spacing.sm)
                            .background(ModernDesignSystem.Colors.softCream)
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                            )
                            .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        }
                        
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Month")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Picker("Month", selection: $birthMonth) {
                                Text("Select Month").tag(nil as Int?)
                                ForEach(availableMonths, id: \.0) { month in
                                    Text("\(month.1) - \(String(format: "%02d", month.0))").tag(month.0 as Int?)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                            .padding(.vertical, ModernDesignSystem.Spacing.sm)
                            .background(ModernDesignSystem.Colors.softCream)
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                            )
                            .cornerRadius(ModernDesignSystem.CornerRadius.small)
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
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.softCream)
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                            .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                    )
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
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
    
    /// Check if form is valid
    private var isFormValid: Bool {
        let petCreate = PetCreate(
            name: name,
            species: species,
            breed: breed.isEmpty ? nil : breed,
            birthday: createBirthday(year: birthYear, month: birthMonth),
            weightKg: weightKg,
            activityLevel: activityLevel,
            imageUrl: nil,
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
            species: species,
            breed: breed.isEmpty ? nil : breed,
            birthday: createBirthday(year: birthYear, month: birthMonth),
            weightKg: weightKg,
            activityLevel: activityLevel,
            imageUrl: nil,
            knownSensitivities: knownSensitivities,
            vetName: vetName.isEmpty ? nil : vetName,
            vetPhone: vetPhone.isEmpty ? nil : vetPhone
        )
        validationErrors = petCreate.validationErrors
    }
    
    private func savePet() {
        Task {
            do {
                var imageUrl: String? = nil
                
                // Upload image to Supabase Storage if selected
                if let selectedImage = selectedImage {
                    // Get current user ID for folder organization
                    guard let userId = AuthService.shared.currentUser?.id else {
                        CachedPetService.shared.errorMessage = "User not authenticated"
                        return
                    }
                    
                    // Generate a temporary pet ID for folder organization
                    let tempPetId = UUID().uuidString
                    
                    // Upload image to Supabase Storage
                    imageUrl = try await StorageService.shared.uploadPetImage(
                        image: selectedImage,
                        userId: userId,
                        petId: tempPetId
                    )
                    
                    print("📸 Pet image uploaded to Supabase: \(imageUrl ?? "nil")")
                }
                
                // Convert weight to kg for storage (backend expects kg)
                let weightInKg = weightKg != nil ? unitService.convertToKg(weightKg!) : nil
                
                let petCreate = PetCreate(
                    name: name,
                    species: species,
                    breed: breed.isEmpty ? nil : breed,
                    birthday: createBirthday(year: birthYear, month: birthMonth),
                    weightKg: weightInKg,
                    activityLevel: activityLevel,
                    imageUrl: imageUrl,
                    knownSensitivities: knownSensitivities,
                    vetName: vetName.isEmpty ? nil : vetName,
                    vetPhone: vetPhone.isEmpty ? nil : vetPhone
                )
                
                // Check subscription limit before creating pet
                let currentPetCount = CachedPetService.shared.pets.count
                if !gatekeeper.canAddPet(currentPetCount: currentPetCount) {
                    gatekeeper.showPetLimitPrompt()
                    return
                }
                
                CachedPetService.shared.createPet(petCreate)
                
                // Dismiss after successful creation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if CachedPetService.shared.errorMessage == nil {
                        dismiss()
                    }
                }
            } catch {
                CachedPetService.shared.errorMessage = "Failed to upload image: \(error.localizedDescription)"
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
    
    // MARK: - Computed Properties
    
    /// Available years for selection (from 1900 to current year)
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(1900...currentYear).reversed()
    }
    
    /// Available months for selection with display names
    private var availableMonths: [(Int, String)] {
        return [
            (1, "January"), (2, "February"), (3, "March"), (4, "April"),
            (5, "May"), (6, "June"), (7, "July"), (8, "August"),
            (9, "September"), (10, "October"), (11, "November"), (12, "December")
        ]
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
}

#Preview("With Mock Data") {
    // Note: Using shared instance for preview purposes
    AddPetView()
}

