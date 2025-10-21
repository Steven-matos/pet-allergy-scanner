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
    // MEMORY OPTIMIZATION: Use shared service instances instead of @State
    private let hybridScanService = HybridScanService.shared
    private let scanService = ScanService.shared
    private let cameraPermissionService = CameraPermissionService.shared
    private let settingsManager = SettingsManager.shared
    @State private var showingPetSelection = false
    @State private var selectedPet: Pet?
    @State private var showingResults = false
    @State private var scanResult: Scan?
    @State private var showingPermissionAlert = false
    @State private var cameraError: String?
    @State private var showingAddPet = false
    @State private var hybridScanResult: HybridScanResult?
    @State private var showingHistory = false
    @State private var detectedBarcode: BarcodeResult?
    @State private var showingBarcodeOverlay = false
    
    // New states for enhanced workflow
    @State private var showingProductFound = false
    @State private var showingProductNotFound = false
    @State private var showingNutritionalLabelScan = false
    @State private var showingOCRResults = false
    @State private var foundProduct: FoodProduct?
    
    // Toast state
    @State private var showingSuccessToast = false
    @State private var showingErrorToast = false
    @State private var successMessage = ""
    @State private var errorMessage = ""
    
    // Camera control state
    @State private var cameraController: ModernCameraViewController?
    @State private var isCameraPaused = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-screen camera view
                ModernCameraView(
                    onImageCaptured: processCapturedImage,
                    onBarcodeDetected: handleBarcodeDetection,
                    onCameraControllerReady: { controller in
                        cameraController = controller
                    }
                )
                .ignoresSafeArea(.all)
                
                // Scanning frame overlay following Trust & Nature design
                ScanningFrameOverlay()
                
                // Top controls with Trust & Nature styling
                VStack {
                    ZStack {
                        // Centered app name
                        Text("Sniff Test")
                            .font(ModernDesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        // History button positioned on the right
                        HStack {
                            Spacer()
                            
                            Button(action: { showingHistory = true }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(ModernDesignSystem.Typography.title3)
                                    .foregroundColor(.white)
                                    .padding(ModernDesignSystem.Spacing.md)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
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
                        BarcodeDetectionCard(
                            barcode: barcode,
                            onAnalyze: {
                                analyzeDetectedBarcode(barcode)
                            },
                            onRescan: {
                                resumeCameraForRescan()
                            }
                        )
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                        .padding(.bottom, ModernDesignSystem.Spacing.md)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            // Auto-close barcode detection card after 8 seconds if user doesn't interact
                            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    // Don't clear detectedBarcode if we're in nutritional label flow, product not found flow, OR product found flow
                                    if !showingNutritionalLabelScan && !showingProductNotFound && !showingProductFound {
                                        detectedBarcode = nil
                                    }
                                }
                            }
                        }
                        .onDisappear {
                            // Reset barcode processing state when card is dismissed
                            // This allows the camera to detect new barcodes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                // Small delay to ensure the card animation completes
                            }
                        }
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
                        .onAppear {
                            // Auto-close scan complete popup after 5 seconds if user doesn't interact
                            if result.scanMethod != .failed {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        // Don't clear results if we're in nutritional label flow, product not found flow, OCR results flow, OR product found flow
                                        if !showingNutritionalLabelScan && !showingProductNotFound && !showingOCRResults && !showingProductFound {
                                            hybridScanResult = nil
                                            detectedBarcode = nil
                                        }
                                    }
                                }
                            }
                        }
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
            
            // Toast overlays
            if showingSuccessToast {
                VStack {
                    Spacer()
                    
                    SuccessToastView(
                        message: successMessage,
                        isVisible: $showingSuccessToast
                    )
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    .padding(.bottom, ModernDesignSystem.Spacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            if showingErrorToast {
                VStack {
                    Spacer()
                    
                    ErrorToastView(
                        message: errorMessage,
                        isVisible: $showingErrorToast
                    )
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    .padding(.bottom, ModernDesignSystem.Spacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
            .onAppear {
                stopCameraForSheetPresentation()
            }
            .onDisappear {
                resumeCameraScanning()
            }
        }
        .sheet(isPresented: $showingAddPet) {
            AddPetView()
                .onAppear {
                    stopCameraForSheetPresentation()
                }
                .onDisappear {
                    resumeCameraScanning()
                }
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView()
                .onAppear {
                    stopCameraForSheetPresentation()
                }
                .onDisappear {
                    resumeCameraScanning()
                }
        }
        .sheet(isPresented: $showingProductFound) {
            if let product = foundProduct {
                ProductFoundView(
                    product: product,
                    onAnalyzeForPet: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingProductFound = false
                        }
                        
                        // Convert product to scan result for analysis
                        analyzeProductForPet(product)
                    },
                    onCancel: {
                        showingProductFound = false
                        foundProduct = nil
                    }
                )
                .onAppear {
                    stopCameraForSheetPresentation()
                }
                .onDisappear {
                    resumeCameraScanning()
                }
            } else {
                // Return an empty view when no product is available
                EmptyView()
                    .onAppear {
                        print("🔍 [SHEET_EVENTS] ❌ No foundProduct available for ProductFoundView sheet")
                    }
            }
        }
        .sheet(isPresented: $showingProductNotFound) {
            ProductNotFoundView(
                barcode: detectedBarcode?.value ?? "",
                onScanNutritionalLabel: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingProductNotFound = false
                    }
                    
                    // Resume camera for nutritional label scanning
                    resumeCameraForNutritionalLabelScan()
                    showingNutritionalLabelScan = true
                },
                onRetry: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingProductNotFound = false
                    }
                    retryScan()
                },
                onCancel: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingProductNotFound = false
                        detectedBarcode = nil
                    }
                }
            )
            .onAppear {
                stopCameraForSheetPresentation()
            }
            .onDisappear {
                // Camera will be resumed when user chooses to scan nutritional label
                // This prevents premature camera resume while user is reviewing options
            }
        }
        .fullScreenCover(isPresented: $showingNutritionalLabelScan) {
            NutritionalLabelScanView(
                barcode: detectedBarcode?.value,
                onImageCaptured: { image in
                    print("🔍 [NUTRITIONAL_LABEL_SCAN] Image captured, processing...")
                    print("🔍 [NUTRITIONAL_LABEL_SCAN] Current detectedBarcode: \(detectedBarcode?.value ?? "NIL")")
                    print("🔍 [NUTRITIONAL_LABEL_SCAN] Image size: \(image.size)")
                    
                    showingNutritionalLabelScan = false
                    print("🔍 [NUTRITIONAL_LABEL_SCAN] showingNutritionalLabelScan set to false")
                    
                    // Don't stop camera here - let the result sheet handle it
                    // This prevents duplicate camera stops that cause blank sheets
                    processNutritionalLabelImage(image)
                },
                onCancel: {
                    print("🔍 [NUTRITIONAL_LABEL_SCAN] User cancelled nutritional label scan")
                    print("🔍 [NUTRITIONAL_LABEL_SCAN] Current detectedBarcode: \(detectedBarcode?.value ?? "NIL")")
                    
                    showingNutritionalLabelScan = false
                    print("🔍 [NUTRITIONAL_LABEL_SCAN] showingNutritionalLabelScan set to false")
                    
                    // Resume camera when canceling nutritional label scan
                    resumeCameraForNutritionalLabelScan()
                }
            )
            .onAppear {
                print("🔍 [NUTRITIONAL_LABEL_SCAN] NutritionalLabelScanView appeared")
                print("🔍 [NUTRITIONAL_LABEL_SCAN] Barcode passed to view: \(detectedBarcode?.value ?? "NIL")")
                print("🔍 [NUTRITIONAL_LABEL_SCAN] Current UI state - showingNutritionalLabelScan: \(showingNutritionalLabelScan)")
                pauseCameraScanning()
            }
            .onDisappear {
                print("🔍 [NUTRITIONAL_LABEL_SCAN] NutritionalLabelScanView disappeared")
                // Don't resume camera here - it will be handled by the onImageCaptured callback
            }
        }
        .sheet(isPresented: $showingOCRResults) {
            if let result = hybridScanResult {
                NutritionalLabelResultView(
                    result: result,
                    onAnalyzeForPet: {
                        print("🔍 [OCR_RESULTS] User chose to analyze for pet")
                        print("🔍 [OCR_RESULTS] Current result barcode: \(result.barcode?.value ?? "NIL")")
                        print("🔍 [OCR_RESULTS] Current detectedBarcode: \(detectedBarcode?.value ?? "NIL")")
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingOCRResults = false
                        }
                        print("🔍 [OCR_RESULTS] showingOCRResults set to false")
                        
                        // Resume camera for continued scanning after analysis
                        resumeCameraScanning()
                        analyzeHybridResult()
                    },
                    onUploadToDatabase: { productName, brand, ingredients, nutrition in
                        print("🔍 [OCR_RESULTS] User chose to upload to database")
                        print("🔍 [OCR_RESULTS] Product name: \(productName), brand: \(brand)")
                        print("🔍 [OCR_RESULTS] Ingredients count: \(ingredients.count)")
                        print("🔍 [OCR_RESULTS] Current result barcode: \(result.barcode?.value ?? "NIL")")
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingOCRResults = false
                        }
                        print("🔍 [OCR_RESULTS] showingOCRResults set to false")
                        
                        // Resume camera for continued scanning after upload
                        resumeCameraScanning()
                        uploadNutritionalDataToDatabase(
                            productName: productName,
                            brand: brand,
                            ingredients: ingredients,
                            nutrition: nutrition
                        )
                    },
                    onRetry: {
                        print("🔍 [OCR_RESULTS] User chose to retry nutritional label scan")
                        print("🔍 [OCR_RESULTS] Current detectedBarcode: \(detectedBarcode?.value ?? "NIL")")
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingOCRResults = false
                        }
                        print("🔍 [OCR_RESULTS] showingOCRResults set to false")
                        
                        // Resume camera for retry
                        resumeCameraForNutritionalLabelScan()
                        showingNutritionalLabelScan = true
                        hybridScanResult = nil
                        print("🔍 [OCR_RESULTS] Retry setup - showingNutritionalLabelScan: \(showingNutritionalLabelScan), hybridScanResult cleared")
                    }
                )
                .onAppear {
                    print("🔍 [OCR_RESULTS] NutritionalLabelResultView appeared")
                    print("🔍 [OCR_RESULTS] Result barcode: \(result.barcode?.value ?? "NIL")")
                    print("🔍 [OCR_RESULTS] Current detectedBarcode: \(detectedBarcode?.value ?? "NIL")")
                    print("🔍 [OCR_RESULTS] OCR text length: \(result.ocrText.count) characters")
                    print("🔍 [OCR_RESULTS] Scan method: \(result.scanMethod), confidence: \(result.confidence)")
                    print("🔍 [OCR_RESULTS] Current UI state - showingOCRResults: \(showingOCRResults)")
                    
                    // Don't stop camera here - let the result sheet handle it
                    // This prevents duplicate camera stops that cause blank sheets
                    stopCameraForSheetPresentation()
                }
                .onDisappear {
                    print("🔍 [OCR_RESULTS] NutritionalLabelResultView disappeared")
                    // Camera will be resumed when user returns to main scanning view
                    // This prevents premature camera resume while sheet is still showing
                }
            } else {
                // Return an empty view when no result is available
                EmptyView()
                    .onAppear {
                        print("🔍 [OCR_RESULTS] ❌ No hybridScanResult available for OCR results sheet")
                    }
            }
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
            // Don't resume camera here - it will be handled when sheets are dismissed
            // This prevents camera resume while sheets are still showing
        }
        .onDisappear {
            // MEMORY OPTIMIZATION: Clear scan results when view disappears to prevent memory leaks
            clearScanState()
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
    
    // MARK: - Memory Management
    
    /**
     * Clear scan state when view disappears to prevent memory leaks
     * This helps prevent freezing when navigating between tabs
     */
    private func clearScanState() {
        print("🔍 [CLEAR_SCAN_STATE] clearScanState called")
        print("🔍 [CLEAR_SCAN_STATE] Current state - detectedBarcode: \(detectedBarcode?.value ?? "NIL")")
        print("🔍 [CLEAR_SCAN_STATE] Current state - showingNutritionalLabelScan: \(showingNutritionalLabelScan)")
        print("🔍 [CLEAR_SCAN_STATE] Current state - showingProductNotFound: \(showingProductNotFound)")
        print("🔍 [CLEAR_SCAN_STATE] Current state - showingProductFound: \(showingProductFound)")
        print("🔍 [CLEAR_SCAN_STATE] Current state - showingOCRResults: \(showingOCRResults)")
        print("🔍 [CLEAR_SCAN_STATE] Current state - foundProduct: \(foundProduct?.name ?? "NIL")")
        print("🔍 [CLEAR_SCAN_STATE] Current state - hybridScanResult: \(hybridScanResult != nil ? "SET" : "NIL")")
        
        // Clear scan results
        print("🔍 [CLEAR_SCAN_STATE] Clearing hybridScanResult and scanResult")
        hybridScanResult = nil
        scanResult = nil
        
        // Don't clear detectedBarcode if we're in nutritional label flow OR product not found flow
        // This preserves the barcode for nutritional label processing and retry functionality
        if !showingNutritionalLabelScan && !showingProductNotFound {
            print("🔍 [CLEAR_SCAN_STATE] Clearing detectedBarcode because not in nutritional label or product not found flow")
            detectedBarcode = nil
        } else {
            print("🔍 [CLEAR_SCAN_STATE] Preserving detectedBarcode because in nutritional label flow: \(showingNutritionalLabelScan) or product not found flow: \(showingProductNotFound)")
        }
        
        print("🔍 [CLEAR_SCAN_STATE] Clearing foundProduct")
        foundProduct = nil
        
        // Clear service states
        print("🔍 [CLEAR_SCAN_STATE] Clearing hybridScanService results")
        hybridScanService.clearResults()
        
        // Reset UI states
        print("🔍 [CLEAR_SCAN_STATE] Resetting UI states")
        showingProductFound = false
        showingProductNotFound = false
        showingNutritionalLabelScan = false
        showingBarcodeOverlay = false
        
        print("🔍 [CLEAR_SCAN_STATE] clearScanState completed")
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
        // Prevent barcode detection when any sheet is already being presented
        if showingProductFound || showingProductNotFound || showingOCRResults || showingNutritionalLabelScan {
            return
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            detectedBarcode = barcode
        }
        
        // Pause camera after barcode detection to save battery and prevent continuous scanning
        pauseCameraAfterBarcodeDetection()
        
        // Auto-analyze high confidence barcodes
        if barcode.confidence > 0.8 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                analyzeDetectedBarcode(barcode)
            }
        } else {
            // For low confidence barcodes, auto-resume camera after 10 seconds if no user interaction
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                if self.detectedBarcode?.value == barcode.value && 
                   !self.showingProductFound && !self.showingProductNotFound && 
                   !self.showingOCRResults && !self.showingNutritionalLabelScan {
                    self.resumeCameraForRescan()
                }
            }
        }
    }
    
    private func analyzeDetectedBarcode(_ barcode: BarcodeResult) {
        Task {
            // Look up product in database
            do {
                let product = try await APIService.shared.lookupProductByBarcode(barcode.value)
                
                await MainActor.run {
                    if let product = product {
                        // Product found in database
                        foundProduct = product
                        showingProductFound = true
                        
                        // Now clear the barcode detection card since we have the product
                        withAnimation(.easeInOut(duration: 0.3)) {
                            detectedBarcode = nil
                        }
                    } else {
                        // Product not found - prompt for nutritional label scan
                        detectedBarcode = barcode // Restore barcode for nutritional label scan
                        showingProductNotFound = true
                    }
                }
            } catch {
                // Error looking up product - treat as not found
                await MainActor.run {
                    detectedBarcode = barcode // Restore barcode for nutritional label scan
                    showingProductNotFound = true
                }
            }
        }
    }
    
    // MARK: - Analysis
    
    private func analyzeHybridResult() {
        guard let result = hybridScanResult else { return }
        
        // Clear scan complete popup when analysis starts
        withAnimation(.easeInOut(duration: 0.3)) {
            hybridScanResult = nil
        }
        
        if petService.pets.count == 1 {
            selectedPet = petService.pets.first
            analyzeIngredientsWithResult(result)
        } else if petService.pets.count > 1 {
            showingPetSelection = true
        } else {
            showingAddPet = true
        }
    }
    
    private func analyzeIngredients() {
        guard let result = hybridScanResult,
              let _ = selectedPet else { return }
        
        analyzeIngredientsWithResult(result)
    }
    
    private func analyzeIngredientsWithResult(_ result: HybridScanResult) {
        guard let pet = selectedPet else { return }
        
        // Don't clear OCR results if user is still in nutritional label scanning flow
        let shouldPreserveOCRResults = showingOCRResults || showingNutritionalLabelScan
        
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
                // Clear all popups when analysis completes (only if not preserving OCR results)
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingProductFound = false
                    showingProductNotFound = false
                    if !shouldPreserveOCRResults {
                        showingOCRResults = false
                        detectedBarcode = nil
                    }
                    foundProduct = nil
                }
                
                scanResult = scan
                showingResults = true
                
                // Resume camera for continued scanning after analysis completes
                resumeCameraScanning()
            }
        }
    }
    
    // MARK: - Actions
    
    private func retryScan() {
        withAnimation(.easeInOut(duration: 0.3)) {
            hybridScanResult = nil
            // Don't clear detectedBarcode on retry - preserve it for the user to try again
            print("🔍 DEBUG: retryScan preserving detectedBarcode for retry: \(detectedBarcode?.value ?? "NIL")")
            showingProductFound = false
            showingProductNotFound = false
            foundProduct = nil
        }
        
        // Don't resume camera here - let the user choose when to start scanning again
        // The camera will be resumed when the user actually starts scanning
        
        // Clear any existing barcode detection to allow fresh scanning
        // The camera will automatically reset its processing state after the cooldown period
    }
    
    // MARK: - Camera Control
    
    /**
     * Pause camera scanning when popups are shown
     * This prevents unwanted background scanning during modals
     */
    private func pauseCameraScanning() {
        // Pause the hybrid scan service to stop background processing
        hybridScanService.pauseScanning()
    }
    
    /**
     * Resume camera scanning when popups are dismissed
     * This restores normal scanning functionality
     */
    private func resumeCameraScanning() {
        // Resume the hybrid scan service for normal operation
        hybridScanService.resumeScanning()
    }
    
    /**
     * Pause camera after barcode detection to save battery and preserve data
     * This prevents continuous scanning while keeping the barcode data
     */
    private func pauseCameraAfterBarcodeDetection() {
        guard !isCameraPaused else { return }
        
        // Pause the camera session
        cameraController?.pauseCameraSession()
        isCameraPaused = true
    }
    
    /**
     * Resume camera for nutritional label scanning
     * Called when user needs to scan nutritional labels
     */
    private func resumeCameraForNutritionalLabelScan() {
        guard isCameraPaused else { return }
        
        // Resume the camera session
        cameraController?.resumeCameraSession()
        isCameraPaused = false
    }
    
    /**
     * Resume camera for rescanning after low confidence barcode detection
     * Clears the barcode detection card and resumes normal scanning
     */
    private func resumeCameraForRescan() {
        guard isCameraPaused else { return }
        
        // Resume the camera session
        cameraController?.resumeCameraSession()
        isCameraPaused = false
        
        // Clear the barcode detection card to allow fresh scanning
        withAnimation(.easeInOut(duration: 0.3)) {
            detectedBarcode = nil
        }
    }
    
    /**
     * Pause camera after nutritional label capture to prevent interference
     * This prevents barcode detection from interfering with nutritional label processing
     */
    private func pauseCameraAfterNutritionalLabelCapture() {
        guard !isCameraPaused else { return }
        
        // Pause the camera session to prevent barcode interference
        cameraController?.pauseCameraSession()
        isCameraPaused = true
    }
    
    /**
     * Completely stop camera session when OCR results sheet is presented
     * This prevents resource conflicts and blank screens
     */
    private func stopCameraForSheetPresentation() {
        // Completely stop the camera session to prevent resource conflicts
        cameraController?.stopCameraSessionCompletely()
        isCameraPaused = true
    }
    
    /**
     * Process nutritional label image captured manually
     */
    private func processNutritionalLabelImage(_ image: UIImage) {
        print("🔍 [NUTRITIONAL_LABEL_PROCESSING] Starting image processing")
        print("🔍 [NUTRITIONAL_LABEL_PROCESSING] Current detectedBarcode: \(detectedBarcode?.value ?? "NIL")")
        print("🔍 [NUTRITIONAL_LABEL_PROCESSING] Image size: \(image.size)")
        print("🔍 [NUTRITIONAL_LABEL_PROCESSING] Current UI state - showingNutritionalLabelScan: \(showingNutritionalLabelScan), showingOCRResults: \(showingOCRResults)")
        
        Task {
            print("🔍 [NUTRITIONAL_LABEL_PROCESSING] Starting OCR-only scan")
            // Use OCR-only scan for nutritional label
            let result = await hybridScanService.performOCROnlyScan(from: image)
            print("🔍 [NUTRITIONAL_LABEL_PROCESSING] OCR scan completed")
            print("🔍 [NUTRITIONAL_LABEL_PROCESSING] OCR result - scanMethod: \(result.scanMethod), confidence: \(result.confidence)")
            print("🔍 [NUTRITIONAL_LABEL_PROCESSING] OCR text length: \(result.ocrText.count) characters")
            
            await MainActor.run {
                // Preserve the detected barcode from the original scan
                print("🔍 [NUTRITIONAL_LABEL_PROCESSING] Processing result on main thread")
                print("🔍 [NUTRITIONAL_LABEL_PROCESSING] Current detectedBarcode: \(detectedBarcode?.value ?? "NIL")")
                
                if let originalBarcode = detectedBarcode {
                    print("🔍 [NUTRITIONAL_LABEL_PROCESSING] ✅ Preserving barcode: \(originalBarcode.value)")
                    // Create a new result with the preserved barcode
                    let updatedResult = HybridScanResult(
                        barcode: originalBarcode,
                        productInfo: result.productInfo,
                        foodProduct: result.foodProduct,
                        ocrText: result.ocrText,
                        ocrAnalysis: result.ocrAnalysis,
                        scanMethod: result.scanMethod,
                        confidence: result.confidence,
                        processingTime: result.processingTime,
                        lastCapturedImage: result.lastCapturedImage
                    )
                    hybridScanResult = updatedResult
                    print("🔍 [NUTRITIONAL_LABEL_PROCESSING] ✅ Updated result created with barcode: \(updatedResult.barcode?.value ?? "NIL")")
                } else {
                    print("🔍 [NUTRITIONAL_LABEL_PROCESSING] ❌ No detectedBarcode to preserve, using OCR-only result")
                    hybridScanResult = result
                }
                
                // Show the OCR results sheet
                print("🔍 [NUTRITIONAL_LABEL_PROCESSING] Setting showingOCRResults to true")
                showingOCRResults = true
                print("🔍 [NUTRITIONAL_LABEL_PROCESSING] Final UI state - showingOCRResults: \(showingOCRResults), hybridScanResult: \(hybridScanResult != nil ? "SET" : "NIL")")
            }
        }
    }
    
    /**
     * Upload scanned nutritional data to database
     * Creates a new food item from OCR-extracted information including both calorie values
     * Then automatically analyzes the data for the user's pet
     */
    private func uploadNutritionalDataToDatabase(
        productName: String,
        brand: String,
        ingredients: [String],
        nutrition: ParsedNutrition
    ) {
        guard let result = hybridScanResult else { return }
        
        Task {
            do {
                // Create a food product from the edited user data
                let foodProduct = createFoodProductFromEditedData(
                    result: result,
                    productName: productName,
                    brand: brand,
                    ingredients: ingredients,
                    nutrition: nutrition
                )
                
                // Log the created product for debugging
                print("📦 Created FoodProduct (Database Schema Compliant):")
                print("   Name: \(foodProduct.name)")
                print("   Brand: \(foodProduct.brand ?? "Unknown")")
                print("   Barcode: \(foodProduct.barcode ?? "None")")
                print("   Data Quality Score: \(foodProduct.nutritionalInfo?.dataQualityScore ?? 0.0)")
                print("   Calories per 100g: \(foodProduct.nutritionalInfo?.caloriesPer100g ?? 0)")
                if let meValue = foodProduct.nutritionalInfo?.nutrientLevels["metabolizable_energy_kcal_per_kg"] {
                    print("   ME (kcal/kg): \(meValue)")
                }
                if let treatValue = foodProduct.nutritionalInfo?.nutrientLevels["calories_per_treat"] {
                    print("   Calories per treat: \(treatValue)")
                }
                print("   Ingredients: \(foodProduct.nutritionalInfo?.ingredients.count ?? 0) items")
                print("   Source: \(foodProduct.nutritionalInfo?.source ?? "Unknown")")
                print("   External ID: \(foodProduct.nutritionalInfo?.externalId ?? "None")")
                
                // Convert FoodProduct to API format
                let nutritionalInfoDict = convertNutritionalInfoToDict(foodProduct.nutritionalInfo)
                
                // Check if user is authenticated
                let authToken = await APIService.shared.getAuthToken()
                if authToken == nil {
                    print("⚠️ DEBUG: User not authenticated, cannot upload food item")
                    await MainActor.run {
                        errorMessage = "Please log in to upload food items"
                        showingErrorToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            showingErrorToast = false
                        }
                    }
                    return
                }
                
                // Upload to database via API
                print("🚀 Uploading to database...")
                let success = try await APIService.shared.createFoodItem(
                    name: foodProduct.name,
                    brand: foodProduct.brand,
                    barcode: foodProduct.barcode,
                    category: foodProduct.category,
                    species: nil, // Let the system determine
                    language: "en",
                    country: nil,
                    externalSource: "user_upload",
                    nutritionalInfo: nutritionalInfoDict
                )
                
                if success {
                    await MainActor.run {
                        print("✅ Food product uploaded successfully to database!")
                        print("   Both calorie values saved: ME and per-treat values stored in nutrientLevels")
                        
                        // Show success toast with food item name
                        successMessage = "\(foodProduct.name) uploaded successfully! 🎉"
                        showingSuccessToast = true
                        
                        // Auto-hide toast after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            showingSuccessToast = false
                        }
                    }
                    
                    // Automatically analyze the uploaded data for the user's pet
                    await analyzeUploadedDataForPet(result: result, foodProduct: foodProduct)
                    
                    // Resume camera for continued scanning after upload completes
                    await MainActor.run {
                        resumeCameraScanning()
                    }
                } else {
                    await MainActor.run {
                        print("❌ Failed to upload food product to database")
                        
                        // Show error toast
                        errorMessage = "Failed to upload food item. Please try again."
                        showingErrorToast = true
                        
                        // Auto-hide error toast after 4 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                            showingErrorToast = false
                        }
                        
                        // Resume camera for continued scanning even after upload failure
                        resumeCameraScanning()
                    }
                }
                
            } catch {
                await MainActor.run {
                    print("❌ Error uploading food product: \(error.localizedDescription)")
                    
                    // Show error toast
                    errorMessage = "Upload failed: \(error.localizedDescription)"
                    showingErrorToast = true
                    
                    // Auto-hide error toast after 4 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        showingErrorToast = false
                    }
                    
                    // Resume camera for continued scanning even after upload error
                    resumeCameraScanning()
                }
            }
        }
    }
    
    /**
     * Automatically analyze uploaded data for the user's pet
     * This provides immediate feedback on the newly uploaded food item
     */
    private func analyzeUploadedDataForPet(result: HybridScanResult, foodProduct: FoodProduct) async {
        // Check if user has pets
        if petService.pets.isEmpty {
            await MainActor.run {
                print("ℹ️ No pets found - skipping automatic analysis")
                // Could show a message suggesting to add a pet first
            }
            return
        }
        
        // Use the first pet if only one, otherwise show pet selection
        if petService.pets.count == 1 {
            selectedPet = petService.pets.first
            await performAutomaticAnalysis(result: result, foodProduct: foodProduct)
        } else {
            await MainActor.run {
                print("ℹ️ Multiple pets found - showing pet selection for analysis")
                showingPetSelection = true
            }
        }
    }
    
    /**
     * Perform automatic analysis of the uploaded food item
     */
    private func performAutomaticAnalysis(result: HybridScanResult, foodProduct: FoodProduct) async {
        guard let pet = selectedPet else { return }
        
        await MainActor.run {
            print("🔍 Analyzing uploaded food for \(pet.name)...")
        }
        
        // Don't clear OCR results if user is still in nutritional label scanning flow
        let shouldPreserveOCRResults = showingOCRResults || showingNutritionalLabelScan
        
        // Use the ingredients from the uploaded food product
        let ingredients = foodProduct.nutritionalInfo?.ingredients.joined(separator: ", ") ?? result.ocrText
        let productName = foodProduct.name
        
        // Determine API scan method
        let apiScanMethod: ScanMethod = .ocr // Since this is from OCR scan
        
        // Convert image to base64 for analysis
        var imageData: String? = nil
        if let image = result.lastCapturedImage {
            if let jpegData = image.jpegData(compressionQuality: 0.8) {
                imageData = jpegData.base64EncodedString()
            }
        }
        
        let analysisRequest = ScanAnalysisRequest(
            petId: pet.id,
            extractedText: ingredients,
            productName: productName,
            scanMethod: apiScanMethod,
            imageData: imageData
        )
        
        scanService.analyzeScan(analysisRequest) { scan in
            Task { @MainActor in
                // Clear all popups when analysis completes (only if not preserving OCR results)
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingProductFound = false
                    showingProductNotFound = false
                    if !shouldPreserveOCRResults {
                        showingOCRResults = false
                        detectedBarcode = nil
                    }
                    foundProduct = nil
                }
                
                scanResult = scan
                showingResults = true
                print("✅ Analysis complete for \(pet.name)!")
                if let result = scan.result {
                    print("   Safety: \(result.overallSafety)")
                    print("   Confidence: \(result.confidenceScore)")
                }
                
                // Camera will be resumed when the nutritional label result sheet is dismissed
            }
        }
    }
    
    /**
     * Convert NutritionalInfo to dictionary format for API
     */
    private func convertNutritionalInfoToDict(_ nutritionalInfo: FoodProduct.NutritionalInfo?) -> [String: Any]? {
        guard let info = nutritionalInfo else { return nil }
        
        var dict: [String: Any] = [:]
        
        // Nutritional values
        if let calories = info.caloriesPer100g { dict["calories_per_100g"] = calories }
        if let protein = info.proteinPercentage { dict["protein_percentage"] = protein }
        if let fat = info.fatPercentage { dict["fat_percentage"] = fat }
        if let fiber = info.fiberPercentage { dict["fiber_percentage"] = fiber }
        if let moisture = info.moisturePercentage { dict["moisture_percentage"] = moisture }
        if let ash = info.ashPercentage { dict["ash_percentage"] = ash }
        if let carbs = info.carbohydratesPercentage { dict["carbohydrates_percentage"] = carbs }
        if let sugars = info.sugarsPercentage { dict["sugars_percentage"] = sugars }
        if let saturatedFat = info.saturatedFatPercentage { dict["saturated_fat_percentage"] = saturatedFat }
        if let sodium = info.sodiumPercentage { dict["sodium_percentage"] = sodium }
        
        // Arrays
        dict["ingredients"] = info.ingredients
        dict["allergens"] = info.allergens
        dict["additives"] = info.additives
        dict["vitamins"] = info.vitamins
        dict["minerals"] = info.minerals
        
        // Metadata
        dict["source"] = info.source
        dict["external_id"] = info.externalId
        dict["data_quality_score"] = info.dataQualityScore
        dict["last_updated"] = info.lastUpdated
        
        // Objects
        dict["nutrient_levels"] = info.nutrientLevels.mapValues { $0.value }
        dict["packaging_info"] = info.packagingInfo.mapValues { $0.value }
        dict["manufacturing_info"] = info.manufacturingInfo.mapValues { $0.value }
        
        return dict
    }
    
    /**
     * Create a FoodProduct from OCR scan result
     * Extracts barcode, product name, and nutritional information including both calorie values
     * Matches the exact database schema structure for consistency
     */
    private func createFoodProductFromOCR(_ result: HybridScanResult) -> FoodProduct {
        // Parse nutritional information from OCR text using the enhanced parser
        let parsedNutrition = NutritionalLabelResultView.parseNutritionalInfo(from: result.ocrText)
        
        // Extract product name (use parsed name or fallback to first line)
        let productName = parsedNutrition.productName ?? 
                         result.ocrText.components(separatedBy: .newlines)
                         .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? 
                         "Unknown Product"
        
        // Convert kcal/kg to calories per 100g for database storage
        // Formula: kcal/kg ÷ 10 = kcal/100g
        let caloriesPer100g: Double? = parsedNutrition.calories != nil ? 
                                      parsedNutrition.calories! / 10.0 : nil
        
        // Create comprehensive nutritional info matching database schema exactly
        let nutritionalInfo = FoodProduct.NutritionalInfo(
            // Nutritional Values (10 fields) - numbers or null
            caloriesPer100g: caloriesPer100g,
            proteinPercentage: parsedNutrition.protein,
            fatPercentage: parsedNutrition.fat,
            fiberPercentage: parsedNutrition.fiber,
            moisturePercentage: parsedNutrition.moisture,
            ashPercentage: parsedNutrition.ash,
            carbohydratesPercentage: parsedNutrition.carbohydrates,
            sugarsPercentage: nil, // Not parsed yet - will be null in database
            saturatedFatPercentage: nil, // Not parsed yet - will be null in database
            sodiumPercentage: parsedNutrition.sodium,
            
            // Arrays (5 fields) - empty arrays if missing
            ingredients: parsedNutrition.ingredients,
            allergens: [], // Could be parsed from ingredients in future
            additives: [], // Could be parsed from ingredients in future
            vitamins: [], // Could be parsed in future
            minerals: [], // Could be parsed in future
            
            // Metadata (4 fields) - strings with defaults
            source: "user_upload",
            externalId: result.barcode?.value ?? "", // Use barcode as external ID
            dataQualityScore: calculateDataQualityScore(parsedNutrition),
            lastUpdated: ISO8601DateFormatter().string(from: Date()),
            
            // Objects (3 fields) - empty objects if missing
            nutrientLevels: createNutrientLevels(parsedNutrition),
            packagingInfo: [:], // Empty object - no packaging data from OCR
            manufacturingInfo: [:] // Empty object - no manufacturing data from OCR
        )
        
        return FoodProduct(
            id: UUID().uuidString,
            name: productName,
            brand: parsedNutrition.brand,
            barcode: result.barcode?.value,
            nutritionalInfo: nutritionalInfo,
            category: nil,
            description: "User uploaded from nutritional label scan with enhanced parsing",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    /**
     * Create a FoodProduct from edited user data
     * Uses the user's edited values instead of parsing from OCR text
     * Matches the exact database schema structure for consistency
     */
    private func createFoodProductFromEditedData(
        result: HybridScanResult,
        productName: String,
        brand: String,
        ingredients: [String],
        nutrition: ParsedNutrition
    ) -> FoodProduct {
        // Convert kcal/kg to calories per 100g for database storage
        // Formula: kcal/kg ÷ 10 = kcal/100g
        let caloriesPer100g: Double? = nutrition.calories != nil ? 
                                      nutrition.calories! / 10.0 : nil
        
        // Create comprehensive nutritional info matching database schema exactly
        let nutritionalInfo = FoodProduct.NutritionalInfo(
            // Nutritional Values (10 fields) - numbers or null
            caloriesPer100g: caloriesPer100g,
            proteinPercentage: nutrition.protein,
            fatPercentage: nutrition.fat,
            fiberPercentage: nutrition.fiber,
            moisturePercentage: nutrition.moisture,
            ashPercentage: nutrition.ash,
            carbohydratesPercentage: nutrition.carbohydrates,
            sugarsPercentage: nil, // Not parsed yet - will be null in database
            saturatedFatPercentage: nil, // Not parsed yet - will be null in database
            sodiumPercentage: nutrition.sodium,
            
            // Arrays (5 fields) - use edited ingredients
            ingredients: ingredients, // Use user's edited ingredients
            allergens: [], // Could be parsed from ingredients in future
            additives: [], // Could be parsed from ingredients in future
            vitamins: [], // Could be parsed in future
            minerals: [], // Could be parsed in future
            
            // Metadata (4 fields) - strings with defaults
            source: "user_upload",
            externalId: result.barcode?.value ?? "", // Use barcode as external ID
            dataQualityScore: calculateDataQualityScore(nutrition),
            lastUpdated: ISO8601DateFormatter().string(from: Date()),
            
            // Objects (3 fields) - empty objects if missing
            nutrientLevels: createNutrientLevels(nutrition),
            packagingInfo: [:], // Empty object - no packaging data from OCR
            manufacturingInfo: [:] // Empty object - no manufacturing data from OCR
        )
        
        return FoodProduct(
            id: UUID().uuidString,
            name: productName, // Use user's edited product name
            brand: brand, // Use user's edited brand
            barcode: result.barcode?.value,
            nutritionalInfo: nutritionalInfo,
            category: nil,
            description: "User uploaded from nutritional label scan with user-edited data",
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    /**
     * Calculate data quality score using enhanced DataQualityService
     * Returns a score from 0.0 to 1.0 based on ingredients and nutritional completeness
     */
    private func calculateDataQualityScore(_ nutrition: ParsedNutrition) -> Double {
        // Convert ParsedNutrition to dictionary format for quality assessment
        var nutritionalData: [String: Any] = [:]
        
        if let calories = nutrition.calories { nutritionalData["calories_per_100g"] = calories }
        if let protein = nutrition.protein { nutritionalData["protein_percentage"] = protein }
        if let fat = nutrition.fat { nutritionalData["fat_percentage"] = fat }
        if let fiber = nutrition.fiber { nutritionalData["fiber_percentage"] = fiber }
        if let moisture = nutrition.moisture { nutritionalData["moisture_percentage"] = moisture }
        if let ash = nutrition.ash { nutritionalData["ash_percentage"] = ash }
        if let carbs = nutrition.carbohydrates { nutritionalData["carbohydrates_percentage"] = carbs }
        if let sodium = nutrition.sodium { nutritionalData["sodium_percentage"] = sodium }
        
        // Calculate nutritional score using the enhanced service
        let nutritionalResult = DataQualityService.calculateNutritionalScore(nutritionalData)
        
        // Calculate ingredients score
        let ingredientsResult = DataQualityService.calculateIngredientsScore(nutrition.ingredients)
        
        // Weighted overall score (nutritional: 70%, ingredients: 30%)
        let overallScore = (nutritionalResult.score * 0.7) + (ingredientsResult.score * 0.3)
        
        return min(overallScore, 1.0)
    }
    
    /**
     * Create nutrient levels object with both calorie values
     * Stores additional nutritional data in the nutrientLevels JSONB field
     */
    private func createNutrientLevels(_ nutrition: ParsedNutrition) -> [String: AnyCodable] {
        var levels: [String: AnyCodable] = [:]
        
        // Store both calorie values for future reference
        if let meValue = nutrition.calories {
            levels["metabolizable_energy_kcal_per_kg"] = AnyCodable(meValue)
        }
        
        if let treatValue = nutrition.caloriesPerTreat {
            levels["calories_per_treat"] = AnyCodable(treatValue)
        }
        
        // Store additional nutritional data that might be useful
        if let protein = nutrition.protein {
            levels["protein_percentage"] = AnyCodable(protein)
        }
        
        if let fat = nutrition.fat {
            levels["fat_percentage"] = AnyCodable(fat)
        }
        
        if let fiber = nutrition.fiber {
            levels["fiber_percentage"] = AnyCodable(fiber)
        }
        
        // Add parsing metadata
        levels["parsing_method"] = AnyCodable("enhanced_ocr")
        levels["parsing_timestamp"] = AnyCodable(ISO8601DateFormatter().string(from: Date()))
        
        return levels
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
        
        // Don't clear OCR results if user is still in nutritional label scanning flow
        let shouldPreserveOCRResults = showingOCRResults || showingNutritionalLabelScan
        
        // Get ingredients from product
        let ingredientsText = product.nutritionalInfo?.ingredients.joined(separator: ", ") ?? ""
        
        // Create analysis request with product info
        let analysisRequest = ScanAnalysisRequest(
            petId: pet.id,
            extractedText: ingredientsText,
            productName: product.name,
            scanMethod: .barcode,  // Product from barcode scan
            imageData: nil  // No image needed for database products
        )
        
        scanService.analyzeScan(analysisRequest) { scan in
            Task { @MainActor in
                // Clear all popups when analysis completes (only if not preserving OCR results)
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingProductFound = false
                    showingProductNotFound = false
                    if !shouldPreserveOCRResults {
                        showingOCRResults = false
                        detectedBarcode = nil
                    }
                    foundProduct = nil
                }
                
                scanResult = scan
                showingResults = true
            }
        }
    }
}

// MARK: - Supporting Views with Trust & Nature Design System

struct ScanningFrameOverlay: View {
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark overlay with transparent scanning area - covers entire screen
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .mask(
                        Rectangle()
                            .frame(width: geometry.size.width, height: geometry.size.height)
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
            }
        }
        .ignoresSafeArea(.all)
        .onAppear {
            isAnimating = true
        }
    }
}

struct BarcodeDetectionCard: View {
    let barcode: BarcodeResult
    let onAnalyze: () -> Void
    let onRescan: () -> Void
    
    @State private var countdownTimer: Timer?
    @State private var timeRemaining = 10
    
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
                    .foregroundColor(barcode.confidence > 0.8 ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.warning)
                
                // Show countdown for low confidence barcodes
                if barcode.confidence <= 0.8 {
                    Text("Auto-rescan in \(timeRemaining)s")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .opacity(0.8)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Rescan button for low confidence barcodes
                if barcode.confidence <= 0.8 {
                    Button(action: onRescan) {
                        Text("Rescan")
                            .font(ModernDesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                            .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                            .padding(.vertical, ModernDesignSystem.Spacing.xs)
                            .background(ModernDesignSystem.Colors.softCream)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(ModernDesignSystem.Colors.primary, lineWidth: 1)
                            )
                    }
                }
                
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
        .onAppear {
            // Start countdown timer for low confidence barcodes
            if barcode.confidence <= 0.8 {
                startCountdownTimer()
            }
        }
        .onDisappear {
            // Stop countdown timer when card disappears
            stopCountdownTimer()
        }
    }
    
    private func startCountdownTimer() {
        timeRemaining = 10
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    // Auto-rescan when countdown reaches 0
                    onRescan()
                    stopCountdownTimer()
                }
            }
        }
    }
    
    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
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

/**
 * Success toast view for upload confirmation
 */
struct SuccessToastView: View {
    let message: String
    @Binding var isVisible: Bool
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.white)
            
            Text(message)
                .font(ModernDesignSystem.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(4)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    ModernDesignSystem.Colors.safe,
                    ModernDesignSystem.Colors.safe.opacity(0.9)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .shadow(
            color: ModernDesignSystem.Colors.safe.opacity(0.3),
            radius: 8,
            x: 0,
            y: 4
        )
        .onAppear {
            // Auto-hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }
            }
        }
    }
}

/**
 * Error toast view for upload failures
 */
struct ErrorToastView: View {
    let message: String
    @Binding var isVisible: Bool
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.white)
            
            Text(message)
                .font(ModernDesignSystem.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(4)
            }
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.md)
        .padding(.vertical, ModernDesignSystem.Spacing.sm)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    ModernDesignSystem.Colors.unsafe,
                    ModernDesignSystem.Colors.unsafe.opacity(0.9)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .shadow(
            color: ModernDesignSystem.Colors.unsafe.opacity(0.3),
            radius: 8,
            x: 0,
            y: 4
        )
        .onAppear {
            // Auto-hide after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isVisible = false
                }
            }
        }
    }
}

#Preview {
    ScanView()
        .environmentObject(PetService.shared)
}
