//
//  ScanView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import AVFoundation

struct ScanView: View {
    @EnvironmentObject var petService: PetService
    @State private var ocrService = OCRService.shared
    @State private var scanService = ScanService.shared
    @State private var cameraPermissionService = CameraPermissionService.shared
    @State private var settingsManager = SettingsManager.shared
    @State private var showingCamera = false
    @State private var showingPetSelection = false
    @State private var selectedPet: Pet?
    @State private var showingResults = false
    @State private var scanResult: Scan?
    @State private var showingPermissionAlert = false
    @State private var cameraError: String?
    @State private var showingAddPet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.xl) {
                    // Main Content
                    if petService.pets.isEmpty && !petService.isLoading {
                        EmptyPetsStateView(onAddPet: { showingAddPet = true })
                    } else {
                        VStack(spacing: ModernDesignSystem.Spacing.xl) {
                            // Camera Section
                            CameraScanSection(
                                isProcessing: ocrService.isProcessing,
                                onScanTap: handleCameraButtonTap
                            )
                            
                            // Processing States
                            if ocrService.isProcessing {
                                ProcessingIndicatorView(
                                    message: LocalizationKeys.processingImage.localized
                                )
                            }
                            
                            if scanService.isAnalyzing {
                                ProcessingIndicatorView(
                                    message: LocalizationKeys.analyzingIngredients.localized
                                )
                            }
                            
                            // Error Display
                            if let errorMessage = ocrService.errorMessage {
                                ErrorDisplayView(
                                    message: errorMessage,
                                    onRetry: { ocrService.clearResults() }
                                )
                            }
                            
                            // Extracted Text Preview
                            if !ocrService.extractedText.isEmpty {
                                ExtractedTextSection(
                                    text: ocrService.extractedText,
                                    isAnalyzing: scanService.isAnalyzing,
                                    onAnalyze: analyzeIngredients,
                                    onCancel: { scanService.cancelAnalysis() }
                                )
                            }
                            
                            // Recent Scans
                            if !scanService.recentScans.isEmpty {
                                RecentScansSection(
                                    scans: scanService.recentScans,
                                    onScanSelected: { scan in
                                        scanResult = scan
                                        showingResults = true
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
            .background(ModernDesignSystem.Colors.softCream)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCamera) {
                CameraView(
                    cameraResolution: settingsManager.cameraResolutionPreset,
                    onImageCaptured: { image in
                        ocrService.extractText(from: image)
                    },
                    onError: { error in
                        cameraError = error
                    }
                )
            }
            .sheet(isPresented: $showingPetSelection) {
                PetSelectionView(
                    onPetSelected: { pet in
                        selectedPet = pet
                        showingCamera = true
                    },
                    onAddPet: {
                        showingAddPet = true
                    }
                )
            }
            .sheet(isPresented: $showingAddPet) {
                AddPetView()
            }
            .sheet(isPresented: $showingResults) {
                if let scan = scanResult {
                    ScanResultView(scan: scan)
                }
            }
            .onAppear {
                scanService.loadRecentScans()
            }
            .alert("Error", isPresented: .constant(scanService.errorMessage != nil)) {
                Button("OK") {
                    scanService.clearError()
                }
            } message: {
                Text(scanService.errorMessage ?? "An error occurred")
            }
            .alert("Camera Permission", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    cameraPermissionService.openAppSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(cameraPermissionService.permissionMessage)
            }
            .alert("Camera Error", isPresented: .constant(cameraError != nil)) {
                Button("OK") {
                    cameraError = nil
                }
            } message: {
                Text(cameraError ?? "An error occurred")
            }
        }
    }
    
    private func analyzeIngredients() {
        guard let pet = selectedPet ?? petService.pets.first else { 
            // Show error if no pet is available
            return 
        }
        
        _ = ocrService.processIngredients(from: ocrService.extractedText)
        
        let analysisRequest = ScanAnalysisRequest(
            petId: pet.id,
            extractedText: ocrService.extractedText,
            productName: nil
        )
        
        scanService.analyzeScan(analysisRequest) { result in
            scanResult = result
            showingResults = true
        }
    }
    
    /// Handle camera button tap with permission checking
    private func handleCameraButtonTap() {
        // Check if user has pets
        if petService.pets.isEmpty {
            showingAddPet = true
            return
        }
        
        // Check camera permission
        switch cameraPermissionService.authorizationStatus {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            cameraPermissionService.requestCameraPermission { status in
                Task { @MainActor in
                    if status == .authorized {
                        showingCamera = true
                    } else {
                        showingPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            showingPermissionAlert = true
        }
    }
}

// MARK: - Scan View Components

/**
 * Header section with title and description following Trust & Nature design
 */
struct ScanHeaderSection: View {
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.sm) {
            Text(LocalizationKeys.scanPetFood.localized)
                .font(ModernDesignSystem.Typography.largeTitle)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            
            Text(LocalizationKeys.pointCameraAtIngredients.localized)
                .font(ModernDesignSystem.Typography.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, ModernDesignSystem.Spacing.lg)
    }
}

/**
 * Empty state when no pets are available
 */
struct EmptyPetsStateView: View {
    let onAddPet: () -> Void
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Empty State Icon
            Image(systemName: "pawprint.circle")
                .font(.system(size: 80))
                .foregroundColor(ModernDesignSystem.Colors.primary.opacity(0.4))
            
            // Empty State Content
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Text("Add Your Pet First")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("To start scanning ingredient labels, you'll need to add your pet's profile first. This helps us provide personalized safety recommendations.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ModernDesignSystem.Spacing.xl)
            }
            
            // Add Pet Button
            Button(action: onAddPet) {
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Your First Pet")
                }
                .font(ModernDesignSystem.Typography.bodyEmphasized)
                .foregroundColor(ModernDesignSystem.Colors.textOnAccent)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.vertical, ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.goldenYellow)
                .cornerRadius(ModernDesignSystem.CornerRadius.large)
            }
        }
        .padding(ModernDesignSystem.Spacing.xl)
        .modernCard()
    }
}

/**
 * Modern camera scan section with enhanced visual design
 * Features: Glassmorphism, improved animations, better accessibility
 */
struct CameraScanSection: View {
    let isProcessing: Bool
    let onScanTap: () -> Void
    @State private var isPressed = false
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            // Header with modern typography
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text("Scan Pet Food")
                    .font(ModernDesignSystem.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Point your camera at the ingredient list")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            // Trust & Nature scan button
            Button(action: onScanTap) {
                ZStack {
                    // Background following Trust & Nature design
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                        .fill(ModernDesignSystem.Colors.primary)
                        .frame(width: 280, height: 280)
                        .shadow(
                            color: Color.black.opacity(0.15),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                    
                    // Pulse animation ring - Trust & Nature style
                    if !isProcessing {
                        Circle()
                            .stroke(
                                ModernDesignSystem.Colors.primary.opacity(0.2),
                                lineWidth: 2
                            )
                            .frame(width: 320, height: 320)
                            .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                            .opacity(pulseAnimation ? 0.0 : 0.4)
                            .animation(
                                .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: false),
                                value: pulseAnimation
                            )
                    }
                    
                    // Main content
                    VStack(spacing: ModernDesignSystem.Spacing.lg) {
                        // Camera icon - Trust & Nature styling
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.white)
                                .scaleEffect(isProcessing ? 0.8 : 1.0)
                                .animation(.easeInOut(duration: 0.3), value: isProcessing)
                        }
                        
                        // Action text
                        VStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Text(isProcessing ? "Processing..." : "Tap to Scan")
                                .font(ModernDesignSystem.Typography.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            if !isProcessing {
                                Text("Hold steady for best results")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
            }
            .disabled(isProcessing)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .scaleEffect(isProcessing ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPressed)
            .animation(.easeInOut(duration: 0.3), value: isProcessing)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
            .accessibilityIdentifier("cameraScanButton")
            .accessibilityLabel(isProcessing ? "Processing scan" : "Tap to scan pet food")
            .accessibilityHint("Opens camera to scan pet food ingredient labels")
            .accessibilityAddTraits(.isButton)
            
            // Quick tips section - following Trust & Nature card pattern
            if !isProcessing {
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                            .font(.system(size: 16))
                        
                        Text("Quick Tips")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                    
                    VStack(spacing: ModernDesignSystem.Spacing.xs) {
                        TipRow(icon: "camera.fill", text: "Ensure good lighting")
                        TipRow(icon: "doc.text.fill", text: "Focus on ingredient list")
                        TipRow(icon: "hand.raised.fill", text: "Hold device steady")
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
                    color: Color.black.opacity(0.1),
                    radius: 2,
                    x: 0,
                    y: 1
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            pulseAnimation = true
        }
    }
}

/**
 * Quick tip row component
 */
struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .font(.system(size: 14))
                .frame(width: 20)
            
            Text(text)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            Spacer()
        }
    }
}

/**
 * Modern processing indicator with enhanced visual design
 * Features: Animated progress, better typography, improved accessibility
 */
struct ProcessingIndicatorView: View {
    let message: String
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Animated processing icon
            ZStack {
                // Background circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ModernDesignSystem.Colors.primary.opacity(0.1),
                                ModernDesignSystem.Colors.primary.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: pulseScale
                    )
                
                // Rotating progress indicator
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ModernDesignSystem.Colors.primary,
                                ModernDesignSystem.Colors.primary.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(
                        .linear(duration: 1.0)
                        .repeatForever(autoreverses: false),
                        value: rotationAngle
                    )
                
                // Center icon
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
            }
            
            // Processing message with better typography
            VStack(spacing: ModernDesignSystem.Spacing.xs) {
                Text("Processing...")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(message)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
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
            color: Color.black.opacity(0.1),
            radius: 2,
            x: 0,
            y: 1
        )
        .transition(.opacity.combined(with: .scale))
        .animation(.easeInOut(duration: 0.3), value: message)
        .onAppear {
            rotationAngle = 360
            pulseScale = 1.1
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Processing: \(message)")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/**
 * Modern error display with enhanced visual design
 * Features: Better iconography, improved layout, enhanced accessibility
 */
struct ErrorDisplayView: View {
    let message: String
    let onRetry: () -> Void
    @State private var shakeOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Error icon with animation
            ZStack {
                Circle()
                    .fill(ModernDesignSystem.Colors.warmCoral.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    .font(.system(size: 32, weight: .medium))
                    .offset(x: shakeOffset)
                    .animation(.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true), value: shakeOffset)
            }
            
            // Error content
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text("Oops! Something went wrong")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(message)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Action buttons
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Button("Try Again", action: onRetry)
                    .modernButton(style: .error)
                
                Text("Make sure you have good lighting and the text is clear")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
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
            color: Color.black.opacity(0.1),
            radius: 2,
            x: 0,
            y: 1
        )
        .transition(.opacity.combined(with: .scale))
        .onAppear {
            shakeOffset = 5
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
        .accessibilityHint("Double tap to try again")
    }
}

/**
 * Extracted text section with analysis controls
 */
struct ExtractedTextSection: View {
    let text: String
    let isAnalyzing: Bool
    let onAnalyze: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text(LocalizationKeys.extractedText.localized)
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            
            ScrollView {
                Text(text)
                    .font(ModernDesignSystem.Typography.body)
                    .padding(ModernDesignSystem.Spacing.md)
                    .background(ModernDesignSystem.Colors.softCream)
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                            .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                    )
                    .accessibilityLabel("Extracted text from image")
            }
            .frame(maxHeight: 150)
            
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Button(LocalizationKeys.analyzeIngredients.localized, action: onAnalyze)
                    .modernButton(style: .primary)
                    .disabled(isAnalyzing)
                    .accessibilityIdentifier("analyzeIngredientsButton")
                    .accessibilityHint("Analyzes the extracted text for pet allergens")
                
                if isAnalyzing {
                    Button(LocalizationKeys.cancel.localized, action: onCancel)
                        .modernButton(style: .secondary)
                        .accessibilityIdentifier("cancelAnalysisButton")
                        .accessibilityHint("Cancels the current analysis")
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.easeInOut(duration: 0.4), value: !text.isEmpty)
    }
}

/**
 * Recent scans section with horizontal scrolling cards
 */
struct RecentScansSection: View {
    let scans: [Scan]
    let onScanSelected: (Scan) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Recent Scans")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    ForEach(scans.prefix(5)) { scan in
                        RecentScanCard(scan: scan)
                            .onTapGesture {
                                onScanSelected(scan)
                            }
                    }
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            }
        }
    }
}

/**
 * Individual recent scan card with Trust & Nature styling
 */
struct RecentScanCard: View {
    let scan: Scan
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text(scan.result?.productName ?? "Unknown Product")
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            if let result = scan.result {
                HStack {
                    Circle()
                        .fill(colorForSafety(result.overallSafety))
                        .frame(width: 8, height: 8)
                    Text(result.safetyDisplayName)
                        .font(ModernDesignSystem.Typography.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            
            Text(scan.createdAt, style: .relative)
                .font(ModernDesignSystem.Typography.caption2)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .frame(width: 140)
    }
    
    private func colorForSafety(_ safety: String) -> Color {
        switch safety {
        case "safe":
            return ModernDesignSystem.Colors.safe
        case "caution":
            return ModernDesignSystem.Colors.caution
        case "unsafe":
            return ModernDesignSystem.Colors.unsafe
        default:
            return ModernDesignSystem.Colors.textSecondary
        }
    }
}

#Preview {
    ScanView()
        .environmentObject(PetService.shared)
}

#Preview("With Mock Data") {
    let petService = PetService.shared
    // Note: Using shared instance for preview purposes
    
    ScanView()
        .environmentObject(petService)
}
