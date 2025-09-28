//
//  ScanView.swift
//  pet-allergy-scanner
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
    @State private var showingCamera = false
    @State private var showingPetSelection = false
    @State private var selectedPet: Pet?
    @State private var showingResults = false
    @State private var scanResult: Scan?
    @State private var showingPermissionAlert = false
    @State private var cameraError: String?
    @State private var showingAddPet = false
    
    /// Safety check for required environment objects
    private var isEnvironmentValid: Bool {
        return petService != nil
    }
    
    var body: some View {
        Group {
            if isEnvironmentValid {
                NavigationStack {
                    VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text(LocalizationKeys.scanPetFood.localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(LocalizationKeys.pointCameraAtIngredients.localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Camera Button
                Button(action: {
                    handleCameraButtonTap()
                }) {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .accessibilityHidden(true)
                            .scaleEffect(ocrService.isProcessing ? 0.9 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: ocrService.isProcessing)
                        
                        Text(LocalizationKeys.tapToScan.localized)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(width: 200, height: 200)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
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
                            .accessibilityLabel("Processing")
                        Text(LocalizationKeys.processingImage.localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                            .accessibilityLabel("Analyzing")
                        Text(LocalizationKeys.analyzingIngredients.localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                            .foregroundColor(.red)
                            .font(.title2)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            ocrService.clearResults()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Extracted Text Preview
                if !ocrService.extractedText.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizationKeys.extractedText.localized)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .accessibilityAddTraits(.isHeader)
                        
                        ScrollView {
                            Text(ocrService.extractedText)
                                .font(.body)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                                .accessibilityLabel("Extracted text from image")
                        }
                        .frame(maxHeight: 150)
                        
                        HStack {
                            Button(LocalizationKeys.analyzeIngredients.localized) {
                                analyzeIngredients()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(scanService.isAnalyzing)
                            .accessibilityIdentifier("analyzeIngredientsButton")
                            .accessibilityHint("Analyzes the extracted text for pet allergens")
                            
                            if scanService.isAnalyzing {
                                Button(LocalizationKeys.cancel.localized) {
                                    scanService.cancelAnalysis()
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("cancelAnalysisButton")
                                .accessibilityHint("Cancels the current analysis")
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.4), value: !ocrService.extractedText.isEmpty)
                }
                
                Spacer()
                
                // Recent Scans
                if !scanService.recentScans.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Scans")
                            .font(.headline)
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
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCamera) {
                CameraView(
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
            } else {
                // Fallback view when environment objects are not available
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Configuration Error")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Required services are not available. Please restart the app.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding()
            }
        }
    }
    
    private func analyzeIngredients() {
        guard let pet = selectedPet ?? petService.pets.first else { 
            // Show error if no pet is available
            return 
        }
        
        let ingredients = ocrService.processIngredients(from: ocrService.extractedText)
        
        let analysisRequest = ScanAnalysisRequest(
            petId: pet.id,
            extractedText: ocrService.extractedText,
            productName: nil
        )
        
        scanService.analyzeScan(analysisRequest) { result in
            DispatchQueue.main.async {
                scanResult = result
                showingResults = true
            }
        }
    }
    
    /// Handle camera button tap with permission checking
    private func handleCameraButtonTap() {
        // Check if user has pets
        if petService.pets.isEmpty {
            showingPetSelection = true
            return
        }
        
        // Check camera permission
        switch cameraPermissionService.authorizationStatus {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            cameraPermissionService.requestCameraPermission { status in
                if status == .authorized {
                    showingCamera = true
                } else {
                    showingPermissionAlert = true
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
                    .foregroundColor(.blue)
                Text(scan.result?.productName ?? "Unknown Product")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            if let result = scan.result {
                HStack {
                    Circle()
                        .fill(colorForSafety(result.overallSafety))
                        .frame(width: 8, height: 8)
                    Text(result.safetyDisplayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(scan.createdAt, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .frame(width: 120)
    }
    
    private func colorForSafety(_ safety: String) -> Color {
        switch safety {
        case "safe":
            return .green
        case "caution":
            return .yellow
        case "unsafe":
            return .red
        default:
            return .gray
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
    
    return ScanView()
        .environmentObject(petService)
}
