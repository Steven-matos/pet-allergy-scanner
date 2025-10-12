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
    @State private var tempOCRText: String? = nil  // Store OCR text for multi-pet selection
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
    
    // New states for enhanced workflow
    @State private var capturedBarcode: String? = nil  // Store barcode from first scan
    @State private var showingProductFound = false
    @State private var showingProductNotFound = false
    @State private var showingNutritionalLabelScan = false
    @State private var foundProduct: FoodProduct?
    @State private var isAnalyzing = false  // Track analysis in progress
    
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
                            capturedBarcode: capturedBarcode,  // Pass captured barcode from first scan
                            onRetry: retryScan,
                            onAnalyze: { ocrText in
                                // Use the potentially edited OCR text
                                analyzeWithText(ocrText)
                            }
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
                    
                    // Loading overlay when analyzing
                    if isAnalyzing {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                        
                        VStack(spacing: ModernDesignSystem.Spacing.md) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(ModernDesignSystem.Colors.goldenYellow)
                            
                            Text("Analyzing ingredients...")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        }
                        .padding(ModernDesignSystem.Spacing.xl)
                        .background(ModernDesignSystem.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.large))
                        .shadow(color: Color.black.opacity(0.3), radius: 20)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingResults) {
            if let scanResult = scanResult {
                ScanResultView(scan: scanResult, barcode: capturedBarcode)
            }
        }
        .sheet(isPresented: $showingPetSelection) {
            PetSelectionView(
                onPetSelected: { pet in
                    selectedPet = pet
                    showingPetSelection = false
                    // Use stored OCR text if available, otherwise use original
                    if let ocrText = tempOCRText {
                        analyzeIngredientsWithText(ocrText)
                        tempOCRText = nil  // Clear after use
                    } else if let result = hybridScanResult {
                        analyzeIngredientsWithText(result.ocrText)
                    }
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
        .sheet(isPresented: $showingProductFound) {
            if let product = foundProduct {
                ProductFoundView(
                    product: product,
                    onAnalyzeForPet: {
                        showingProductFound = false
                        // Convert product to scan result for analysis
                        analyzeProductForPet(product)
                    },
                    onCancel: {
                        showingProductFound = false
                        foundProduct = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showingProductNotFound) {
            ProductNotFoundView(
                barcode: capturedBarcode ?? "",  // Use captured barcode from first scan
                onScanNutritionalLabel: {
                    showingProductNotFound = false
                    showingNutritionalLabelScan = true
                    // Keep capturedBarcode for next scan
                },
                onRetry: {
                    showingProductNotFound = false
                    capturedBarcode = nil  // Clear captured barcode on retry
                    retryScan()
                },
                onCancel: {
                    showingProductNotFound = false
                    detectedBarcode = nil
                    capturedBarcode = nil  // Clear captured barcode on cancel
                }
            )
        }
        .fullScreenCover(isPresented: $showingNutritionalLabelScan) {
            NutritionalLabelScanView(
                barcode: detectedBarcode?.value,
                onImageCaptured: { image in
                    showingNutritionalLabelScan = false
                    processNutritionalLabelImage(image)
                },
                onCancel: {
                    showingNutritionalLabelScan = false
                }
            )
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
        // Store barcode value for later use with nutritional scan
        capturedBarcode = barcode.value
        
        Task {
            // Look up product in database
            do {
                let product = try await APIService.shared.lookupProductByBarcode(barcode.value)
                
                await MainActor.run {
                    if let product = product {
                        // Product found in database
                        foundProduct = product
                        showingProductFound = true
                        detectedBarcode = nil
                    } else {
                        // Product not found - prompt for nutritional label scan
                        // Barcode is stored in capturedBarcode for next scan
                        showingProductNotFound = true
                        detectedBarcode = nil
                    }
                }
            } catch {
                // Error looking up product
                print("Error looking up product: \(error.localizedDescription)")
                await MainActor.run {
                    // Still store barcode for nutritional scan
                    showingProductNotFound = true
                    detectedBarcode = nil
                }
            }
        }
    }
    
    // MARK: - Analysis
    
    /**
     * Analyze scan with potentially edited OCR text
     * This is called when user clicks "Analyze" button in the scan result overlay
     */
    private func analyzeWithText(_ ocrText: String) {
        guard hybridScanResult != nil else { return }
        
        if petService.pets.count == 1 {
            selectedPet = petService.pets.first
            // Dismiss overlay before analyzing
            withAnimation(.easeInOut(duration: 0.3)) {
                hybridScanResult = nil
            }
            analyzeIngredientsWithText(ocrText)
        } else if petService.pets.count > 1 {
            // Store the OCR text for later use after pet selection
            tempOCRText = ocrText
            // Dismiss overlay before showing pet selection
            withAnimation(.easeInOut(duration: 0.3)) {
                hybridScanResult = nil
            }
            showingPetSelection = true
        } else {
            // Dismiss overlay before showing add pet
            withAnimation(.easeInOut(duration: 0.3)) {
                hybridScanResult = nil
            }
            showingAddPet = true
        }
    }
    
    private func analyzeHybridResult() {
        guard let result = hybridScanResult else { return }
        // Use original OCR text when auto-analyzing
        analyzeWithText(result.ocrText)
    }
    
    private func analyzeIngredientsWithText(_ ocrText: String) {
        guard let result = hybridScanResult,
              let pet = selectedPet else { return }
        
        // Show loading state
        isAnalyzing = true
        
        let ingredients = ocrText  // Use provided OCR text (potentially edited)
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
        
        // Use captured barcode if available, otherwise try to get from result
        let barcodeValue = capturedBarcode ?? result.barcode?.value
        
        let analysisRequest = ScanAnalysisRequest(
            petId: pet.id,
            extractedText: ingredients,
            productName: manufacturerCode,
            barcode: barcodeValue,  // Use captured barcode from first scan
            scanMethod: apiScanMethod,
            imageData: imageData
        )
        
        scanService.analyzeScan(analysisRequest) { scan in
            Task { @MainActor in
                isAnalyzing = false  // Hide loading state
                scanResult = scan
                showingResults = true
                capturedBarcode = nil  // Clear after successful analysis
            }
        }
    }
    
    // MARK: - Actions
    
    private func retryScan() {
        withAnimation(.easeInOut(duration: 0.3)) {
            hybridScanResult = nil
            detectedBarcode = nil
            showingProductFound = false
            showingProductNotFound = false
            foundProduct = nil
            capturedBarcode = nil  // Clear captured barcode on retry
        }
    }
    
    /**
     * Process nutritional label image captured manually
     */
    private func processNutritionalLabelImage(_ image: UIImage) {
        Task {
            // Use OCR-only scan for nutritional label
            let result = await hybridScanService.performOCROnlyScan(from: image)
            await MainActor.run {
                hybridScanResult = result
            }
        }
    }
    
    /**
     * Analyze product from database for pet safety
     */
    private func analyzeProductForPet(_ product: FoodProduct) {
        // Select pet first
        if petService.pets.count == 1 {
            selectedPet = petService.pets.first
            analyzeProductIngredients(product)
        } else if petService.pets.count > 1 {
            showingPetSelection = true
        } else {
            showingAddPet = true
        }
    }
    
    /**
     * Analyze product ingredients for selected pet
     */
    private func analyzeProductIngredients(_ product: FoodProduct) {
        guard let pet = selectedPet else { return }
        
        // Get ingredients from product
        let ingredientsText = product.nutritionalInfo?.ingredients.joined(separator: ", ") ?? ""
        
        // Create analysis request with product info
        let analysisRequest = ScanAnalysisRequest(
            petId: pet.id,
            extractedText: ingredientsText,
            productName: product.name,
            barcode: product.barcode,  // Include product barcode for linking
            scanMethod: .barcode,  // Product from barcode scan
            imageData: nil  // No image needed for database products
        )
        
        scanService.analyzeScan(analysisRequest) { scan in
            Task { @MainActor in
                scanResult = scan
                showingResults = true
                foundProduct = nil
                capturedBarcode = nil  // Clear after successful analysis
            }
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
    let capturedBarcode: String?  // Barcode from previous scan
    let onRetry: () -> Void
    let onAnalyze: (String) -> Void  // Now passes the current OCR text
    @State private var showingRawText = false
    @State private var showingNutritionalData = true
    @State private var showingIngredients = true
    @State private var showingEditSheet = false
    @State private var editedOCRText: String = ""
    @State private var isUsingEditedText = false
    @State private var showingEditBrandSheet = false
    @State private var editedBrand: String = ""
    @State private var isUsingEditedBrand = false
    
    // Get the current text (edited or original)
    private var currentOCRText: String {
        isUsingEditedText ? editedOCRText : result.ocrText
    }
    
    // Parse ingredients from current OCR text
    private var extractedIngredients: [String] {
        OCRService.shared.processIngredients(from: currentOCRText)
    }
    
    // Parse nutritional data from current OCR text
    private var extractedNutritionalData: NutritionalAnalysis {
        OCRService.shared.extractNutritionalInfo(from: currentOCRText)
    }
    
    // Extract brand from current OCR text or use edited brand
    private var extractedBrand: String? {
        if isUsingEditedBrand {
            return editedBrand.isEmpty ? nil : editedBrand
        }
        return OCRService.shared.extractBrand(from: currentOCRText)
    }
    
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
            
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    
                    // Barcode info - prominent display
                    // Show captured barcode from previous scan, or detected barcode from current scan
                    if let captured = capturedBarcode {
                        // Show captured barcode with a badge
                        VStack(spacing: ModernDesignSystem.Spacing.xs) {
                            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.safe)
                                Text("Barcode from previous scan")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                            BarcodeInfoCard(barcode: BarcodeResult(
                                value: captured,
                                type: "SAVED",
                                confidence: 1.0,
                                timestamp: Date()
                            ))
                        }
                    } else if let barcode = result.barcode {
                        BarcodeInfoCard(barcode: barcode)
                    }
                    
                    // Brand Section - Editable
                    EditableBrandCard(
                        brand: extractedBrand,
                        isEdited: isUsingEditedBrand,
                        onEdit: {
                            // Initialize with current brand or empty
                            if !isUsingEditedBrand {
                                editedBrand = extractedBrand ?? ""
                            }
                            showingEditBrandSheet = true
                        },
                        onAdd: {
                            // Initialize empty for adding new brand
                            editedBrand = ""
                            showingEditBrandSheet = true
                        }
                    )
                    
                    // Extracted Ingredients Section
                    if !extractedIngredients.isEmpty {
                        IngredientsPreviewCard(
                            ingredients: extractedIngredients,
                            isExpanded: $showingIngredients
                        )
                    }
                    
                    // Nutritional Data Section
                    NutritionalDataPreviewCard(
                        analysis: extractedNutritionalData,
                        isExpanded: $showingNutritionalData
                    )
                    
                    // Edit OCR Text Option
                    Button(action: {
                        if !isUsingEditedText {
                            editedOCRText = result.ocrText
                        }
                        showingEditSheet = true
                    }) {
                        HStack(spacing: ModernDesignSystem.Spacing.sm) {
                            Image(systemName: "pencil.circle")
                                .font(ModernDesignSystem.Typography.body)
                            
                            Text(isUsingEditedText ? "Text Edited - Tap to Review" : "Edit OCR Text")
                                .font(ModernDesignSystem.Typography.caption)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(ModernDesignSystem.Typography.caption)
                        }
                        .foregroundColor(isUsingEditedText ? ModernDesignSystem.Colors.goldenYellow : ModernDesignSystem.Colors.primary)
                        .padding(ModernDesignSystem.Spacing.sm)
                        .background(isUsingEditedText ? ModernDesignSystem.Colors.goldenYellow.opacity(0.1) : ModernDesignSystem.Colors.primary.opacity(0.05))
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Raw OCR Text (collapsible, at bottom)
                    if !result.ocrText.isEmpty {
                        RawTextPreviewCard(
                            text: currentOCRText,
                            isExpanded: $showingRawText
                        )
                    }
                }
            }
            .frame(maxHeight: 400)
            
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
                
                Button(action: {
                    // Pass the current OCR text (edited or original)
                    onAnalyze(currentOCRText)
                }) {
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
        .sheet(isPresented: $showingEditSheet) {
            EditOCRTextSheet(
                originalText: result.ocrText,
                editedText: $editedOCRText,
                isUsingEditedText: $isUsingEditedText
            )
        }
        .sheet(isPresented: $showingEditBrandSheet) {
            EditBrandSheet(
                originalBrand: OCRService.shared.extractBrand(from: result.ocrText),
                editedBrand: $editedBrand,
                isUsingEditedBrand: $isUsingEditedBrand
            )
        }
    }
}

/**
 * Edit OCR Text Sheet - Allows users to manually correct OCR errors
 */
struct EditOCRTextSheet: View {
    let originalText: String
    @Binding var editedText: String
    @Binding var isUsingEditedText: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Instructions
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        Text("Fix OCR Errors")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                    
                    Text("Edit the text below to fix any OCR misreads. The ingredients and nutritional data will be re-parsed automatically.")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                .padding(.top, ModernDesignSystem.Spacing.sm)
                
                // Text Editor
                TextEditor(text: $editedText)
                    .font(ModernDesignSystem.Typography.body)
                    .padding(ModernDesignSystem.Spacing.sm)
                    .background(Color.white)
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                            .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                    )
                    .padding(.horizontal, ModernDesignSystem.Spacing.md)
                
                // Action Buttons
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    // Reset button
                    Button(action: {
                        editedText = originalText
                    }) {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(ModernDesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.softCream)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                    
                    // Apply button
                    Button(action: {
                        isUsingEditedText = true
                        dismiss()
                    }) {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Apply Changes")
                        }
                        .font(ModernDesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.primary)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    }
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                .padding(.bottom, ModernDesignSystem.Spacing.md)
            }
            .navigationTitle("Edit OCR Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/**
 * Edit Brand Sheet - Allows users to manually edit or add brand name
 */
struct EditBrandSheet: View {
    let originalBrand: String?
    @Binding var editedBrand: String
    @Binding var isUsingEditedBrand: Bool
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Instructions
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "tag.fill")
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        Text("Edit Brand Name")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                    
                    Text("Enter or correct the brand name for this product. This will help with product identification and database contributions.")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                .padding(.top, ModernDesignSystem.Spacing.sm)
                
                // Text Field
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Brand Name")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                    
                    TextField("e.g., Purina, Blue Buffalo, Hill's", text: $editedBrand)
                        .font(ModernDesignSystem.Typography.body)
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(Color.white)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(isFocused ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.borderPrimary, lineWidth: isFocused ? 2 : 1)
                        )
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .focused($isFocused)
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    // Reset button
                    Button(action: {
                        if let original = originalBrand {
                            editedBrand = original
                        } else {
                            editedBrand = ""
                        }
                    }) {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(ModernDesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.softCream)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                    
                    // Clear button (remove brand)
                    Button(action: {
                        editedBrand = ""
                        isUsingEditedBrand = false
                        dismiss()
                    }) {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "xmark.circle")
                            Text("Remove")
                        }
                        .font(ModernDesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.error)
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.error.opacity(0.1))
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    }
                    
                    // Save button
                    Button(action: {
                        isUsingEditedBrand = !editedBrand.isEmpty
                        dismiss()
                    }) {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save")
                        }
                        .font(ModernDesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.primary)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    }
                    .disabled(editedBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(editedBrand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                .padding(.bottom, ModernDesignSystem.Spacing.md)
            }
            .navigationTitle("Brand Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

/**
 * Editable Brand Card - Shows brand with edit button
 */
struct EditableBrandCard: View {
    let brand: String?
    let isEdited: Bool
    let onEdit: () -> Void
    let onAdd: () -> Void
    
    var body: some View {
        if let brand = brand {
            // Brand detected - show with edit option
            Button(action: onEdit) {
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    // Brand icon
                    Image(systemName: "tag.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Brand")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            
                            if isEdited {
                                Image(systemName: "pencil.circle.fill")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                            }
                        }
                        
                        Text(brand)
                            .font(ModernDesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "pencil.circle")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(isEdited ? ModernDesignSystem.Colors.goldenYellow.opacity(0.08) : ModernDesignSystem.Colors.primary.opacity(0.08))
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(isEdited ? ModernDesignSystem.Colors.goldenYellow.opacity(0.3) : ModernDesignSystem.Colors.primary.opacity(0.2), lineWidth: 1.5)
                )
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            // No brand detected - show add option
            Button(action: onAdd) {
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ModernDesignSystem.Colors.primary.opacity(0.6))
                    
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Brand")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Text("Add Brand Name")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.primary.opacity(0.03))
                .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(ModernDesignSystem.Colors.borderPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
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

// MARK: - Scan Result Preview Cards

/**
 * Barcode Info Card - Prominent barcode display
 */
struct BarcodeInfoCard: View {
    let barcode: BarcodeResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "barcode.viewfinder")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                
                Text("Barcode Detected")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            // Barcode value
            HStack {
                Text(barcode.value)
                    .font(ModernDesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                
                Spacer()
                
                // Confidence indicator
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(confidenceColor)
                    
                    Text("\(Int(barcode.confidence * 100))%")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            
            Text("Type: \(barcode.type)")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.goldenYellow.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.goldenYellow.opacity(0.3), lineWidth: 2)
        )
    }
    
    private var confidenceColor: Color {
        if barcode.confidence > 0.8 {
            return ModernDesignSystem.Colors.safe
        } else if barcode.confidence > 0.6 {
            return ModernDesignSystem.Colors.goldenYellow
        } else {
            return ModernDesignSystem.Colors.error
        }
    }
}

/**
 * Brand Info Card - Shows detected brand name
 */
struct BrandInfoCard: View {
    let brand: String
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Brand icon
            Image(systemName: "tag.fill")
                .font(.system(size: 24))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text("Brand")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text(brand)
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.primary.opacity(0.08))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.primary.opacity(0.2), lineWidth: 1.5)
        )
    }
}

/**
 * Ingredients Preview Card - Shows extracted ingredients list
 */
struct IngredientsPreviewCard: View {
    let ingredients: [String]
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "list.bullet")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    Text("Ingredients Found")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(ingredients.count) items")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        ForEach(Array(ingredients.prefix(20).enumerated()), id: \.offset) { index, ingredient in
                            HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                                Text("\(index + 1).")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    .frame(width: 24, alignment: .trailing)
                                
                                Text(ingredient)
                                    .font(ModernDesignSystem.Typography.body)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                
                                Spacer()
                            }
                        }
                        
                        if ingredients.count > 20 {
                            Text("... and \(ingredients.count - 20) more")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .padding(.leading, 32)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
}

/**
 * Nutritional Data Preview Card - Shows parsed nutritional values
 */
struct NutritionalDataPreviewCard: View {
    let analysis: NutritionalAnalysis
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    
                    Text("Nutritional Data")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(dataFieldCount) fields")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    // Calories - show both if available
                    if let caloriesPer100g = analysis.caloriesPer100G {
                        NutritionalValueRow(
                            label: "Calories (per 100g)",
                            value: "\(Int(caloriesPer100g))",
                            unit: "kcal"
                        )
                    }
                    
                    if let caloriesPerServing = analysis.caloriesPerServing {
                        // Determine label based on calorie amount
                        // Small values (< 50) are typically per treat
                        let label = caloriesPerServing < 50 ? "Calories (per treat)" : "Calories (per serving)"
                        NutritionalValueRow(
                            label: label,
                            value: "\(Int(caloriesPerServing))",
                            unit: "kcal"
                        )
                    }
                    
                    // Protein
                    if let protein = analysis.proteinPercent {
                        NutritionalValueRow(
                            label: "Protein",
                            value: String(format: "%.1f", protein),
                            unit: "%"
                        )
                    }
                    
                    // Fat
                    if let fat = analysis.fatPercent {
                        NutritionalValueRow(
                            label: "Fat",
                            value: String(format: "%.1f", fat),
                            unit: "%"
                        )
                    }
                    
                    // Fiber
                    if let fiber = analysis.fiberPercent {
                        NutritionalValueRow(
                            label: "Fiber",
                            value: String(format: "%.1f", fiber),
                            unit: "%"
                        )
                    }
                    
                    // Moisture
                    if let moisture = analysis.moisturePercent {
                        NutritionalValueRow(
                            label: "Moisture",
                            value: String(format: "%.1f", moisture),
                            unit: "%"
                        )
                    }
                    
                    // Ash
                    if let ash = analysis.ashPercent {
                        NutritionalValueRow(
                            label: "Ash",
                            value: String(format: "%.1f", ash),
                            unit: "%"
                        )
                    }
                    
                    // Calcium
                    if let calcium = analysis.calciumPercent {
                        NutritionalValueRow(
                            label: "Calcium",
                            value: String(format: "%.2f", calcium),
                            unit: "%"
                        )
                    }
                    
                    // Phosphorus
                    if let phosphorus = analysis.phosphorusPercent {
                        NutritionalValueRow(
                            label: "Phosphorus",
                            value: String(format: "%.2f", phosphorus),
                            unit: "%"
                        )
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
    
    private var dataFieldCount: Int {
        var count = 0
        // Count both calorie fields separately if present
        if analysis.caloriesPer100G != nil { count += 1 }
        if analysis.caloriesPerServing != nil { count += 1 }
        if analysis.proteinPercent != nil { count += 1 }
        if analysis.fatPercent != nil { count += 1 }
        if analysis.fiberPercent != nil { count += 1 }
        if analysis.moisturePercent != nil { count += 1 }
        if analysis.ashPercent != nil { count += 1 }
        if analysis.calciumPercent != nil { count += 1 }
        if analysis.phosphorusPercent != nil { count += 1 }
        return count
    }
}

/**
 * Nutritional Value Row - Individual nutrient display
 */
struct NutritionalValueRow: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Spacer()
            
            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                Text(value)
                    .font(ModernDesignSystem.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                
                Text(unit)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
        .padding(.vertical, ModernDesignSystem.Spacing.xs)
    }
}

/**
 * Raw Text Preview Card - Collapsible raw OCR text for reference
 */
struct RawTextPreviewCard: View {
    let text: String
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: "text.viewfinder")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Text("Raw OCR Text")
                        .font(ModernDesignSystem.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text("For Reference")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                
                ScrollView {
                    Text(text)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
            }
        }
        .padding(ModernDesignSystem.Spacing.sm)
        .background(ModernDesignSystem.Colors.primary.opacity(0.05))
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                .stroke(ModernDesignSystem.Colors.borderPrimary.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    ScanView()
        .environmentObject(PetService.shared)
}