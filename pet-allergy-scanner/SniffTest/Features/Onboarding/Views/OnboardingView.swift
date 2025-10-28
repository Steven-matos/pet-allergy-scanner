//
//  OnboardingView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
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
    @FocusState private var isNameFieldFocused: Bool
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
    private let totalSteps = 4
    
    var body: some View {
        NavigationStack {
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
                .simultaneousGesture(
                    DragGesture().onChanged { _ in
                        // Block swipe if on step 1 and validation fails
                        if currentStep == 1 && !canProceed {
                            showNameValidationError = true
                            isNameFieldFocused = true
                            
                            // Auto-hide validation error after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    showNameValidationError = false
                                }
                            }
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
                
                // Navigation buttons
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Skip button (only show on first step)
                    if currentStep == 0 {
                        Button("Skip for now") {
                            // Skip onboarding for this session only
                            // User will see onboarding again next time until they add a pet
                            onSkip()
                        }
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .padding(.trailing, ModernDesignSystem.Spacing.md)
                    }
                    
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
                                .font(ModernDesignSystem.Typography.bodyEmphasized)
                                .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                                .padding(.vertical, ModernDesignSystem.Spacing.md)
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
                    .frame(maxWidth: .infinity)
                    .background(ModernDesignSystem.Colors.buttonPrimary)
                    .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                    .shadow(
                        color: ModernDesignSystem.Shadows.small.color,
                        radius: ModernDesignSystem.Shadows.small.radius,
                        x: ModernDesignSystem.Shadows.small.x,
                        y: ModernDesignSystem.Shadows.small.y
                    )
                    .disabled(!canProceed || isCreatingPet)
                    .opacity((!canProceed || isCreatingPet) ? 0.5 : 1.0)
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.bottom, ModernDesignSystem.Spacing.xl)
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
                // Pet name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Pet Name *")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter your pet's name", text: $name)
                        .focused($isNameFieldFocused)
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(
                            showNameValidationError ? 
                                Color(hex: "#FFF3E0") : // Light amber background
                                ModernDesignSystem.Colors.surface
                        )
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(
                                    showNameValidationError ? 
                                        Color(hex: "#FFB300") : // Amber border
                                        ModernDesignSystem.Colors.borderPrimary, 
                                    lineWidth: showNameValidationError ? 2 : 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.3), value: showNameValidationError)
                        .onChange(of: name) { _, _ in
                            validateForm()
                            showNameValidationError = false
                        }
                    
                    if showNameValidationError {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(Color(hex: "#FFB300"))
                                .font(ModernDesignSystem.Typography.caption)
                            Text("Pet name is required (minimum 2 characters)")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(Color(hex: "#FFB300"))
                        }
                        .transition(.opacity)
                    } else if validationErrors.contains(where: { $0.contains("name") }) {
                        Text(validationErrors.first(where: { $0.contains("name") }) ?? "")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                }
                
                // Species selection
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Species *")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Picker("Species", selection: $species) {
                        ForEach(PetSpecies.allCases, id: \.self) { species in
                            Text(species.displayName)
                                .tag(species)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Breed (optional)
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Breed (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("e.g., Golden Retriever", text: $breed)
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(ModernDesignSystem.Colors.surface)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
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
                    .frame(width: 250, height: 250)
                
                Text("This helps us provide age and size-appropriate recommendations.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            }
            .padding(.top, ModernDesignSystem.Spacing.xxl)
            
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Birthday
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Birthday (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack(spacing: ModernDesignSystem.Spacing.md) {
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Year")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            
                            Picker("Year", selection: $birthYear) {
                                Text("Select Year").tag(nil as Int?)
                                ForEach(availableYears, id: \.self) { year in
                                    Text("\(year, specifier: "%d")").tag(year as Int?)
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
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            
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
                
                // Weight
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Weight (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        TextField("Weight (\(unitService.getUnitSymbol()))", value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .padding(ModernDesignSystem.Spacing.md)
                            .background(ModernDesignSystem.Colors.surface)
                            .cornerRadius(ModernDesignSystem.CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                            )
                            .onChange(of: weightKg) { _, _ in
                                validateForm()
                            }
                        
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
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            Spacer()
        }
    }
    
    private var allergiesAndVetStep: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Text("Health & Safety Information")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Help us keep your pet safe by sharing any known allergies and vet information.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, ModernDesignSystem.Spacing.xxl)
            
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Known allergies
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Food Sensitivities (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    ForEach(knownSensitivities, id: \.self) { sensitivity in
                        HStack(spacing: ModernDesignSystem.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
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
                    
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        TextField("Add sensitivity", text: $newSensitivity)
                            .padding(ModernDesignSystem.Spacing.md)
                            .background(ModernDesignSystem.Colors.surface)
                            .cornerRadius(ModernDesignSystem.CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                            )
                        
                        Button("Add") {
                            if !newSensitivity.isEmpty {
                                knownSensitivities.append(newSensitivity)
                                newSensitivity = ""
                            }
                        }
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.surface)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(ModernDesignSystem.Colors.primary, lineWidth: 1)
                        )
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
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(ModernDesignSystem.Colors.surface)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                    
                    TextField("Vet Phone", text: $vetPhone)
                        .keyboardType(.phonePad)
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(ModernDesignSystem.Colors.surface)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
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
        
        // Create the pet first
        Task {
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
