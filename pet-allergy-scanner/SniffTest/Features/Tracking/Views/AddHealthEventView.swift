//
//  AddHealthEventView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import SwiftUI
import Foundation

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
    @State private var petService = CachedPetService.shared
    @StateObject private var gatekeeper = SubscriptionGatekeeper.shared
    
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
    @State private var showingPaywall = false
    @State private var showingUpgradePrompt = false
    
    // Medication-specific fields
    @State private var medicationName = ""
    @State private var dosage = ""
    @State private var frequency: MedicationFrequency = .daily
    @State private var reminderTimes: [MedicationReminderTime] = []
    @State private var startDate = Date()
    @State private var endDate: Date?
    @State private var hasEndDate = false
    @State private var createReminder = false
    
    // Vet visit-specific fields
    @State private var vetDocuments: [VetDocument] = []
    @State private var temporaryEventId = UUID().uuidString // Temporary ID for document uploads
    
    // Performance optimization: Cache computed values
    private var isFormValid: Bool {
        // For single pet users, selectedPet will be auto-selected
        let hasValidPet = selectedPet != nil || (petService.pets.count == 1 && petService.pets.first != nil)
        let hasValidTitle = !title.isEmpty && (selectedEventType != .other || !customEventName.isEmpty)
        
        // For medication events, validate medication fields
        if selectedEventType == .medication {
            let hasMedicationDetails = !medicationName.isEmpty && !dosage.isEmpty
            let hasValidReminder = !createReminder || !reminderTimes.isEmpty
            return hasValidPet && hasValidTitle && hasMedicationDetails && hasValidReminder
        }
        
        return hasValidPet && hasValidTitle
    }
    
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
                    .foregroundColor(Color.red.opacity(0.8))
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
            // Reset reminder toggle for free users
            if gatekeeper.currentTier == .free && createReminder {
                createReminder = false
            }
            // Clear documents for free users
            if gatekeeper.currentTier == .free && !vetDocuments.isEmpty {
                vetDocuments = []
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        // Subscription sheets hidden - app is fully free
        // .sheet(isPresented: $showingPaywall) {
        //     PaywallView()
        // }
        // .sheet(isPresented: $showingUpgradePrompt) {
        //     UpgradePromptView(
        //         title: gatekeeper.upgradePromptTitle.isEmpty ? "Premium Feature" : gatekeeper.upgradePromptTitle,
        //         message: gatekeeper.upgradePromptMessage.isEmpty ? "This feature is available with SniffTest Premium." : gatekeeper.upgradePromptMessage
        //     )
        //     .onDisappear {
        //         // Reset both states when sheet dismisses
        //         showingUpgradePrompt = false
        //         gatekeeper.showingUpgradePrompt = false
        //     }
        // }
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
            
            // Event Details (hide for medication events)
            if selectedEventType != .medication {
                eventDetailsSection
            }
            
            // Severity Level (hide for medication events)
            if selectedEventType != .medication {
                severitySection
            }
            
            // Date & Time
            dateTimeSection
            
            // Medication-specific sections
            if selectedEventType == .medication {
                medicationDetailsSection
                medicationReminderSection
                
                // Notes (moved after medication sections for medication events)
                notesSection
            } else {
                // Notes (for non-medication events)
                notesSection
            }
            
            // Vet visit document upload section
            if selectedEventType == .vetVisit {
                vetDocumentSection
            }
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
        .onAppear {
            print("🐛 DEBUG [AddHealthEventView:appear]")
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
    
    // MARK: - Medication Details Section
    
    private var medicationDetailsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
            Text("Medication Details")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            // Medication Name
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text("Medication Name")
                    .font(ModernDesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                TextField("Enter medication name", text: $medicationName)
                    .textFieldStyle(ModernTextFieldStyle())
            }
            
            // Dosage
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text("Dosage")
                    .font(ModernDesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                TextField("e.g., 10mg, 1 tablet, 5ml", text: $dosage)
                    .textFieldStyle(ModernTextFieldStyle())
            }
            
            // Frequency
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text("How often should \(currentPetName) take this medication?")
                    .font(ModernDesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: ModernDesignSystem.Spacing.sm) {
                    ForEach(MedicationFrequency.allCases, id: \.self) { freq in
                        MedicationFrequencyButton(
                            frequency: freq,
                            isSelected: frequency == freq
                        ) {
                            frequency = freq
                            updateReminderTimes()
                        }
                    }
                }
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
    
    // MARK: - Medication Reminder Section
    
    private var medicationReminderSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
            HStack {
                Text("Reminder Settings")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                // App is fully free - always show reminder toggle
                Toggle("Create Reminders", isOn: $createReminder)
                    .toggleStyle(SwitchToggleStyle(tint: ModernDesignSystem.Colors.primary))
                // Upgrade UI hidden - app is fully free
                // if gatekeeper.currentTier == .premium {
                // } else {
                //     ... upgrade button UI ...
                // }
            }
            
            // App is fully free - always show reminder options
            if createReminder {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
                    // Reminder Times
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        HStack {
                            Text("Reminder Times")
                                .font(ModernDesignSystem.Typography.body)
                                .fontWeight(.medium)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Spacer()
                            
                            Button("Add Time") {
                                addReminderTime()
                            }
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                            .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                            .padding(.vertical, ModernDesignSystem.Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                    .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                            )
                        }
                        
                        ForEach(reminderTimes.indices, id: \.self) { index in
                            HStack {
                                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                                    TextField("Label (e.g., Morning, Evening)", text: Binding(
                                        get: { reminderTimes[index].label },
                                        set: { updateReminderTimeLabel(at: index, newLabel: $0) }
                                    ))
                                    .font(ModernDesignSystem.Typography.body)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    
                                    DatePicker("Time", selection: Binding(
                                        get: { reminderTimes[index].timeDate },
                                        set: { updateReminderTimeDate(at: index, newDate: $0) }
                                    ), displayedComponents: [.hourAndMinute])
                                    .datePickerStyle(CompactDatePickerStyle())
                                }
                                
                                Spacer()
                                
                                Button("Remove") {
                                    removeReminderTime(at: index)
                                }
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.error)
                                .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                                .padding(.vertical, ModernDesignSystem.Spacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                        .fill(ModernDesignSystem.Colors.error.opacity(0.1))
                                )
                            }
                            .padding(ModernDesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                    .fill(ModernDesignSystem.Colors.background)
                                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                            )
                        }
                        
                        if reminderTimes.isEmpty {
                            Text("No reminder times set. Tap 'Add Time' to add one.")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .italic()
                                .padding(ModernDesignSystem.Spacing.sm)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(
                                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                        .fill(ModernDesignSystem.Colors.background)
                                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                                )
                        }
                    }
                    
                    // Start Date
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        DatePicker(
                            "Start Date",
                            selection: $startDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(CompactDatePickerStyle())
                    }
                    
                    // End Date (Optional)
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        HStack {
                            Spacer()
                            
                            Toggle("Set End Date", isOn: $hasEndDate)
                                .toggleStyle(SwitchToggleStyle(tint: ModernDesignSystem.Colors.primary))
                        }
                        
                        if hasEndDate {
                            DatePicker(
                                "End Date",
                                selection: Binding(
                                    get: { endDate ?? Date() },
                                    set: { endDate = $0 }
                                ),
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(CompactDatePickerStyle())
                        }
                    }
                }
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
    
    // MARK: - Vet Document Section
    
    private var vetDocumentSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // App is fully free - always show document picker, never show upgrade prompt
            DocumentPickerView(
                selectedDocuments: $vetDocuments,
                userId: AuthService.shared.currentUser?.id ?? "",
                petId: selectedPet?.id ?? petService.pets.first?.id ?? "",
                healthEventId: temporaryEventId // Temporary ID for folder structure
            )
            // Upgrade UI hidden - app is fully free
            // if gatekeeper.currentTier == .premium {
            // } else {
            //     ... upgrade button UI ...
            // }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialValues() {
        updateTitle()
        updateReminderTimes()
    }
    
    private func updateTitle() {
        if selectedEventType == .other {
            title = customEventName.isEmpty ? "Custom Event" : customEventName
        } else {
            title = selectedEventType.displayName
        }
    }
    
    private func updateReminderTimes() {
        reminderTimes = frequency.defaultReminderTimes
    }
    
    private func addReminderTime() {
        let newReminderTime = MedicationReminderTime(
            time: "09:00",
            label: "Reminder"
        )
        reminderTimes.append(newReminderTime)
    }
    
    private func removeReminderTime(at index: Int) {
        guard index < reminderTimes.count else { return }
        reminderTimes.remove(at: index)
    }
    
    private func updateReminderTimeLabel(at index: Int, newLabel: String) {
        guard index < reminderTimes.count else { return }
        let currentTime = reminderTimes[index]
        let updatedTime = MedicationReminderTime(
            time: currentTime.time,
            label: newLabel.isEmpty ? "Reminder" : newLabel
        )
        reminderTimes[index] = updatedTime
    }
    
    private func updateReminderTimeDate(at index: Int, newDate: Date) {
        guard index < reminderTimes.count else { return }
        let currentTime = reminderTimes[index]
        let timeString = formatTime(from: newDate)
        let updatedTime = MedicationReminderTime(
            time: timeString,
            label: currentTime.label
        )
        reminderTimes[index] = updatedTime
    }
    
    private func formatTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
        
        // Get current user ID for document uploads
        guard (AuthService.shared.currentUser?.id) != nil else {
            errorMessage = "Please log in to save health events"
            showingError = true
            return
        }
        
        isSubmitting = true
        
        Task {
            do {
                let finalTitle = selectedEventType == .other ? customEventName : title
                
                // Extract document URLs from uploaded documents (already uploaded when selected)
                // App is fully free - always allow document uploads
                var documentUrls: [String] = []
                if selectedEventType == .vetVisit {
                    documentUrls = vetDocuments.map { $0.url }
                    // Subscription check removed - app is fully free
                    // if gatekeeper.currentTier == .premium {
                    // } else if !vetDocuments.isEmpty {
                    //     errorMessage = "Document uploads require a premium subscription..."
                    //     return
                    // }
                }
                
                let healthEvent = try await healthEventService.createHealthEvent(
                    for: pet.id,
                    eventType: selectedEventType,
                    title: finalTitle,
                    notes: notes.isEmpty ? nil : notes,
                    severityLevel: severityLevel,
                    eventDate: eventDate,
                    documents: documentUrls.isEmpty ? nil : documentUrls
                )
                
                // Create medication reminder if medication event and reminder is enabled
                // App is fully free - always allow medication reminders
                if selectedEventType == .medication && createReminder && !medicationName.isEmpty && !dosage.isEmpty {
                    // Subscription check removed - app is fully free
                    // guard gatekeeper.currentTier == .premium else {
                    //     errorMessage = "Medication reminders require a premium subscription..."
                    //     return
                    // }
                    
                    let reminderService = MedicationReminderService.shared
                    _ = try await reminderService.createMedicationReminder(
                        healthEventId: healthEvent.id,
                        petId: pet.id,
                        medicationName: medicationName,
                        dosage: dosage,
                        frequency: frequency,
                        reminderTimes: reminderTimes,
                        startDate: startDate,
                        endDate: hasEndDate ? endDate : nil
                    )
                }
                
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

// MARK: - Medication Frequency Button

struct MedicationFrequencyButton: View {
    let frequency: MedicationFrequency
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text(frequency.displayName)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : ModernDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(frequency.description)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
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
