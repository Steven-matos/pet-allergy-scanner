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
                        // Header Section
                        headerSection
                        
                        // Event Details Section
                        eventDetailsSection
                        
                        // Severity Section
                        severitySection
                        
                        // Date & Time Section
                        dateTimeSection
                        
                        // Notes Section
                        notesSection
                        
                        // Documents Section (for vet visits)
                        if event.eventType == .vetVisit, let documents = event.documents, !documents.isEmpty {
                            documentsSection
                        }
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                                )
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
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                    HStack {
                        Text("Level \(editedSeverityLevel)")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(severityColor(for: editedSeverityLevel))
                        
                        Spacer()
                        
                        Text(severityDescription(for: editedSeverityLevel))
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(editedSeverityLevel) },
                        set: { editedSeverityLevel = Int($0) }
                    ), in: 1...5, step: 1)
                    .accentColor(severityColor(for: editedSeverityLevel))
                    
                    HStack {
                        ForEach(1...5, id: \.self) { level in
                            Circle()
                                .fill(level <= editedSeverityLevel ? severityColor(for: level) : ModernDesignSystem.Colors.textSecondary.opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                        Spacer()
                    }
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(severityColor(for: editedSeverityLevel).opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .stroke(severityColor(for: editedSeverityLevel), lineWidth: 1)
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
    
    // MARK: - Date & Time Section
    
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Date & Time")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if isEditing {
                DatePicker("Event Date", selection: $editedEventDate, displayedComponents: [.date, .hourAndMinute])
                    .font(ModernDesignSystem.Typography.body)
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
    
    // MARK: - Documents Section
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Vet Paperwork")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            if let documents = event.documents, !documents.isEmpty {
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    ForEach(documents, id: \.self) { documentUrl in
                        DocumentLinkView(url: documentUrl)
                    }
                }
            } else {
                Text("No documents uploaded")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .italic()
                    .padding(ModernDesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    
    // MARK: - Helper Functions
    
    private var isFormValid: Bool {
        !editedTitle.isEmpty
    }
    
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
        isSubmitting = true
        
        Task {
            do {
                let update = HealthEventUpdate(
                    title: editedTitle,
                    notes: editedNotes.isEmpty ? nil : editedNotes,
                    severityLevel: editedSeverityLevel,
                    eventDate: editedEventDate
                )
                
                _ = try await healthEventService.updateHealthEvent(event.id, updates: update)
                
                await MainActor.run {
                    isEditing = false
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSubmitting = false
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
    
    private func severityDescription(for level: Int) -> String {
        switch level {
        case 1: return "Mild"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "High"
        case 5: return "Severe"
        default:         return "Unknown"
        }
    }
}

// MARK: - Document Link View

struct DocumentLinkView: View {
    let url: String
    
    private var documentType: String {
        if url.lowercased().hasSuffix(".pdf") {
            return "PDF"
        } else if url.lowercased().contains("image") || url.lowercased().hasSuffix(".jpg") || url.lowercased().hasSuffix(".jpeg") || url.lowercased().hasSuffix(".png") {
            return "Image"
        }
        return "Document"
    }
    
    private var iconName: String {
        if documentType == "PDF" {
            return "doc.fill"
        } else {
            return "photo.fill"
        }
    }
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                            .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(documentType)
                        .font(ModernDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("Tap to view")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 20))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
            }
            .padding(ModernDesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                    .fill(ModernDesignSystem.Colors.background)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
        }
    }
}
