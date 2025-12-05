//
//  PetsView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/// Main view for displaying and managing user's pets
/// Follows Trust & Nature Design System for consistent styling
struct PetsView: View {
    @State private var petService = CachedPetService.shared
    @State private var showingAddPet = false
    @State private var showingEditPet: Pet?
    @State private var petToDelete: Pet?
    @State private var showingDeleteAlert = false
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if petService.isLoading {
                    ModernLoadingView(message: "Loading pets...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if petService.pets.isEmpty {
                    EmptyPetsView {
                        showingAddPet = true
                    }
                } else {
                    if #available(iOS 18.0, *) {
                        ModernScrollView {
                            LazyVStack(spacing: ModernDesignSystem.Spacing.md) {
                                ForEach(petService.pets) { pet in
                                    PetCardView(
                                        pet: pet,
                                        onEdit: {
                                            showingEditPet = pet
                                        },
                                        onDelete: {
                                            petToDelete = pet
                                            showingDeleteAlert = true
                                        }
                                    )
                                    .modernCardAnimation()
                                }
                            }
                            .padding(ModernDesignSystem.Spacing.md)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: ModernDesignSystem.Spacing.md) {
                                ForEach(petService.pets) { pet in
                                    PetCardView(
                                        pet: pet,
                                        onEdit: {
                                            showingEditPet = pet
                                        },
                                        onDelete: {
                                            petToDelete = pet
                                            showingDeleteAlert = true
                                        }
                                    )
                                    .modernCardAnimation()
                                }
                            }
                            .padding(ModernDesignSystem.Spacing.md)
                        }
                    }
                }
            }
            .navigationTitle("My Pets")
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddPet = true
                    }) {
                        Image(systemName: "plus")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                    }
                    .accessibilityLabel("Add new pet")
                    .accessibilityHint("Opens the add pet form")
                }
            }
            .sheet(isPresented: $showingAddPet) {
                AddPetView()
            }
            .sheet(item: $showingEditPet) { pet in
                EditPetView(pet: pet)
            }
            .alert("Delete Pet", isPresented: $showingDeleteAlert, presenting: petToDelete) { pet in
                Button("Cancel", role: .cancel) {
                    petToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let pet = petToDelete {
                        petService.deletePet(id: pet.id)
                        petToDelete = nil
                    }
                }
            } message: { pet in
                Text("Are you sure you want to delete \(pet.name)? This action cannot be undone.")
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
            .onAppear {
                // Track analytics
                PostHogAnalytics.trackPetsViewOpened()
                
                // Refresh pets when view appears to ensure fresh data
                // This is especially important after weight/event/food logging
                petService.loadPets(forceRefresh: false)
            }
            .refreshable {
                // Pull-to-refresh to force fresh data from server
                await MainActor.run {
                    petService.loadPets(forceRefresh: true)
                }
            }
        }
    }
}

/// Enhanced pet card view with detailed information and action buttons
/// Follows Trust & Nature Design System card patterns
struct PetCardView: View {
    let pet: Pet
    let onEdit: () -> Void
    let onDelete: () -> Void
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    @StateObject private var weightService = CachedWeightTrackingService.shared
    @State private var isExportingPDF = false
    @State private var showExportError = false
    @State private var exportErrorMessage: String?
    @State private var pdfURL: URL?
    @State private var showShareSheet = false
    
    /// Get current weight for the pet - prefers fresh weight from weight service over cached pet.weightKg
    /// This ensures we always show the most up-to-date weight
    private var currentWeight: Double? {
        // CRITICAL: Use weightService.currentWeights instead of pet.weightKg
        // pet.weightKg may be stale from cache, but currentWeights is updated immediately
        // when weight is recorded and is always fresh from the server
        return weightService.currentWeights[pet.id] ?? pet.weightKg
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero Pet Image Section - Focal Point
            ZStack(alignment: .topTrailing) {
                // Large Pet Image as focal point
                RemoteImageView(petImageUrl: pet.imageUrl, species: pet.species)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                
                // Action Buttons positioned over the image with Trust & Nature styling
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(ModernDesignSystem.Colors.textPrimary.opacity(0.8))
                            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                            .shadow(
                                color: ModernDesignSystem.Shadows.small.color,
                                radius: ModernDesignSystem.Shadows.small.radius,
                                x: ModernDesignSystem.Shadows.small.x,
                                y: ModernDesignSystem.Shadows.small.y
                            )
                    }
                    .accessibilityLabel("Edit \(pet.name)")
                    .accessibilityHint("Opens the edit pet form")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(ModernDesignSystem.Colors.warmCoral.opacity(0.9))
                            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                            .shadow(
                                color: ModernDesignSystem.Shadows.small.color,
                                radius: ModernDesignSystem.Shadows.small.radius,
                                x: ModernDesignSystem.Shadows.small.x,
                                y: ModernDesignSystem.Shadows.small.y
                            )
                    }
                    .accessibilityLabel("Delete \(pet.name)")
                    .accessibilityHint("Deletes this pet from your profile")
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            
            // Pet Name and Species with Trust & Nature colors
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(pet.name)
                    .font(ModernDesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(pet.species.displayName)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.bottom, ModernDesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Pet Details Grid with consistent spacing
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                // Breed and Age Row with Trust & Nature spacing
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    if let breed = pet.breed, !breed.isEmpty {
                        InfoPillView(
                            icon: "pawprint.fill",
                            label: "Breed",
                            value: breed
                        )
                    }
                    
                    if let ageDescription = pet.ageDescription {
                        InfoPillView(
                            icon: "calendar",
                            label: "Age",
                            value: ageDescription
                        )
                    }
                }
                
                // Weight and Allergies Row with Trust & Nature spacing
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    // CRITICAL: Use currentWeight computed property instead of pet.weightKg
                    // This ensures we always show fresh weight from weight service
                    if let weightKg = currentWeight {
                        InfoPillView(
                            icon: "scalemass.fill",
                            label: "Weight",
                            value: unitService.formatWeight(weightKg)
                        )
                    }
                    
                    if !pet.knownSensitivities.isEmpty {
                        InfoPillView(
                            icon: "exclamationmark.triangle.fill",
                            label: "Sensitivities",
                            value: "\(pet.knownSensitivities.count)",
                            isWarning: true
                        )
                    }
                }
                
                // Sensitivities List with Trust & Nature styling
                if !pet.knownSensitivities.isEmpty {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        Text("Food Sensitivities")
                            .font(ModernDesignSystem.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .textCase(.uppercase)
                        
                        PetTagFlowLayout(spacing: ModernDesignSystem.Spacing.sm) {
                            ForEach(pet.knownSensitivities, id: \.self) { sensitivity in
                                Text(sensitivity)
                                    .font(ModernDesignSystem.Typography.caption)
                                    .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                                    .background(ModernDesignSystem.Colors.warmCoral.opacity(0.1))
                                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                            }
                        }
                    }
                }
                
                // Veterinary Information with Trust & Nature styling
                if (pet.vetName != nil && !pet.vetName!.isEmpty) || (pet.vetPhone != nil && !pet.vetPhone!.isEmpty) {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        Text("Veterinary Information")
                            .font(ModernDesignSystem.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .textCase(.uppercase)
                        
                        if let vetName = pet.vetName, !vetName.isEmpty {
                            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                Image(systemName: "cross.case.fill")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                Text(vetName)
                                    .font(ModernDesignSystem.Typography.subheadline)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            }
                        }
                        
                        if let vetPhone = pet.vetPhone, !vetPhone.isEmpty {
                            if let phoneURL = URL(string: "tel://\(vetPhone.replacingOccurrences(of: " ", with: ""))") {
                                Link(destination: phoneURL) {
                                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                        Image(systemName: "phone.fill")
                                            .font(ModernDesignSystem.Typography.caption)
                                            .foregroundColor(ModernDesignSystem.Colors.primary)
                                        Text(vetPhone)
                                            .font(ModernDesignSystem.Typography.subheadline)
                                            .foregroundColor(ModernDesignSystem.Colors.primary)
                                            .underline()
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(ModernDesignSystem.Typography.caption2)
                                            .foregroundColor(ModernDesignSystem.Colors.primary)
                                    }
                                }
                                .accessibilityLabel("Call \(vetPhone)")
                                .accessibilityHint("Opens phone to call vet")
                            } else {
                                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                    Image(systemName: "phone.fill")
                                        .font(ModernDesignSystem.Typography.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    Text(vetPhone)
                                        .font(ModernDesignSystem.Typography.subheadline)
                                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                }
                            }
                        }
                    }
                }
                
                // Export for Vet Button
                Button(action: {
                    Task {
                        await exportForVet()
                    }
                }) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        if isExportingPDF {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "doc.text.fill")
                                .font(ModernDesignSystem.Typography.subheadline)
                        }
                        Text(isExportingPDF ? "Generating PDF..." : "Export for Vet")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.primary)
                    .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                }
                .disabled(isExportingPDF)
                .accessibilityLabel("Export pet data for veterinarian")
                .accessibilityHint("Generates a PDF document with pet health information")
                .sheet(isPresented: $showShareSheet) {
                    if let pdfURL = pdfURL {
                        ShareSheet(activityItems: [pdfURL])
                    }
                }
                .alert("Export Error", isPresented: $showExportError) {
                    Button("OK") { }
                } message: {
                    Text(exportErrorMessage ?? "Failed to generate PDF report")
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        // Apply Trust & Nature card styling with enhanced shadow for hero image
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                .stroke(ModernDesignSystem.Colors.borderPrimary.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.large)
        .shadow(
            color: ModernDesignSystem.Shadows.medium.color,
            radius: ModernDesignSystem.Shadows.medium.radius,
            x: ModernDesignSystem.Shadows.medium.x,
            y: ModernDesignSystem.Shadows.medium.y
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pet card for \(pet.name)")
    }
    
    /**
     * Export pet data as PDF for veterinarian
     * Aggregates all pet data and generates a professional PDF report
     */
    private func exportForVet() async {
        isExportingPDF = true
        exportErrorMessage = nil
        
        do {
            // Aggregate all pet data
            let reportData = try await PetDataAggregator.shared.aggregatePetData(for: pet)
            
            // Generate PDF
            let pdfData = try PetDataPDFService.shared.generateVetReport(data: reportData)
            
            // Save PDF to temporary file
            let fileName = "\(pet.name)_Vet_Report_\(Date().timeIntervalSince1970).pdf"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try pdfData.write(to: tempURL)
            
            // Track analytics
            PostHogAnalytics.trackPDFExported(petId: pet.id, success: true)
            
            // Present share sheet
            await MainActor.run {
                self.pdfURL = tempURL
                self.isExportingPDF = false
                self.showShareSheet = true
            }
        } catch {
            // Track analytics
            PostHogAnalytics.trackPDFExported(petId: pet.id, success: false, error: error.localizedDescription)
            
            await MainActor.run {
                self.isExportingPDF = false
                self.exportErrorMessage = error.localizedDescription
                self.showExportError = true
            }
        }
    }
}

/**
 * Share Sheet wrapper for PDF export
 * Enables sharing PDF via email, Files app, or other sharing options
 */
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Reusable info pill component for displaying pet details
/// Follows Trust & Nature Design System styling
struct InfoPillView: View {
    let icon: String
    let label: String
    let value: String
    var isWarning: Bool = false
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(ModernDesignSystem.Typography.caption2)
                .foregroundColor(isWarning ? ModernDesignSystem.Colors.warmCoral : ModernDesignSystem.Colors.primary)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs / 2) {
                Text(label)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text(value)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isWarning ? ModernDesignSystem.Colors.warmCoral : ModernDesignSystem.Colors.primary).opacity(0.08))
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
    }
}

/// Flow layout for wrapping allergy tags
struct PetTagFlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

#Preview {
    PetsView()
}
