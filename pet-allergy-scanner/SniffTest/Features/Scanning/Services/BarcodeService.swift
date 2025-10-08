//
//  BarcodeService.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import Foundation
import AVFoundation
import UIKit
import Combine
import Observation
@preconcurrency import Vision

/**
 * Barcode scanning service using AVFoundation for product identification
 * 
 * Supports multiple barcode formats commonly found on pet food products:
 * - UPC-A, UPC-E: Common in US pet food products
 * - EAN-13, EAN-8: International standard for pet food products
 * - Code 128: Used for additional product information
 * 
 * Integrates with OCRService for hybrid scanning approach (barcode-first, OCR fallback)
 */
@Observable
@MainActor
class BarcodeService: @unchecked Sendable {
    static let shared = BarcodeService()
    
    var isScanning = false
    var detectedBarcode: String?
    var barcodeType: String?
    var errorMessage: String?
    var scanConfidence: Float = 0.0
    
    // Supported barcode formats for pet food products
    private let supportedBarcodeTypes: [VNBarcodeSymbology] = [
        .ean13,     // European Article Number 13-digit
        .ean8,      // European Article Number 8-digit
        .upce,      // UPC-E
        .code128,   // Code 128
        .pdf417     // PDF417 (for additional product data)
    ]
    
    private init() {}
    
    /**
     * Scan for barcodes in a captured image
     * - Parameter image: The UIImage to scan for barcodes
     * - Returns: Barcode result with product identification data
     */
    func scanBarcode(from image: UIImage) -> BarcodeResult? {
        guard let cgImage = image.cgImage else {
            errorMessage = "Invalid image for barcode scanning"
            return nil
        }
        
        isScanning = true
        errorMessage = nil
        detectedBarcode = nil
        barcodeType = nil
        scanConfidence = 0.0
        
        let request = VNDetectBarcodesRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.isScanning = false
                
                if let error = error {
                    self?.errorMessage = "Barcode detection failed: \(error.localizedDescription)"
                    return
                }
                
                guard let observations = request.results as? [VNBarcodeObservation] else {
                    self?.errorMessage = "No barcodes detected in image"
                    return
                }
                
                // Find the highest confidence barcode
                let bestBarcode = observations.max { $0.confidence < $1.confidence }
                
                if let barcode = bestBarcode, barcode.confidence > 0.7 {
                    self?.detectedBarcode = barcode.payloadStringValue
                    self?.barcodeType = barcode.symbology.rawValue
                    self?.scanConfidence = barcode.confidence
                    self?.errorMessage = nil
                } else {
                    self?.errorMessage = "No reliable barcodes found (confidence too low)"
                }
            }
        }
        
        // Configure for pet food product barcodes
        request.symbologies = supportedBarcodeTypes
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self?.isScanning = false
                    self?.errorMessage = "Barcode processing failed: \(error.localizedDescription)"
                }
            }
        }
        
        // Return result if barcode was detected
        if let barcode = detectedBarcode, let type = barcodeType {
            return BarcodeResult(
                value: barcode,
                type: type,
                confidence: scanConfidence,
                timestamp: Date()
            )
        }
        
        return nil
    }
    
    /**
     * Validate barcode format for pet food products
     * - Parameter barcode: The barcode string to validate
     * - Returns: True if barcode format is valid for pet food products
     */
    func validateBarcode(_ barcode: String) -> Bool {
        // Remove any non-digit characters for validation
        let cleanBarcode = barcode.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Check length for common pet food barcode formats
        switch cleanBarcode.count {
        case 8:   // EAN-8
            return isValidEAN8(cleanBarcode)
        case 12:  // UPC-A
            return isValidUPCA(cleanBarcode)
        case 13:  // EAN-13
            return isValidEAN13(cleanBarcode)
        default:
            return false
        }
    }
    
    /**
     * Extract product information from barcode
     * - Parameter barcode: The barcode string
     * - Returns: Product information if available
     */
    func extractProductInfo(from barcode: String) -> ProductInfo? {
        let cleanBarcode = barcode.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // Basic product info extraction based on barcode format
        switch cleanBarcode.count {
        case 13: // EAN-13
            return extractEAN13Info(cleanBarcode)
        case 12: // UPC-A
            return extractUPCAInfo(cleanBarcode)
        case 8:  // EAN-8
            return extractEAN8Info(cleanBarcode)
        default:
            return nil
        }
    }
    
    /**
     * Clear current scanning results
     */
    func clearResults() {
        detectedBarcode = nil
        barcodeType = nil
        errorMessage = nil
        scanConfidence = 0.0
    }
    
    // MARK: - Private Helper Methods
    
    private func isValidEAN8(_ barcode: String) -> Bool {
        guard barcode.count == 8 else { return false }
        return validateChecksum(barcode)
    }
    
    private func isValidEAN13(_ barcode: String) -> Bool {
        guard barcode.count == 13 else { return false }
        return validateChecksum(barcode)
    }
    
    private func isValidUPCA(_ barcode: String) -> Bool {
        guard barcode.count == 12 else { return false }
        return validateChecksum(barcode)
    }
    
    private func validateChecksum(_ barcode: String) -> Bool {
        let digits = barcode.compactMap { Int(String($0)) }
        guard digits.count == barcode.count else { return false }
        
        var sum = 0
        for (index, digit) in digits.enumerated() {
            if index % 2 == 0 {
                sum += digit
            } else {
                sum += digit * 3
            }
        }
        
        return sum % 10 == 0
    }
    
    private func extractEAN13Info(_ barcode: String) -> ProductInfo? {
        // Extract country code (first 3 digits)
        let countryCode = String(barcode.prefix(3))
        
        // Extract manufacturer code (next 4-6 digits)
        let manufacturerCode = String(barcode.dropFirst(3).prefix(4))
        
        return ProductInfo(
            barcode: barcode,
            countryCode: countryCode,
            manufacturerCode: manufacturerCode,
            productCode: String(barcode.dropFirst(7).prefix(5)),
            checksum: String(barcode.suffix(1))
        )
    }
    
    private func extractUPCAInfo(_ barcode: String) -> ProductInfo? {
        return ProductInfo(
            barcode: barcode,
            countryCode: "US", // UPC-A is primarily US-based
            manufacturerCode: String(barcode.prefix(6)),
            productCode: String(barcode.dropFirst(6).prefix(5)),
            checksum: String(barcode.suffix(1))
        )
    }
    
    private func extractEAN8Info(_ barcode: String) -> ProductInfo? {
        return ProductInfo(
            barcode: barcode,
            countryCode: String(barcode.prefix(3)),
            manufacturerCode: String(barcode.dropFirst(3).prefix(3)),
            productCode: String(barcode.dropFirst(6).prefix(2)),
            checksum: String(barcode.suffix(1))
        )
    }
}

// MARK: - Supporting Data Structures

/**
 * Result of barcode scanning operation
 */
struct BarcodeResult: Codable, Equatable {
    let value: String
    let type: String
    let confidence: Float
    let timestamp: Date
}

/**
 * Product information extracted from barcode
 */
struct ProductInfo: Codable, Equatable {
    let barcode: String
    let countryCode: String
    let manufacturerCode: String
    let productCode: String
    let checksum: String
}

// MARK: - Barcode Format Extensions

extension BarcodeResult {
    /**
     * Human-readable description of barcode type
     */
    var typeDescription: String {
        switch type {
        case "VNBarcodeSymbologyEAN13":
            return "EAN-13 (International)"
        case "VNBarcodeSymbologyEAN8":
            return "EAN-8 (International)"
        case "VNBarcodeSymbologyUPCE":
            return "UPC-E (US)"
        case "VNBarcodeSymbologyCode128":
            return "Code 128"
        case "VNBarcodeSymbologyPDF417":
            return "PDF417"
        default:
            return "Unknown Format"
        }
    }
    
    /**
     * Confidence level description
     */
    var confidenceDescription: String {
        switch confidence {
        case 0.9...1.0:
            return "Very High"
        case 0.8..<0.9:
            return "High"
        case 0.7..<0.8:
            return "Medium"
        case 0.6..<0.7:
            return "Low"
        default:
            return "Very Low"
        }
    }
}
