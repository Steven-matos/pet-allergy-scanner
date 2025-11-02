//
//  OnboardingView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/2025.
//

import SwiftUI

/// Onboarding view for new users to set up their first pet
struct OnboardingView: View {
    @State private var petService = CachedPetService.shared
    @StateObject private var authService = AuthService.shared
    
    /// Callback when user skips onboarding
    let onSkip: () -> Void
    
    @State private var currentStep = 0
    @State private var name = ""
    @State private var species = PetSpecies.dog
    @State private var breed = ""
    @State private var birthYear: Int?
    @State private var birthMonth: Int?
    @State private var weightKg: Double?
    @State private var activityLevel: PetActivityLevel = .moderate
    @State private var knownSensitivities: [String] = []
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var newSensitivity = ""
    @State private var showingAlert = false
    @State private var validationErrors: [String] = []
    @State private var isCreatingPet = false
    @State private var showNameValidationError = false
    @State private var petImage: UIImage?
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isBreedFieldFocused: Bool
    @FocusState private var isWeightFieldFocused: Bool
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
    private let totalSteps = 4
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Progress indicator
                        ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(ModernDesignSystem.Colors.primary)
                            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                            .padding(.top, ModernDesignSystem.Spacing.sm)
                        
                        // Step content
                        TabView(selection: $currentStep) {
                            // Step 1: Welcome
                            welcomeStep
                                .tag(0)
                            
                            // Step 2: Basic Pet Info
                            basicInfoStep
                                .tag(1)
                            
                            // Step 3: Physical Info
                            physicalInfoStep
                                .tag(2)
                            
                            // Step 4: Allergies & Vet Info
                            allergiesAndVetStep
                                .tag(3)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut, value: currentStep)
                        .frame(height: UIScreen.main.bounds.height * 0.7) // Fixed height for TabView
                        .simultaneousGesture(
                            DragGesture().onChanged { _ in
                                // Block swipe if on step 1 and validation fails
                                if currentStep == 1 && !canProceed {
                                    showNameValidationError = true
                                    isNameFieldFocused = true
                                }
                            }
                        )
                        .onChange(of: currentStep) { oldValue, newValue in
                            // Prevent swiping forward if validation fails
                            if newValue > oldValue {
                                // User is trying to move forward
                                if !canProceedFromStep(oldValue) {
                                    // Show validation error and reset
                                    withAnimation {
                                        if oldValue == 1 {
                                            // Pet name validation failed
                                            showNameValidationError = true
                                            isNameFieldFocused = true
                                        }
                                        currentStep = oldValue
                                    }
                                    
                                    // Auto-hide validation error after 2 seconds
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        withAnimation {
                                            showNameValidationError = false
                                        }
                                    }
                                } else {
                                    // Validation passed, hide any errors
                                    showNameValidationError = false
                                }
                            }
                        }
                    }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
                .onChange(of: isNameFieldFocused) { _, isFocused in
                    if isFocused {
                        // Scroll to the name field when it gets focus
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("nameField", anchor: UnitPoint.center)
                            }
                        }
                    }
                }
                .onChange(of: isBreedFieldFocused) { _, isFocused in
                    if isFocused {
                        // Scroll to the breed field when it gets focus
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("breedField", anchor: UnitPoint.center)
                            }
                        }
                    }
                }
                .onChange(of: isWeightFieldFocused) { _, isFocused in
                    if isFocused {
                        // Scroll to the weight field when it gets focus
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("weightField", anchor: UnitPoint.center)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Navigation buttons using modern SwiftUI bottom placement
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    // Back/Skip button - 1/3 width
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .stroke(ModernDesignSystem.Colors.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Skip button (only show on first step) - 1/3 width
                    if currentStep == 0 {
                        Button("Skip for now") {
                            // Skip onboarding for this session only
                            // User will see onboarding again next time until they add a pet
                            onSkip()
                        }
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .stroke(ModernDesignSystem.Colors.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Next/Complete button - 2/3 width
                    Button(action: {
                        if currentStep == totalSteps - 1 {
                            createPet()
                        } else {
                            // Validate before moving forward
                            if canProceed {
                                withAnimation {
                                    currentStep += 1
                                    showNameValidationError = false
                                }
                            } else if currentStep == 1 {
                                // Show validation error for pet name
                                withAnimation {
                                    showNameValidationError = true
                                    isNameFieldFocused = true
                                }
                                
                                // Auto-hide after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation {
                                        showNameValidationError = false
                                    }
                                }
                            }
                        }
                    }) {
                        ZStack {
                            Text(currentStep == totalSteps - 1 ? "Complete Setup" : "Next")
                                .opacity(isCreatingPet ? 0 : 1)
                            
                            if isCreatingPet {
                                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(ModernDesignSystem.Colors.textOnPrimary)
                                    Text("Creating...")
                                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                                }
                            }
                        }
                    }
                    .font(ModernDesignSystem.Typography.bodyEmphasized)
                    .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                            .fill(ModernDesignSystem.Colors.primary)
                    )
                    .disabled(!canProceed || isCreatingPet)
                    .opacity((!canProceed || isCreatingPet) ? 0.5 : 1.0)
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.vertical, ModernDesignSystem.Spacing.md)
                .background(
                    ModernDesignSystem.Colors.softCream
                        .shadow(
                            color: ModernDesignSystem.Shadows.medium.color,
                            radius: ModernDesignSystem.Shadows.medium.radius,
                            x: ModernDesignSystem.Shadows.medium.x,
                            y: ModernDesignSystem.Shadows.medium.y
                        )
                )
            }
            .navigationBarHidden(true)
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
        }
    }
    
    // MARK: - Step Views
    
    private var welcomeStep: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            Spacer()
            
            // Welcome illustration
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                Text("Welcome to SniffTest!")
                    .font(ModernDesignSystem.Typography.largeTitle)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Image("Illustrations/welcome")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                
                Text("Let's set up your first pet profile to get started with ingredient scanning and safety monitoring.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            }
            
            // Features preview
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                FeatureRow(icon: "camera.viewfinder", title: "Scan Ingredients", description: "Use your camera to scan pet food labels")
                FeatureRow(icon: "chart.bar.fill", title: "Nutrition Tracking", description: "Monitor feeding, calories, and health trends")
                FeatureRow(icon: "exclamationmark.triangle", title: "Allergy Alerts", description: "Get instant warnings about harmful ingredients")
                FeatureRow(icon: "heart.fill", title: "Pet Safety", description: "Keep your furry friends healthy and happy")
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            Spacer()
        }
    }
    
    private var basicInfoStep: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Text("Tell us about your pet")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("We'll use this information to provide personalized safety recommendations.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, ModernDesignSystem.Spacing.xxl)
            
            VStack(spacing: ModernDesignSystem.Spacing.lg) {

                // Pet Photo (optional)
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Pet Photo (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        Spacer()
                        PetImagePickerView(
                            selectedImage: $petImage,
                            species: species
                        )
                        Spacer()
                    }
                }

                // Pet name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Pet Name *")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter your pet's name", text: $name)
                        .focused($isNameFieldFocused)
                        .modernInputField()
                        .background(
                            showNameValidationError ? 
                                Color(hex: "#FFF3E0") : // Light amber background for validation
                                Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(
                                    showNameValidationError ? 
                                        Color(hex: "#FFB300") : // Amber border for validation
                                        Color.clear, 
                                    lineWidth: showNameValidationError ? 2 : 0
                                )
                        )
                        .animation(.easeInOut(duration: 0.3), value: showNameValidationError)
                        .onChange(of: name) { _, _ in
                            validateForm()
                            showNameValidationError = false
                        }
                        .id("nameField")
                    
                    if showNameValidationError {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Color(hex: "#FFB300"))
                            Text("Pet name is required and must be at least 2 characters")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(Color(hex: "#FFB300"))
                        }
                    } else if validationErrors.contains(where: { $0.contains("name") }) {
                        Text(validationErrors.first(where: { $0.contains("name") }) ?? "")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                }
                
                // Species
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Species *")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Picker("Species", selection: $species) {
                        Text("Dog").tag(PetSpecies.dog)
                        Text("Cat").tag(PetSpecies.cat)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: species) { _, _ in
                        validateForm()
                    }
                }
                
                // Breed (optional)
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Breed (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("e.g., Golden Retriever", text: $breed)
                        .focused($isBreedFieldFocused)
                        .modernInputField()
                        .id("breedField")
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            Spacer()
        }
    }
    
    private var physicalInfoStep: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Text("Physical Information")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)

                Image("Illustrations/running")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 250, maxHeight: 250)
                
                Text("Help us track your pet's health and activity for personalized nutrition recommendations.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, ModernDesignSystem.Spacing.xxl)
            
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Birthday
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Birthday (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack(spacing: ModernDesignSystem.Spacing.md) {
                        Picker("Year", selection: $birthYear) {
                            Text("Year").tag(nil as Int?)
                            ForEach(availableYears, id: \.self) { year in
                                Text(String(format: "%d", year)).tag(year as Int?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        
                        Picker("Month", selection: $birthMonth) {
                            Text("Month").tag(nil as Int?)
                            ForEach(availableMonths, id: \.0) { month, name in
                                Text("\(name) - \(String(format: "%02d", month))").tag(month as Int?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: birthYear) { _, _ in validateForm() }
                    .onChange(of: birthMonth) { _, _ in validateForm() }
                    
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
                
                // Weight
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Weight (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        TextField("Weight (\(unitService.getUnitSymbol()))", value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($isWeightFieldFocused)
                            .modernInputField()
                            .onChange(of: weightKg) { _, _ in
                                validateForm()
                            }
                            .id("weightField")
                        
                        Text(unitService.getUnitSymbol())
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    if validationErrors.contains(where: { $0.contains("Weight") }) {
                        Text(validationErrors.first(where: { $0.contains("Weight") }) ?? "")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                }
                
                // Activity Level
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Activity Level")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Picker("Activity Level", selection: $activityLevel) {
                        Text("Low").tag(PetActivityLevel.low)
                        Text("Moderate").tag(PetActivityLevel.moderate)
                        Text("High").tag(PetActivityLevel.high)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            Spacer()
        }
        .padding(.bottom, ModernDesignSystem.Spacing.lg)
    }
    
    private var allergiesAndVetStep: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Text("Health & Safety")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Share any known allergies or sensitivities to help us keep your pet safe.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, ModernDesignSystem.Spacing.xxl)
            
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Known Sensitivities
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Known Sensitivities (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    if !knownSensitivities.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: ModernDesignSystem.Spacing.sm) {
                            ForEach(knownSensitivities, id: \.self) { sensitivity in
                                HStack {
                                    Text(sensitivity)
                                        .font(ModernDesignSystem.Typography.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                    
                                    Button(action: {
                                        knownSensitivities.removeAll { $0 == sensitivity }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                                    }
                                }
                                .modernCard()
                            }
                        }
                    }
                    
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    TextField("Add sensitivity", text: $newSensitivity)
                        .modernInputField()
                        
                        Button("Add") {
                            if !newSensitivity.isEmpty {
                                knownSensitivities.append(newSensitivity)
                                newSensitivity = ""
                            }
                        }
                        .modernButton(style: .primary)
                        .disabled(newSensitivity.isEmpty)
                        .opacity(newSensitivity.isEmpty ? 0.5 : 1.0)
                    }
                }
                
                // Vet information
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Veterinary Information (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Vet Name", text: $vetName)
                        .modernInputField()
                    
                    TextField("Vet Phone", text: $vetPhone)
                        .keyboardType(.phonePad)
                        .modernInputField()
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            Spacer()
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
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return true // Welcome step
        case 1:
            return !name.isEmpty && name.count >= 2 // Basic info step
        case 2:
            return true // Physical info step (all optional)
        case 3:
            return true // Allergies and vet step (all optional)
        default:
            return false
        }
    }
    
    /// Check if user can proceed from a specific step (used for swipe validation)
    /// - Parameter step: The step number to validate
    /// - Returns: True if validation passes for that step
    private func canProceedFromStep(_ step: Int) -> Bool {
        switch step {
        case 0:
            return true // Welcome step
        case 1:
            return !name.isEmpty && name.count >= 2 // Basic info step - pet name required
        case 2:
            return true // Physical info step (all optional)
        case 3:
            return true // Allergies and vet step (all optional)
        default:
            return false
        }
    }
    
    // MARK: - Methods
    
    private func validateForm() {
        // Convert weight to kg for validation (backend expects kg)
        let weightInKg = weightKg != nil ? unitService.convertToKg(weightKg!) : nil
        
        let petCreate = PetCreate(
            name: name,
            species: species,
            breed: breed.isEmpty ? nil : breed,
            birthday: createBirthday(year: birthYear, month: birthMonth),
            weightKg: weightInKg,
            activityLevel: activityLevel,
            imageUrl: nil,
            knownSensitivities: knownSensitivities,
            vetName: vetName.isEmpty ? nil : vetName,
            vetPhone: vetPhone.isEmpty ? nil : vetPhone
        )
        validationErrors = petCreate.validationErrors
    }
    
    /// Create pet and mark onboarding as complete
    private func createPet() {
        isCreatingPet = true
        
        // Convert weight to kg for storage (backend expects kg)
        let weightInKg = weightKg != nil ? unitService.convertToKg(weightKg!) : nil
        
        // Create the pet with image upload
        Task {
            var imageUrl: String? = nil
            
            // Upload pet image if provided
            if let petImage = petImage,
               let userId = authService.currentUser?.id {
                do {
                    // Generate a temporary pet ID for image upload
                    let tempPetId = UUID().uuidString
                    imageUrl = try await StorageService.shared.uploadPetImage(
                        image: petImage,
                        userId: userId,
                        petId: tempPetId
                    )
                    print("📸 Pet image uploaded successfully: \(imageUrl ?? "nil")")
                } catch {
                    print("⚠️ Failed to upload pet image: \(error)")
                    // Continue with pet creation even if image upload fails
                }
            }
            
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
            
            // Use the pet service's createPet method
            petService.createPet(petCreate)
            
            // Wait for the pet creation to complete by monitoring the service state
            while petService.isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            await MainActor.run {
                if petService.errorMessage == nil {
                    // Pet created successfully - mark onboarding as complete
                    petService.completeOnboarding()
                    
                    // Even if onboarding completion fails, the pet was created successfully
                    // The user can proceed to the main app
                    print("✅ Pet created successfully - onboarding flow complete")
                } else {
                    print("❌ Pet creation failed: \(petService.errorMessage ?? "Unknown error")")
                }
                isCreatingPet = false
            }
        }
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

// MARK: - Supporting Views

/// Feature row component displaying an icon, title, and description
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(ModernDesignSystem.Typography.title2)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(title)
                    .font(ModernDesignSystem.Typography.bodyEmphasized)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onSkip: {
        print("Skipped onboarding")
    })
}