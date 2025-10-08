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
    @State private var hybridScanService = HybridScanService.shared
    @State private var scanService = ScanService.shared
    @State private var cameraPermissionService = CameraPermissionService.shared
    @State private var settingsManager = SettingsManager.shared
    @State private var showingPetSelection = false
    @State private var selectedPet: Pet?
    @State private var showingResults = false
    @State private var scanResult: Scan?
    @State private var showingPermissionAlert = false
    @State private var cameraError: String?
    @State private var showingAddPet = false
    @State private var hybridScanResult: HybridScanResult?
    @State private var showingScanOptions = false
    @State private var showingHistory = false
    @State private var detectedBarcode: BarcodeResult?
    @State private var showingBarcodeOverlay = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen camera view
                ModernCameraView(
                    onImageCaptured: processCapturedImage,
                    onBarcodeDetected: handleBarcodeDetection
                )
                .ignoresSafeArea(.all)
                
                // Scanning frame overlay following Trust & Nature design
                ScanningFrameOverlay()
                
                // Top controls with Trust & Nature styling
                VStack {
                    HStack {
                        // Title with Trust & Nature typography
                        Text("Sniff Test")
                            .font(ModernDesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        Spacer()
                        
                        // History button with Trust & Nature styling
                        Button(action: { showingHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(ModernDesignSystem.Typography.title3)
                                .foregroundColor(.white)
                                .padding(ModernDesignSystem.Spacing.md)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        
                        // Options button with Trust & Nature styling
                        Button(action: { showingScanOptions = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(ModernDesignSystem.Typography.title3)
                                .foregroundColor(.white)
                                .padding(ModernDesignSystem.Spacing.md)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    .padding(.top, ModernDesignSystem.Spacing.md)
                    
                    Spacer()
                }
                
                // Bottom results and controls with Trust & Nature design
                VStack {
                    Spacer()
                    
                    // Real-time barcode detection feedback
                    if let barcode = detectedBarcode {
                        BarcodeDetectionCard(barcode: barcode) {
                            analyzeDetectedBarcode(barcode)
                        }
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                        .padding(.bottom, ModernDesignSystem.Spacing.md)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Processing indicator with Trust & Nature colors
                    if hybridScanService.isScanning {
                        ProcessingOverlayView(progress: hybridScanService.scanProgress)
                            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                            .padding(.bottom, ModernDesignSystem.Spacing.lg)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Results section with Trust & Nature styling
                    if let result = hybridScanResult {
                        ScanResultOverlayView(
                            result: result,
                            onRetry: retryScan,
                            onAnalyze: analyzeHybridResult
                        )
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                        .padding(.bottom, ModernDesignSystem.Spacing.lg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    // Quick tips with Trust & Nature design
                    if !hybridScanService.isScanning && hybridScanResult == nil && detectedBarcode == nil {
                        QuickTipsCard {
                            // Show tips
                        }
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                        .padding(.bottom, ModernDesignSystem.Spacing.xl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingResults) {
            if let scanResult = scanResult {
                ScanResultView(scan: scanResult)
            }
        }
        .sheet(isPresented: $showingPetSelection) {
            PetSelectionView(
                onPetSelected: { pet in
                    selectedPet = pet
                    showingPetSelection = false
                    analyzeIngredients()
                },
                onAddPet: {
                    showingAddPet = true
                }
            )
        }
        .sheet(isPresented: $showingAddPet) {
            AddPetView()
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView()
        }
        .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings to use the scanning feature.")
        }
        .onChange(of: hybridScanService.scanProgress) { _, _ in
            // Handle scan progress updates
        }
        .onChange(of: hybridScanService.isScanning) { _, _ in
            // Handle scanning state updates
        }
        .onAppear {
            checkCameraPermission()
        }
    }
    
    // MARK: - Camera Permission
    
    private func checkCameraPermission() {
        cameraPermissionService.requestCameraPermission { status in
            Task { @MainActor in
                if status != .authorized {
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    // MARK: - Image Processing
    
    private func processCapturedImage(_ image: UIImage) {
        Task {
            let result = await hybridScanService.performHybridScan(from: image)
            await MainActor.run {
                hybridScanResult = result
                if let barcode = result.barcode {
                    detectedBarcode = barcode
                }
            }
        }
    }
    
    // MARK: - Barcode Detection
    
    private func handleBarcodeDetection(_ barcode: BarcodeResult) {
        withAnimation(.easeInOut(duration: 0.3)) {
            detectedBarcode = barcode
        }
        
        // Auto-analyze high confidence barcodes
        if barcode.confidence > 0.8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                analyzeDetectedBarcode(barcode)
            }
        }
    }
    
    private func analyzeDetectedBarcode(_ barcode: BarcodeResult) {
        Task {
            // Create a simple result from the detected barcode
            let result = HybridScanResult(
                barcode: barcode,
                productInfo: nil,
                ocrText: "",
                ocrAnalysis: nil,
                scanMethod: .barcodeOnly,
                confidence: barcode.confidence,
                processingTime: 0.0,
                lastCapturedImage: nil
            )
            await MainActor.run {
                hybridScanResult = result
                detectedBarcode = nil // Clear the detection card
            }
        }
    }
    
    // MARK: - Analysis
    
    private func analyzeHybridResult() {
        guard hybridScanResult != nil else { return }
        
        if petService.pets.count == 1 {
            selectedPet = petService.pets.first
            analyzeIngredients()
        } else if petService.pets.count > 1 {
            showingPetSelection = true
        } else {
            showingAddPet = true
        }
    }
    
    private func analyzeIngredients() {
        guard let result = hybridScanResult,
              let pet = selectedPet else { return }
        
        let ingredients = result.ocrText
        let manufacturerCode = result.productInfo?.manufacturerCode
        
        // Determine API scan method based on what was detected
        let apiScanMethod: ScanMethod
        if result.scanMethod == .barcodeOnly {
            apiScanMethod = .barcode  // No image needed
        } else if result.barcode != nil && !result.ocrText.isEmpty {
            apiScanMethod = .hybrid   // Both barcode and OCR - save image
        } else {
            apiScanMethod = .ocr      // OCR only - save image
        }
        
        // Convert image to base64 for OCR and hybrid scans
        var imageData: String? = nil
        if apiScanMethod.requiresImageStorage, let image = result.lastCapturedImage {
            if let jpegData = image.jpegData(compressionQuality: 0.8) {
                imageData = jpegData.base64EncodedString()
            }
        }
        
        let analysisRequest = ScanAnalysisRequest(
            petId: pet.id,
            extractedText: ingredients,
            productName: manufacturerCode,
            scanMethod: apiScanMethod,
            imageData: imageData
        )
        
        scanService.analyzeScan(analysisRequest) { scan in
            Task { @MainActor in
                scanResult = scan
                showingResults = true
            }
        }
    }
    
    // MARK: - Actions
    
    private func retryScan() {
        withAnimation(.easeInOut(duration: 0.3)) {
            hybridScanResult = nil
            detectedBarcode = nil
        }
    }
}

// MARK: - Supporting Views with Trust & Nature Design System

struct ScanningFrameOverlay: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Dark overlay with transparent scanning area
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .mask(
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                                .frame(width: 280, height: 280)
                                .blendMode(.destinationOut)
                        )
                )
            
            // Scanning frame with Trust & Nature colors
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            ModernDesignSystem.Colors.primary,
                            ModernDesignSystem.Colors.goldenYellow,
                            ModernDesignSystem.Colors.primary
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 280, height: 280)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // Corner indicators with Trust & Nature primary color
            VStack {
                HStack {
                    CornerIndicator()
                    Spacer()
                    CornerIndicator()
                        .rotationEffect(.degrees(90))
                }
                Spacer()
                HStack {
                    CornerIndicator()
                        .rotationEffect(.degrees(-90))
                    Spacer()
                    CornerIndicator()
                        .rotationEffect(.degrees(180))
                }
            }
            .frame(width: 280, height: 280)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct CornerIndicator: View {
    var body: some View {
        Rectangle()
            .fill(ModernDesignSystem.Colors.primary)
            .frame(width: 20, height: 3)
    }
}

struct BarcodeDetectionCard: View {
    let barcode: BarcodeResult
    let onAnalyze: () -> Void
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Barcode icon with Trust & Nature styling
            Image(systemName: "barcode.viewfinder")
                .font(ModernDesignSystem.Typography.title2)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .padding(ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.softCream)
                .clipShape(Circle())
            
            // Barcode info with Trust & Nature typography
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text("Barcode Detected")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Type: \(barcode.type)")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text("Confidence: \(Int(barcode.confidence * 100))%")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Analyze button with Trust & Nature primary color
            Button(action: onAnalyze) {
                Text("Analyze")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, ModernDesignSystem.Spacing.md)
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.primary)
                    .clipShape(Capsule())
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

struct ProcessingOverlayView: View {
    let progress: ScanProgress
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Progress indicator with Trust & Nature colors
            ZStack {
                Circle()
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: CGFloat(progress.progress))
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ModernDesignSystem.Colors.primary,
                                ModernDesignSystem.Colors.goldenYellow
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress.progress)
            }
            
            // Status text with Trust & Nature typography
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(progress.displayName)
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Processing your scan...")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

struct ScanResultOverlayView: View {
    let result: HybridScanResult
    let onRetry: () -> Void
    let onAnalyze: () -> Void
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Result header with Trust & Nature colors
            HStack {
                Image(systemName: result.scanMethod == .failed ? "exclamationmark.triangle" : "checkmark.circle.fill")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(result.scanMethod == .failed ? ModernDesignSystem.Colors.error : ModernDesignSystem.Colors.primary)
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(result.scanMethod == .failed ? "Scan Failed" : "Scan Complete")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("Method: \(result.scanMethod.displayName)")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Action buttons with Trust & Nature styling
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Button(action: onRetry) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .padding(.horizontal, ModernDesignSystem.Spacing.md)
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.softCream)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                    )
                }
                
                Spacer()
                
                Button(action: onAnalyze) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                        Text("Analyze")
                    }
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, ModernDesignSystem.Spacing.md)
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                    .background(ModernDesignSystem.Colors.primary)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

struct QuickTipsCard: View {
    let onTipsTap: () -> Void
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Tips icon with Trust & Nature golden yellow
            Image(systemName: "lightbulb.fill")
                .font(ModernDesignSystem.Typography.title2)
                .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
            
            // Tips text with Trust & Nature typography
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text("Quick Tips")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Point camera at barcode or ingredient list")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Chevron with Trust & Nature secondary color
            Button(action: onTipsTap) {
                Image(systemName: "chevron.right")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 4,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Scan Detection Method Extension

extension ScanDetectionMethod {
    var displayName: String {
        switch self {
        case .barcodeOnly:
            return "Barcode Scan"
        case .barcodeWithProduct:
            return "Barcode + Product"
        case .ocrOnly:
            return "Text Recognition"
        case .hybrid:
            return "Hybrid Scan"
        case .failed:
            return "Failed"
        }
    }
}

#Preview {
    ScanView()
        .environmentObject(PetService.shared)
}