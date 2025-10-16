//
//  AddHealthEventView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import SwiftUI

/**
 * Add Health Event View
 * 
 * Simple form for logging health events with 8 core types + Other option
 * Follows SOLID principles with single responsibility for health event creation
 * Implements DRY by reusing common form patterns
 * Follows KISS by keeping the form simple and uncluttered
 */
struct AddHealthEventView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var healthEventService = HealthEventService.shared
    @StateObject private var petService = PetService.shared
    
    @State private var selectedPet: Pet?
    @State private var selectedEventType: HealthEventType = .vomiting
    @State private var title = ""
    @State private var notes = ""
    @State private var severityLevel = 1
    @State private var eventDate = Date()
    @State private var customEventName = ""
    @State private var isSubmitting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasAutoSelectedPet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ModernDesignSystem.Colors.softCream
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ModernDesignSystem.Spacing.lg) {
                        // Header
                        headerSection
                        
                        // Form
                        formSection
                    }
                    .padding(ModernDesignSystem.Spacing.lg)
                }
            }
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSubmitting ? "Saving..." : "Save") {
                        saveHealthEvent()
                    }
                    .font(ModernDesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .disabled(!isFormValid || isSubmitting)
                }
            }
        }
        .onAppear {
            setupInitialValues()
            // Auto-select pet if only one exists
            if petService.pets.count == 1 && !hasAutoSelectedPet {
                selectedPet = petService.pets.first
                hasAutoSelectedPet = true
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(ModernDesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text(headerSubtitle)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .fill(ModernDesignSystem.Colors.background)
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
        )
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Pet Selection
            petSelectionSection
            
            // Event Type Selection
            eventTypeSection
            
            // Custom Event Name (if Other selected)
            if selectedEventType == .other {
                customEventNameSection
            }
            
            // Event Details
            eventDetailsSection
            
            // Severity Level
            severitySection
            
            // Date & Time
            dateTimeSection
            
            // Notes
            notesSection
        }
    }
    
    // MARK: - Pet Selection Section
    
    private var petSelectionSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Select Pet")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if petService.pets.isEmpty {
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Image(systemName: "pawprint.fill")
                        .font(.title)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Text("No pets added yet")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Text("Add a pet first to log health events")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(ModernDesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(ModernDesignSystem.Colors.background)
                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                )
            } else if petService.pets.count == 1 {
                // Auto-select single pet
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    HStack {
                        AsyncImage(url: URL(string: petService.pets.first?.imageUrl ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: petService.pets.first?.species.icon ?? "pawprint.fill")
                                .foregroundColor(ModernDesignSystem.Colors.primary)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Logging for \(petService.pets.first?.name ?? "your pet")")
                                .font(ModernDesignSystem.Typography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Text("Automatically selected")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.success)
                    }
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(ModernDesignSystem.Colors.background)
                        .stroke(ModernDesignSystem.Colors.success, lineWidth: 1)
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: ModernDesignSystem.Spacing.md) {
                    ForEach(petService.pets) { pet in
                        HealthEventPetSelectionCard(
                            pet: pet,
                            isSelected: selectedPet?.id == pet.id
                        ) {
                            selectedPet = pet
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Event Type Section
    
    private var eventTypeSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("What happened to \(currentPetName)?")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(HealthEventType.allCases, id: \.self) { eventType in
                    EventTypeButton(
                        eventType: eventType,
                        isSelected: selectedEventType == eventType
                    ) {
                        selectedEventType = eventType
                        updateTitle()
                    }
                }
            }
        }
    }
    
    // MARK: - Custom Event Name Section
    
    private var customEventNameSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("What happened to \(currentPetName)?")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            TextField("Describe what happened to \(currentPetName)", text: $customEventName)
                .textFieldStyle(ModernTextFieldStyle())
                .onChange(of: customEventName) {
                    updateTitle()
                }
        }
    }
    
    // MARK: - Event Details Section
    
    private var eventDetailsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Event Title")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            TextField("Brief description for \(currentPetName)", text: $title)
                .textFieldStyle(ModernTextFieldStyle())
        }
    }
    
    // MARK: - Severity Section
    
    private var severitySection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Text("How severe was this for \(currentPetName)?")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text(severityDescription)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Slider(
                    value: Binding(
                        get: { Double(severityLevel) },
                        set: { severityLevel = Int($0) }
                    ),
                    in: 1...5,
                    step: 1
                )
                .accentColor(severityColor)
                
                HStack {
                    ForEach(1...5, id: \.self) { level in
                        Circle()
                            .fill(level <= severityLevel ? severityColor : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
    }
    
    // MARK: - Date Time Section
    
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("When did this happen to \(currentPetName)?")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            DatePicker(
                "Event Date",
                selection: $eventDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(CompactDatePickerStyle())
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Additional details about \(currentPetName)")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            TextField("Add any additional details about what happened to \(currentPetName)...", text: $notes, axis: .vertical)
                .textFieldStyle(ModernTextFieldStyle())
                .lineLimit(3...6)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        // For single pet users, selectedPet will be auto-selected
        let hasValidPet = selectedPet != nil || (petService.pets.count == 1 && petService.pets.first != nil)
        return hasValidPet && !title.isEmpty && (selectedEventType != .other || !customEventName.isEmpty)
    }
    
    private var currentPetName: String {
        if let selectedPet = selectedPet {
            return selectedPet.name
        } else if petService.pets.count == 1, let singlePet = petService.pets.first {
            return singlePet.name
        } else {
            return "your pet"
        }
    }
    
    private var headerTitle: String {
        if petService.pets.count == 1 {
            return "Add Health Event for \(currentPetName)"
        } else {
            return "Add Health Event"
        }
    }
    
    private var headerSubtitle: String {
        if petService.pets.count == 1 {
            return "Track \(currentPetName)'s health events and patterns"
        } else {
            return "Track health events and patterns"
        }
    }
    
    private var severityDescription: String {
        switch severityLevel {
        case 1: return "Mild"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "High"
        case 5: return "Severe"
        default: return "Unknown"
        }
    }
    
    private var severityColor: Color {
        switch severityLevel {
        case 1: return ModernDesignSystem.Colors.safe
        case 2: return ModernDesignSystem.Colors.goldenYellow
        case 3: return ModernDesignSystem.Colors.warmCoral
        case 4: return ModernDesignSystem.Colors.error
        case 5: return ModernDesignSystem.Colors.error
        default: return ModernDesignSystem.Colors.textSecondary
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialValues() {
        updateTitle()
    }
    
    private func updateTitle() {
        if selectedEventType == .other {
            title = customEventName.isEmpty ? "Custom Event" : customEventName
        } else {
            title = selectedEventType.displayName
        }
    }
    
    private func saveHealthEvent() {
        guard isFormValid else { return }
        
        // Get the pet - either selected or auto-selected for single pet users
        let pet: Pet
        if let selectedPet = selectedPet {
            pet = selectedPet
        } else if petService.pets.count == 1, let singlePet = petService.pets.first {
            pet = singlePet
        } else {
            return
        }
        
        isSubmitting = true
        
        Task {
            do {
                let finalTitle = selectedEventType == .other ? customEventName : title
                
                _ = try await healthEventService.createHealthEvent(
                    for: pet.id,
                    eventType: selectedEventType,
                    title: finalTitle,
                    notes: notes.isEmpty ? nil : notes,
                    severityLevel: severityLevel,
                    eventDate: eventDate
                )
                
                await MainActor.run {
                    isSubmitting = false
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Event Type Button

struct EventTypeButton: View {
    let eventType: HealthEventType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: eventType.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .white : eventType.category.color)
                
                Text(eventType.displayName)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : ModernDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .fill(isSelected ? eventType.category.color : ModernDesignSystem.Colors.background)
                    .shadow(
                        color: ModernDesignSystem.Shadows.small.color,
                        radius: ModernDesignSystem.Shadows.small.radius,
                        x: ModernDesignSystem.Shadows.small.x,
                        y: ModernDesignSystem.Shadows.small.y
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Health Event Pet Selection Card

struct HealthEventPetSelectionCard: View {
    let pet: Pet
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                AsyncImage(url: URL(string: pet.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: pet.species.icon)
                        .foregroundColor(isSelected ? .white : ModernDesignSystem.Colors.primary)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                Text(pet.name)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : ModernDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(pet.species.rawValue.capitalized)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : ModernDesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .padding(ModernDesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .fill(isSelected ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.background)
                    .stroke(isSelected ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.borderPrimary, lineWidth: isSelected ? 2 : 1)
                    .shadow(
                        color: ModernDesignSystem.Shadows.small.color,
                        radius: ModernDesignSystem.Shadows.small.radius,
                        x: ModernDesignSystem.Shadows.small.x,
                        y: ModernDesignSystem.Shadows.small.y
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Modern Text Field Style

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(ModernDesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .fill(ModernDesignSystem.Colors.background)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
    }
}

#Preview {
    AddHealthEventView()
}
