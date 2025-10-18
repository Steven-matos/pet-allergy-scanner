//
//  HealthEventDetailView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import SwiftUI

/**
 * Health Event Detail View
 * 
 * Detail view for a single health event with edit capability
 * Follows SOLID principles with single responsibility for health event details
 * Implements DRY by reusing common detail view patterns
 * Follows KISS by keeping the interface simple and focused
 */
struct HealthEventDetailView: View {
    let event: HealthEvent
    let pet: Pet
    @StateObject private var healthEventService = HealthEventService.shared
    @State private var isEditing = false
    @State private var editedTitle: String = ""
    @State private var editedNotes: String = ""
    @State private var editedSeverityLevel: Int = 1
    @State private var editedEventDate: Date = Date()
    @State private var isSubmitting = false
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                ModernDesignSystem.Colors.softCream
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: ModernDesignSystem.Spacing.lg) {
                        // Header
                        headerSection
                        
                        // Event Details
                        eventDetailsSection
                        
                        // Severity Section
                        severitySection
                        
                        // Date & Time Section
                        dateTimeSection
                        
                        // Notes Section
                        notesSection
                    }
                    .padding(ModernDesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Health Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        if isEditing {
                            Button("Cancel") {
                                cancelEditing()
                            }
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            
                            Button("Save") {
                                saveChanges()
                            }
                            .font(ModernDesignSystem.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, ModernDesignSystem.Spacing.md)
                            .padding(.vertical, ModernDesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                    .fill(ModernDesignSystem.Colors.primary)
                            )
                            .disabled(!isFormValid || isSubmitting)
                        } else {
                            Button("Edit") {
                                startEditing()
                            }
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                            
                            Button("Delete") {
                                showingDeleteAlert = true
                            }
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.error)
                        }
                    }
                }
            }
        }
        .onAppear {
            setupInitialValues()
        }
        .alert("Delete Health Event", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteHealthEvent()
            }
        } message: {
            Text("Are you sure you want to delete this health event? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Event Icon and Type
            HStack {
                Image(systemName: event.eventType.iconName)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color(hex: event.eventType.colorCode))
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(Color(hex: event.eventType.colorCode).opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(event.eventType.displayName)
                        .font(ModernDesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text(event.eventCategory.displayName)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Pet Info
            HStack {
                AsyncImage(url: URL(string: pet.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: pet.species.icon)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                )
                
                Text("For \(pet.name)")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Spacer()
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .fill(ModernDesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                )
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
        )
    }
    
    // MARK: - Event Details Section
    
    private var eventDetailsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Event Details")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                Text("Title")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                if isEditing {
                    TextField("Event title", text: $editedTitle)
                        .font(ModernDesignSystem.Typography.body)
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .fill(ModernDesignSystem.Colors.background)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                } else {
                    Text(event.title)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .padding(ModernDesignSystem.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .fill(ModernDesignSystem.Colors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .fill(ModernDesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                )
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
        )
    }
    
    // MARK: - Severity Section
    
    private var severitySection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Severity Level")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if isEditing {
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    HStack {
                        Text("Severity: \(editedSeverityLevel)")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Spacer()
                        
                        Text(severityDescription(for: editedSeverityLevel))
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(editedSeverityLevel) },
                            set: { editedSeverityLevel = Int($0) }
                        ),
                        in: 1...5,
                        step: 1
                    )
                    .accentColor(severityColor(for: editedSeverityLevel))
                    
                    HStack {
                        ForEach(1...5, id: \.self) { level in
                            Circle()
                                .fill(level <= editedSeverityLevel ? severityColor(for: level) : ModernDesignSystem.Colors.textSecondary.opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(ModernDesignSystem.Colors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                )
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text(event.severityDescription)
                            .font(ModernDesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: event.severityColor))
                        
                        Text("Level \(event.severityLevel) of 5")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        ForEach(1...5, id: \.self) { level in
                            Circle()
                                .fill(level <= event.severityLevel ? Color(hex: event.severityColor) : ModernDesignSystem.Colors.textSecondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(Color(hex: event.severityColor).opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .stroke(Color(hex: event.severityColor), lineWidth: 1)
                        )
                )
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .fill(ModernDesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                )
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
        )
    }
    
    // MARK: - Date Time Section
    
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Date & Time")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if isEditing {
                DatePicker(
                    "Event Date",
                    selection: $editedEventDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(CompactDatePickerStyle())
                .padding(ModernDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(ModernDesignSystem.Colors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                )
            } else {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(event.eventDate, style: .date)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text(event.eventDate, style: .time)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Text(event.eventDate, style: .relative)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(ModernDesignSystem.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(ModernDesignSystem.Colors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                )
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .fill(ModernDesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                )
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
        )
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Notes")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if isEditing {
                TextField("Add notes...", text: $editedNotes, axis: .vertical)
                    .font(ModernDesignSystem.Typography.body)
                    .lineLimit(3...6)
                    .padding(ModernDesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                            .fill(ModernDesignSystem.Colors.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                            )
                    )
            } else {
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .padding(ModernDesignSystem.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .fill(ModernDesignSystem.Colors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                                )
                        )
                } else {
                    Text("No notes added")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .italic()
                        .padding(ModernDesignSystem.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .fill(ModernDesignSystem.Colors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .fill(ModernDesignSystem.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                )
                .shadow(
                    color: ModernDesignSystem.Shadows.small.color,
                    radius: ModernDesignSystem.Shadows.small.radius,
                    x: ModernDesignSystem.Shadows.small.x,
                    y: ModernDesignSystem.Shadows.small.y
                )
        )
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        return !editedTitle.isEmpty
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialValues() {
        editedTitle = event.title
        editedNotes = event.notes ?? ""
        editedSeverityLevel = event.severityLevel
        editedEventDate = event.eventDate
    }
    
    private func startEditing() {
        isEditing = true
    }
    
    private func cancelEditing() {
        isEditing = false
        setupInitialValues()
    }
    
    private func saveChanges() {
        guard isFormValid else { return }
        
        isSubmitting = true
        
        let updates = HealthEventUpdate(
            title: editedTitle,
            notes: editedNotes.isEmpty ? nil : editedNotes,
            severityLevel: editedSeverityLevel,
            eventDate: editedEventDate
        )
        
        Task {
            do {
                _ = try await healthEventService.updateHealthEvent(event.id, updates: updates)
                
                await MainActor.run {
                    isSubmitting = false
                    isEditing = false
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
    
    private func deleteHealthEvent() {
        Task {
            do {
                try await healthEventService.deleteHealthEvent(event.id, petId: pet.id)
                
                await MainActor.run {
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func severityDescription(for level: Int) -> String {
        switch level {
        case 1: return "Mild"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "High"
        case 5: return "Severe"
        default: return "Unknown"
        }
    }
    
    private func severityColor(for level: Int) -> Color {
        switch level {
        case 1: return ModernDesignSystem.Colors.success // Green for mild
        case 2: return ModernDesignSystem.Colors.goldenYellow // Golden yellow for low
        case 3: return ModernDesignSystem.Colors.warmCoral // Warm coral for moderate
        case 4: return ModernDesignSystem.Colors.error // Red for high
        case 5: return Color(hex: "#8E44AD") // Purple for severe
        default: return ModernDesignSystem.Colors.textSecondary
        }
    }
}

#Preview {
    HealthEventDetailView(
        event: HealthEvent(
            id: "preview-event",
            petId: "preview-pet",
            userId: "preview-user",
            eventType: .vomiting,
            eventCategory: .digestive,
            title: "Morning vomiting episode",
            notes: "Vomited after breakfast, seemed fine afterwards",
            severityLevel: 2,
            eventDate: Date(),
            createdAt: Date(),
            updatedAt: Date()
        ),
        pet: Pet(
            id: "preview-pet",
            userId: "preview-user",
            name: "Buddy",
            species: .dog,
            breed: "Golden Retriever",
            birthday: Date(),
            weightKg: 25.0,
            activityLevel: .moderate,
            imageUrl: nil,
            knownSensitivities: [],
            vetName: nil,
            vetPhone: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    )
}
