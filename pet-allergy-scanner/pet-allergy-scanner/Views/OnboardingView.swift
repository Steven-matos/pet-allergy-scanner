//
//  OnboardingView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/// Onboarding view for new users to set up their first pet
struct OnboardingView: View {
    @EnvironmentObject var petService: PetService
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
    @State private var knownSensitivities: [String] = []
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var newSensitivity = ""
    @State private var showingAlert = false
    @State private var validationErrors: [String] = []
    @State private var isCreatingPet = false
    @State private var showingYearPicker = false
    @State private var showingMonthPicker = false
    
    private let totalSteps = 4
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(ModernDesignSystem.Colors.deepForestGreen)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
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
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep -= 1
                            }
                        }
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
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .padding(.trailing, 16)
                    }
                    
                    Button(currentStep == totalSteps - 1 ? "Complete Setup" : "Next") {
                        if currentStep == totalSteps - 1 {
                            createPet()
                        } else {
                            withAnimation {
                                currentStep += 1
                            }
                        }
                    }
                    .font(.headline)
                    .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ModernDesignSystem.Colors.buttonPrimary)
                    .cornerRadius(10)
                    .disabled(!canProceed || isCreatingPet)
                    .overlay(
                        Group {
                            if isCreatingPet {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(ModernDesignSystem.Colors.textOnPrimary)
                                    Text("Creating...")
                                        .font(.headline)
                                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                                }
                            }
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
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
    
    // MARK: - Step Views
    
    private var welcomeStep: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Welcome illustration
            VStack(spacing: 20) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 100))
                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                
                Text("Welcome to SniffSafe!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Let's set up your first pet profile to get started with ingredient scanning and safety monitoring.")
                    .font(.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Features preview
            VStack(spacing: 16) {
                FeatureRow(icon: "camera.viewfinder", title: "Scan Ingredients", description: "Use your camera to scan pet food labels")
                FeatureRow(icon: "exclamationmark.triangle", title: "Allergy Alerts", description: "Get instant warnings about harmful ingredients")
                FeatureRow(icon: "heart.fill", title: "Pet Safety", description: "Keep your furry friends healthy and happy")
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    private var basicInfoStep: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Text("Tell us about your pet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("We'll use this information to provide personalized safety recommendations.")
                    .font(.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(spacing: 20) {
                // Pet name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pet Name *")
                        .font(.headline)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter your pet's name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) { _, _ in
                            validateForm()
                        }
                    
                    if validationErrors.contains(where: { $0.contains("name") }) {
                        Text(validationErrors.first(where: { $0.contains("name") }) ?? "")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                }
                
                // Species selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Species *")
                        .font(.headline)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Breed (Optional)")
                        .font(.headline)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("e.g., Golden Retriever", text: $breed)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    private var physicalInfoStep: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Text("Physical Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("This helps us provide age and size-appropriate recommendations.")
                    .font(.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(spacing: 20) {
                // Birthday
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
                
                // Weight
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight (Optional)")
                        .font(.headline)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        TextField("Weight", value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: weightKg) { _, _ in
                                validateForm()
                            }
                        
                        Text("kg")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    if validationErrors.contains(where: { $0.contains("Weight") }) {
                        Text(validationErrors.first(where: { $0.contains("Weight") }) ?? "")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    private var allergiesAndVetStep: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                Text("Health & Safety Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Help us keep your pet safe by sharing any known allergies and vet information.")
                    .font(.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(spacing: 20) {
                // Known allergies
                VStack(alignment: .leading, spacing: 8) {
                    Text("Food Sensitivities (Optional)")
                        .font(.headline)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
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
                        .padding(.vertical, 4)
                    }
                    
                    HStack {
                        TextField("Add sensitivity", text: $newSensitivity)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            if !newSensitivity.isEmpty {
                                knownSensitivities.append(newSensitivity)
                                newSensitivity = ""
                            }
                        }
                        .disabled(newSensitivity.isEmpty)
                        .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                    }
                }
                
                // Vet information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Veterinary Information (Optional)")
                        .font(.headline)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Vet Name", text: $vetName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Vet Phone", text: $vetPhone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Available years for selection (from 1900 to current year)
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(1900...currentYear).reversed()
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
    
    // MARK: - Methods
    
    private func validateForm() {
        let petCreate = PetCreate(
            name: name,
            species: species,
            breed: breed.isEmpty ? nil : breed,
            birthday: createBirthday(year: birthYear, month: birthMonth),
            weightKg: weightKg,
            knownSensitivities: knownSensitivities,
            vetName: vetName.isEmpty ? nil : vetName,
            vetPhone: vetPhone.isEmpty ? nil : vetPhone
        )
        validationErrors = petCreate.validationErrors
    }
    
    /// Create pet and mark onboarding as complete
    private func createPet() {
        isCreatingPet = true
        
        let petCreate = PetCreate(
            name: name,
            species: species,
            breed: breed.isEmpty ? nil : breed,
            birthday: createBirthday(year: birthYear, month: birthMonth),
            weightKg: weightKg,
            knownSensitivities: knownSensitivities,
            vetName: vetName.isEmpty ? nil : vetName,
            vetPhone: vetPhone.isEmpty ? nil : vetPhone
        )
        
        // Create the pet first
        Task {
            petService.createPet(petCreate)
            
            // Wait for the pet creation to complete
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await MainActor.run {
                if petService.errorMessage == nil {
                    // Pet created successfully - mark onboarding as complete
                    petService.completeOnboarding()
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

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Picker Views

struct YearPickerView: View {
    @Binding var selectedYear: Int?
    let availableYears: [Int]
    @Binding var showingYearPicker: Bool
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showingYearPicker = false
                }
            
            VStack(spacing: 0) {
                Text("Select Year")
                    .font(.headline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .padding(.top, 20)
                
                List {
                    Button("None") {
                        selectedYear = nil
                        showingYearPicker = false
                    }
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    ForEach(availableYears, id: \.self) { year in
                        Button("\(year, specifier: "%d")") {
                            print("Year selected: \(year)")
                            selectedYear = year
                            showingYearPicker = false
                        }
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                }
                .frame(maxHeight: 300)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                Button("Cancel") {
                    showingYearPicker = false
                }
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .padding(.top, 10)
            }
        }
    }
}

struct MonthPickerView: View {
    @Binding var selectedMonth: Int?
    @Binding var showingMonthPicker: Bool
    
    private let months = [
        (1, "January"), (2, "February"), (3, "March"), (4, "April"),
        (5, "May"), (6, "June"), (7, "July"), (8, "August"),
        (9, "September"), (10, "October"), (11, "November"), (12, "December")
    ]
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showingMonthPicker = false
                }
            
            VStack(spacing: 0) {
                Text("Select Month")
                    .font(.headline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .padding(.top, 20)
                
                List {
                    Button("None") {
                        selectedMonth = nil
                        showingMonthPicker = false
                    }
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    ForEach(months, id: \.0) { month in
                        Button(month.1) {
                            selectedMonth = month.0
                            showingMonthPicker = false
                        }
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                }
                .frame(maxHeight: 300)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                Button("Cancel") {
                    showingMonthPicker = false
                }
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .padding(.top, 10)
            }
        }
    }
}


#Preview {
    OnboardingView(onSkip: {
        print("Skipped onboarding")
    })
    .environmentObject(PetService.shared)
}
