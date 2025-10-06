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
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(LocalizationKeys.scanPetFood.localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(LocalizationKeys.pointCameraAtIngredients.localized)
                        .font(.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Show empty state if no pets
                if petService.pets.isEmpty && !petService.isLoading {
                    VStack(spacing: 24) {
                        Spacer()
                        
                        // Empty State Icon
                        Image(systemName: "pawprint.circle")
                            .font(.system(size: 80))
                            .foregroundColor(ModernDesignSystem.Colors.deepForestGreen.opacity(0.4))
                        
                        // Empty State Text
                        VStack(spacing: 12) {
                            Text("Add Your Pet First")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Text("To start scanning ingredient labels, you'll need to add your pet's profile first. This helps us provide personalized safety recommendations.")
                                .font(.body)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        // Add Pet Button
                        Button(action: {
                            showingAddPet = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Your First Pet")
                            }
                            .font(.headline)
                            .foregroundColor(ModernDesignSystem.Colors.textOnAccent)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(ModernDesignSystem.Colors.goldenYellow)
                            .cornerRadius(25)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                
                Spacer()
                
                // Camera Button
                Button(action: {
                    handleCameraButtonTap()
                }) {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                            .accessibilityHidden(true)
                            .scaleEffect(ocrService.isProcessing ? 0.9 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: ocrService.isProcessing)
                        
                        Text(LocalizationKeys.tapToScan.localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                    }
                    .frame(width: 200, height: 200)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [ModernDesignSystem.Colors.deepForestGreen, ModernDesignSystem.Colors.deepForestGreen.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: ModernDesignSystem.Colors.deepForestGreen.opacity(0.3), radius: 10, x: 0, y: 5)
                    .scaleEffect(ocrService.isProcessing ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: ocrService.isProcessing)
                }
                .disabled(ocrService.isProcessing)
                .accessibilityIdentifier("cameraScanButton")
                .accessibilityLabel(LocalizationKeys.tapToScan.localized)
                .accessibilityHint("Opens camera to scan pet food ingredient labels")
                .accessibilityAddTraits(.isButton)
                
                // Processing Indicator
                if ocrService.isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(ModernDesignSystem.Colors.deepForestGreen)
                            .accessibilityLabel("Processing")
                        Text(LocalizationKeys.processingImage.localized)
                            .font(.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, 20)
                    .accessibilityElement(children: .combine)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.3), value: ocrService.isProcessing)
                }
                
                // Analysis Loading Indicator
                if scanService.isAnalyzing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(ModernDesignSystem.Colors.deepForestGreen)
                            .accessibilityLabel("Analyzing")
                        Text(LocalizationKeys.analyzingIngredients.localized)
                            .font(.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(.top, 20)
                    .accessibilityElement(children: .combine)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.3), value: scanService.isAnalyzing)
                }
                
                // Error Display
                if let errorMessage = ocrService.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                            .font(.title2)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            ocrService.clearResults()
                        }
                        .modernButton(style: .error)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Extracted Text Preview
                if !ocrService.extractedText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizationKeys.extractedText.localized)
                            .font(.headline)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        
                        ScrollView {
                            Text(ocrService.extractedText)
                                .font(.body)
                                .padding()
                                .background(ModernDesignSystem.Colors.surfaceVariant)
                                .cornerRadius(8)
                                .accessibilityLabel("Extracted text from image")
                        }
                        .frame(maxHeight: 150)
                        
                        HStack {
                            Button(LocalizationKeys.analyzeIngredients.localized) {
                                analyzeIngredients()
                            }
                            .modernButton(style: .primary)
                            .disabled(scanService.isAnalyzing)
                            .accessibilityIdentifier("analyzeIngredientsButton")
                            .accessibilityHint("Analyzes the extracted text for pet allergens")
                            
                            if scanService.isAnalyzing {
                                Button(LocalizationKeys.cancel.localized) {
                                    scanService.cancelAnalysis()
                                }
                                .modernButton(style: .secondary)
                                .accessibilityIdentifier("cancelAnalysisButton")
                                .accessibilityHint("Cancels the current analysis")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.4), value: !ocrService.extractedText.isEmpty)
                    .onAppear {
                        // Auto-analyze if setting is enabled
                        if settingsManager.shouldAutoAnalyze && !scanService.isAnalyzing {
                            analyzeIngredients()
                        }
                    }
                }
                
                Spacer()
                
                // Recent Scans
                if !scanService.recentScans.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Scans")
                            .font(.headline)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(scanService.recentScans.prefix(5)) { scan in
                                    RecentScanCard(scan: scan)
                                        .onTapGesture {
                                            scanResult = scan
                                            showingResults = true
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                }
            }
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

struct RecentScanCard: View {
    let scan: Scan
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                Text(scan.result?.productName ?? "Unknown Product")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            if let result = scan.result {
                HStack {
                    Circle()
                        .fill(colorForSafety(result.overallSafety))
                        .frame(width: 8, height: 8)
                    Text(result.safetyDisplayName)
                        .font(.caption2)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            
            Text(scan.createdAt, style: .relative)
                .font(.caption2)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .padding(12)
        .background(ModernDesignSystem.Colors.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ModernDesignSystem.Colors.borderSecondary, lineWidth: 1)
        )
        .frame(width: 120)
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
            return ModernDesignSystem.Colors.unknown
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
