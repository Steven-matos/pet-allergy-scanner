//
//  HybridScanService.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import UIKit
import Vision
import Combine
import Observation

/**
 * Hybrid scanning service combining barcode detection and OCR text extraction
 * 
 * Implements the modern iOS scanning pattern:
 * 1. Try barcode scanning first (fast, accurate, structured data)
 * 2. Fallback to OCR if no barcode found (comprehensive coverage)
 * 3. Combine both data sources when available for enriched results
 * 
 * Uses latest Swift concurrency patterns and SwiftUI integration
 */
@Observable
@MainActor
class HybridScanService: @unchecked Sendable {
    static let shared = HybridScanService()
    
    // MARK: - Published Properties
    var isScanning = false
    var scanProgress: ScanProgress = .idle
    var scanResult: HybridScanResult?
    var errorMessage: String?
    
    // MARK: - Service Dependencies
    private let barcodeService = BarcodeService.shared
    private let ocrService = OCRService.shared
    private let apiService = APIService.shared
    
    // MARK: - Configuration
    private let barcodeConfidenceThreshold: Float = 0.7
    private let ocrConfidenceThreshold: Float = 0.5
    
    private init() {}
    
    /**
     * Perform hybrid scan on captured image
     * 
     * Scanning Strategy:
     * 1. Try barcode detection first (fast, accurate)
     * 2. If barcode found, attempt product lookup
     * 3. If no barcode or lookup fails, fallback to OCR
     * 4. Combine results for comprehensive analysis
     * 
     * - Parameter image: The captured image to scan
     * - Returns: HybridScanResult containing both barcode and OCR data
     */
    func performHybridScan(from image: UIImage) async -> HybridScanResult {
        isScanning = true
        scanProgress = .initializing
        errorMessage = nil
        
        let startTime = Date()
        
        // Phase 1: Barcode Detection
        scanProgress = .detectingBarcode
        let barcodeResult = await detectBarcode(from: image)
        
        var productInfo: ProductInfo?
        var barcodeData: BarcodeResult?
        
        if let barcode = barcodeResult {
            barcodeData = barcode
            scanProgress = .lookingUpProduct
            
            // Phase 2: Product Lookup (if barcode found)
            productInfo = await lookupProduct(by: barcode.value)
            
            // If we have reliable product data from barcode, we might skip OCR
            if productInfo != nil && barcode.confidence > 0.9 {
                scanProgress = .completed
                let result = HybridScanResult(
                    barcode: barcode,
                    productInfo: productInfo,
                    ocrText: "",
                    ocrAnalysis: nil,
                    scanMethod: .barcodeOnly,
                    confidence: barcode.confidence,
                    processingTime: Date().timeIntervalSince(startTime),
                    lastCapturedImage: image
                )
                
                isScanning = false
                return result
            }
        }
        
        // Phase 3: OCR Text Extraction (fallback or supplementary)
        scanProgress = .extractingText
        let ocrResult = await extractText(from: image)
        
        // Phase 4: Combine Results
        scanProgress = .analyzing
        let finalResult = await combineScanResults(
            barcode: barcodeData,
            productInfo: productInfo,
            ocrText: ocrResult.text,
            ocrAnalysis: ocrResult.analysis,
            processingTime: Date().timeIntervalSince(startTime),
            image: image
        )
        
        scanProgress = .completed
        isScanning = false
        
        return finalResult
    }
    
    /**
     * Quick scan using barcode detection only
     * Use for real-time scanning in camera preview
     */
    func quickBarcodeScan(from image: UIImage) async -> BarcodeResult? {
        return await withCheckedContinuation { continuation in
            Task {
                let result = barcodeService.scanBarcode(from: image)
                continuation.resume(returning: result)
            }
        }
    }
    
    /**
     * Smart retry mechanism with different scanning strategies
     */
    func retryScan(with strategy: ScanRetryStrategy, from image: UIImage) async -> HybridScanResult {
        switch strategy {
        case .barcodeOnly:
            return await performBarcodeOnlyScan(from: image)
        case .ocrOnly:
            return await performOCROnlyScan(from: image)
        case .hybrid:
            return await performHybridScan(from: image)
        case .enhancedOCR:
            return await performEnhancedOCRScan(from: image)
        }
    }
    
    /**
     * Clear current scan results and reset state
     */
    func clearResults() {
        scanResult = nil
        errorMessage = nil
        scanProgress = .idle
        barcodeService.clearResults()
        ocrService.clearResults()
    }
    
    // MARK: - Private Methods
    
    private func detectBarcode(from image: UIImage) async -> BarcodeResult? {
        return await withCheckedContinuation { continuation in
            Task {
                let result = barcodeService.scanBarcode(from: image)
                continuation.resume(returning: result)
            }
        }
    }
    
    private func lookupProduct(by barcode: String) async -> ProductInfo? {
        // In a real implementation, this would query a product database
        // For now, return basic product info from barcode
        return barcodeService.extractProductInfo(from: barcode)
    }
    
    private func extractText(from image: UIImage) async -> (text: String, analysis: NutritionalAnalysis?) {
        return await withCheckedContinuation { continuation in
            ocrService.extractText(from: image)
            
            // Wait for OCR to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                while self.ocrService.isProcessing {
                    // Wait for processing to complete
                }
                
                let result = (
                    text: self.ocrService.extractedText,
                    analysis: self.ocrService.nutritionalAnalysis
                )
                continuation.resume(returning: result)
            }
        }
    }
    
    private func combineScanResults(
        barcode: BarcodeResult?,
        productInfo: ProductInfo?,
        ocrText: String,
        ocrAnalysis: NutritionalAnalysis?,
        processingTime: TimeInterval,
        image: UIImage? = nil
    ) async -> HybridScanResult {
        
        let scanMethod: ScanMethod
        let confidence: Float
        
        if let barcode = barcode, let _ = productInfo {
            // Both barcode and product info available
            scanMethod = .barcodeWithProduct
            confidence = barcode.confidence
        } else if let barcode = barcode {
            // Barcode found but no product info
            scanMethod = .barcodeOnly
            confidence = barcode.confidence * 0.8 // Slightly lower confidence without product info
        } else if !ocrText.isEmpty {
            // OCR only
            scanMethod = .ocrOnly
            confidence = 0.6 // OCR typically has lower confidence
        } else {
            // No results
            scanMethod = .failed
            confidence = 0.0
        }
        
        return HybridScanResult(
            barcode: barcode,
            productInfo: productInfo,
            ocrText: ocrText,
            ocrAnalysis: ocrAnalysis,
            scanMethod: scanMethod,
            confidence: confidence,
            processingTime: processingTime,
            lastCapturedImage: image
        )
    }
    
    private func performBarcodeOnlyScan(from image: UIImage) async -> HybridScanResult {
        isScanning = true
        scanProgress = .detectingBarcode
        errorMessage = nil
        
        let startTime = Date()
        
        let barcodeResult = await detectBarcode(from: image)
        let productInfo = barcodeResult != nil ? await lookupProduct(by: barcodeResult!.value) : nil
        
        let result = HybridScanResult(
            barcode: barcodeResult,
            productInfo: productInfo,
            ocrText: "",
            ocrAnalysis: nil,
            scanMethod: barcodeResult != nil ? .barcodeOnly : .failed,
            confidence: barcodeResult?.confidence ?? 0.0,
            processingTime: Date().timeIntervalSince(startTime),
            lastCapturedImage: image
        )
        
        isScanning = false
        return result
    }
    
    private func performOCROnlyScan(from image: UIImage) async -> HybridScanResult {
        isScanning = true
        scanProgress = .extractingText
        errorMessage = nil
        
        let startTime = Date()
        
        let ocrResult = await extractText(from: image)
        
        let result = HybridScanResult(
            barcode: nil,
            productInfo: nil,
            ocrText: ocrResult.text,
            ocrAnalysis: ocrResult.analysis,
            scanMethod: ocrResult.text.isEmpty ? .failed : .ocrOnly,
            confidence: ocrResult.text.isEmpty ? 0.0 : 0.6,
            processingTime: Date().timeIntervalSince(startTime),
            lastCapturedImage: image
        )
        
        isScanning = false
        return result
    }
    
    private func performEnhancedOCRScan(from image: UIImage) async -> HybridScanResult {
        // Enhanced OCR with image preprocessing and multiple attempts
        isScanning = true
        scanProgress = .extractingText
        errorMessage = nil
        
        let _ = Date() // Track processing time for future metrics
        
        // TODO: Implement enhanced OCR with image preprocessing
        // This could include:
        // - Multiple image orientations
        // - Enhanced contrast/brightness
        // - Multiple recognition attempts with different settings
        
        return await performOCROnlyScan(from: image)
    }
}

// MARK: - Supporting Data Structures

/**
 * Comprehensive scan result combining barcode and OCR data
 */
struct HybridScanResult: Codable {
    let barcode: BarcodeResult?
    let productInfo: ProductInfo?
    let ocrText: String
    let ocrAnalysis: NutritionalAnalysis?
    let scanMethod: ScanMethod
    let confidence: Float
    let processingTime: TimeInterval
    let error: Error?
    let lastCapturedImage: UIImage?
    
    init(
        barcode: BarcodeResult?,
        productInfo: ProductInfo?,
        ocrText: String,
        ocrAnalysis: NutritionalAnalysis?,
        scanMethod: ScanMethod,
        confidence: Float,
        processingTime: TimeInterval,
        error: Error? = nil,
        lastCapturedImage: UIImage? = nil
    ) {
        self.barcode = barcode
        self.productInfo = productInfo
        self.ocrText = ocrText
        self.ocrAnalysis = ocrAnalysis
        self.scanMethod = scanMethod
        self.confidence = confidence
        self.processingTime = processingTime
        self.error = error
        self.lastCapturedImage = lastCapturedImage
    }
    
    // MARK: - Codable Conformance
    private enum CodingKeys: String, CodingKey {
        case barcode, productInfo, ocrText, ocrAnalysis, scanMethod, confidence, processingTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        barcode = try container.decodeIfPresent(BarcodeResult.self, forKey: .barcode)
        productInfo = try container.decodeIfPresent(ProductInfo.self, forKey: .productInfo)
        ocrText = try container.decode(String.self, forKey: .ocrText)
        ocrAnalysis = try container.decodeIfPresent(NutritionalAnalysis.self, forKey: .ocrAnalysis)
        scanMethod = try container.decode(ScanMethod.self, forKey: .scanMethod)
        confidence = try container.decode(Float.self, forKey: .confidence)
        processingTime = try container.decode(TimeInterval.self, forKey: .processingTime)
        error = nil // Error is not encoded
        lastCapturedImage = nil // UIImage is not encoded
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(barcode, forKey: .barcode)
        try container.encodeIfPresent(productInfo, forKey: .productInfo)
        try container.encode(ocrText, forKey: .ocrText)
        try container.encodeIfPresent(ocrAnalysis, forKey: .ocrAnalysis)
        try container.encode(scanMethod, forKey: .scanMethod)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(processingTime, forKey: .processingTime)
        // lastCapturedImage and error are not encoded
    }
}

/**
 * Scan progress states for UI feedback
 */
enum ScanProgress: String, CaseIterable {
    case idle = "idle"
    case initializing = "initializing"
    case detectingBarcode = "detectingBarcode"
    case lookingUpProduct = "lookingUpProduct"
    case extractingText = "extractingText"
    case analyzing = "analyzing"
    case completed = "completed"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .idle:
            return "Ready to Scan"
        case .initializing:
            return "Initializing..."
        case .detectingBarcode:
            return "Detecting Barcode..."
        case .lookingUpProduct:
            return "Looking Up Product..."
        case .extractingText:
            return "Extracting Text..."
        case .analyzing:
            return "Analyzing Results..."
        case .completed:
            return "Scan Complete"
        case .error:
            return "Scan Failed"
        }
    }
    
    var progress: Float {
        switch self {
        case .idle:
            return 0.0
        case .initializing:
            return 0.1
        case .detectingBarcode:
            return 0.3
        case .lookingUpProduct:
            return 0.5
        case .extractingText:
            return 0.7
        case .analyzing:
            return 0.9
        case .completed:
            return 1.0
        case .error:
            return 0.0
        }
    }
}

/**
 * Scan method used for result
 */
enum ScanMethod: String, Codable, CaseIterable {
    case barcodeOnly = "barcodeOnly"
    case barcodeWithProduct = "barcodeWithProduct"
    case ocrOnly = "ocrOnly"
    case hybrid = "hybrid"
    case failed = "failed"
    
}

/**
 * Retry strategy for failed scans
 */
enum ScanRetryStrategy: String, CaseIterable {
    case barcodeOnly = "barcodeOnly"
    case ocrOnly = "ocrOnly"
    case hybrid = "hybrid"
    case enhancedOCR = "enhancedOCR"
    
    var displayName: String {
        switch self {
        case .barcodeOnly:
            return "Barcode Only"
        case .ocrOnly:
            return "Text Recognition Only"
        case .hybrid:
            return "Hybrid Scan"
        case .enhancedOCR:
            return "Enhanced Text Recognition"
        }
    }
}
