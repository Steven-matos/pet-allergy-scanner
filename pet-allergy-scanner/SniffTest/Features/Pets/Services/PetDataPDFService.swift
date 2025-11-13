//
//  PetDataPDFService.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import Foundation
import PDFKit
import UIKit

/**
 * Pet Data PDF Service
 * 
 * Generates professional PDF documents for veterinary reports containing:
 * - Pet profile information
 * - Nutritional requirements and analysis
 * - Feeding history
 * - Product safety assessments
 * - Health timeline data
 * 
 * Follows SOLID principles with single responsibility for PDF generation
 * Implements DRY by reusing formatting methods
 * Follows KISS by keeping PDF layout simple and organized
 */
@MainActor
class PetDataPDFService {
    static let shared = PetDataPDFService()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Trust & Nature Design System Colors
    private let primaryColor = UIColor(red: 0.176, green: 0.314, blue: 0.086, alpha: 1.0) // #2D5016
    private let warmCoral = UIColor(red: 0.902, green: 0.494, blue: 0.133, alpha: 1.0) // #E67E22
    private let softCream = UIColor(red: 0.973, green: 0.965, blue: 0.941, alpha: 1.0) // #F8F6F0
    private let textPrimary = UIColor(red: 0.173, green: 0.243, blue: 0.314, alpha: 1.0) // #2C3E50
    private let textSecondary = UIColor(red: 0.741, green: 0.765, blue: 0.780, alpha: 1.0) // #BDC3C7
    private let borderPrimary = UIColor(red: 0.584, green: 0.647, blue: 0.651, alpha: 1.0) // #95A5A6
    private let safeColor = UIColor(red: 0.153, green: 0.682, blue: 0.376, alpha: 1.0) // #27AE60
    private let warningColor = UIColor(red: 0.953, green: 0.612, blue: 0.071, alpha: 1.0) // #F39C12
    private let errorColor = UIColor(red: 0.906, green: 0.298, blue: 0.235, alpha: 1.0) // #E74C3C
    
    private init() {}
    
    /**
     * Generate veterinary report PDF for a pet
     * - Parameter data: Complete pet data for the report
     * - Returns: PDF document data
     */
    func generateVetReport(data: VetReportData) throws -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "SniffTest Pet Allergy Scanner",
            kCGPDFContextAuthor: "Pet Owner",
            kCGPDFContextTitle: "Veterinary Report - \(data.pet.name)"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0 // US Letter width in points
        let pageHeight = 11.0 * 72.0 // US Letter height in points
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let pdfData = renderer.pdfData { context in
            // Start a new page
            context.beginPage()
            
            var currentY: CGFloat = 72.0 // Start 1 inch from top
            let margin: CGFloat = 72.0
            let contentWidth = pageWidth - (margin * 2)
            let contentX = margin // X position for content
            
            // Save graphics state and translate to content area
            context.cgContext.saveGState()
            context.cgContext.translateBy(x: contentX, y: 0)
            
            // Draw header with logo and app name on first page
            currentY = drawHeader(context: context, y: 0, width: contentWidth, pageWidth: pageWidth)
            currentY += 20 // Add spacing after header
            
            // Title Section
            currentY = drawTitleSection(
                context: context,
                y: currentY,
                width: contentWidth,
                petName: data.pet.name,
                generatedDate: data.generatedAt
            )
            
            currentY += 20
            
            // Pet Information Section
            currentY = drawPetInformationSection(
                context: context,
                y: currentY,
                width: contentWidth,
                pet: data.pet
            )
            
            currentY += 20
            
            // Nutritional Requirements Section
            currentY = drawNutritionalRequirementsSection(
                context: context,
                y: currentY,
                width: contentWidth,
                requirements: data.nutritionalRequirements
            )
            
            currentY += 20
            
            // Known Sensitivities Section
            if !data.pet.knownSensitivities.isEmpty {
                currentY = drawSensitivitiesSection(
                    context: context,
                    y: currentY,
                    width: contentWidth,
                    sensitivities: data.pet.knownSensitivities
                )
                currentY += 20
            }
            
            // Check if we need a new page
            if currentY > pageHeight - 200 {
                context.cgContext.restoreGState()
                context.beginPage()
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: contentX, y: 0)
                // Draw header on new page
                currentY = drawHeader(context: context, y: 0, width: contentWidth, pageWidth: pageWidth)
                currentY += 20 // Add spacing after header
            }
            
            // Ingredients from Logged Foods Section (always show)
            currentY = drawIngredientsSection(
                context: context,
                y: currentY,
                width: contentWidth,
                foodAnalyses: data.fedFoodAnalyses,
                pageHeight: pageHeight
            )
            currentY += 20
            
            // Health Events Section (always show, even if empty)
            // Check if we need a new page
            if currentY > pageHeight - 300 {
                context.cgContext.restoreGState()
                context.beginPage()
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: contentX, y: 0)
                // Draw header on new page
                currentY = drawHeader(context: context, y: 0, width: contentWidth, pageWidth: pageWidth)
                currentY += 20 // Add spacing after header
            }
            
            currentY = drawHealthEventsSection(
                context: context,
                y: currentY,
                width: contentWidth,
                events: data.healthEvents,
                pageHeight: pageHeight,
                pageWidth: pageWidth
            )
            currentY += 20
            
            // Check if we need a new page
            if currentY > pageHeight - 200 {
                context.cgContext.restoreGState()
                context.beginPage()
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: contentX, y: 0)
                // Draw header on new page
                currentY = drawHeader(context: context, y: 0, width: contentWidth, pageWidth: pageWidth)
                currentY += 20 // Add spacing after header
            }
            
            // Feeding History Section (always show)
            currentY = drawFeedingHistorySection(
                context: context,
                y: currentY,
                width: contentWidth,
                records: data.feedingRecords,
                pageHeight: pageHeight,
                data: data
            )
            currentY += 20
            
            // Check if we need a new page
            if currentY > pageHeight - 200 {
                context.cgContext.restoreGState()
                context.beginPage()
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: contentX, y: 0)
                // Draw header on new page
                currentY = drawHeader(context: context, y: 0, width: contentWidth, pageWidth: pageWidth)
                currentY += 20 // Add spacing after header
            }
            
            // Scan History Section (always show)
            currentY = drawScanHistorySection(
                context: context,
                y: currentY,
                width: contentWidth,
                scans: data.scanHistory,
                pageHeight: pageHeight
            )
            currentY += 20
            
            // Check if we need a new page
            if currentY > pageHeight - 200 {
                context.cgContext.restoreGState()
                context.beginPage()
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: contentX, y: 0)
                // Draw header on new page
                currentY = drawHeader(context: context, y: 0, width: contentWidth, pageWidth: pageWidth)
                currentY += 20 // Add spacing after header
            }
            
            // Daily Nutrition Summary Section (always show)
            currentY = drawDailySummarySection(
                context: context,
                y: currentY,
                width: contentWidth,
                summaries: data.dailySummaries,
                pageHeight: pageHeight
            )
            
            // Restore graphics state
            context.cgContext.restoreGState()
        }
        
        return pdfData
    }
    
    // MARK: - Drawing Methods
    
    /**
     * Draw header with app logo and name on every page
     * - Parameter context: PDF renderer context
     * - Parameter y: Starting Y position (in translated coordinates)
     * - Parameter width: Content width
     * - Parameter pageWidth: Full page width
     * - Returns: Y position after header (in translated coordinates)
     */
    private func drawHeader(context: UIGraphicsPDFRendererContext, y: CGFloat, width: CGFloat, pageWidth: CGFloat) -> CGFloat {
        let headerHeight: CGFloat = 50.0
        let logoSize: CGFloat = 40.0
        let margin: CGFloat = 72.0
        
        // Get current graphics context
        guard let cgContext = UIGraphicsGetCurrentContext() else {
            return y + headerHeight
        }
        
        // Save current state
        cgContext.saveGState()
        
        // Reset translation to draw in absolute page coordinates
        cgContext.translateBy(x: -margin, y: 0)
        
        // Draw in absolute page coordinates
        let headerY: CGFloat = 20.0 // Top margin from page edge
        
        // Load app logo from asset catalog
        if let logoImage = UIImage(named: "Branding/app-logo") {
            // Draw logo in top right (accounting for margin)
            let logoX = pageWidth - margin - logoSize
            let logoRect = CGRect(x: logoX, y: headerY, width: logoSize, height: logoSize)
            logoImage.draw(in: logoRect)
        }
        
        // Draw app name next to logo
        let appNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: textPrimary
        ]
        let appName = "SniffTest"
        let appNameSize = appName.size(withAttributes: appNameAttributes)
        let logoX = pageWidth - margin - logoSize
        let appNameX = logoX - appNameSize.width - 10 // 10 points spacing between name and logo
        let appNameRect = CGRect(x: appNameX, y: headerY + (logoSize - appNameSize.height) / 2, width: appNameSize.width, height: appNameSize.height)
        appName.draw(in: appNameRect, withAttributes: appNameAttributes)
        
        // Draw separator line below header
        cgContext.setStrokeColor(borderPrimary.cgColor)
        cgContext.setLineWidth(0.5)
        let separatorY = headerY + logoSize + 10
        cgContext.move(to: CGPoint(x: margin, y: separatorY))
        cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: separatorY))
        cgContext.strokePath()
        
        // Restore state
        cgContext.restoreGState()
        
        // Return Y position after header (in translated coordinates)
        // The header ends at absolute Y = headerY + logoSize + 10
        // In translated coordinates (accounting for margin translation), this is:
        return headerY + logoSize + 10 + 10 // Add some spacing
    }
    
    /**
     * Draw title section with pet name and generation date
     */
    private func drawTitleSection(context: UIGraphicsPDFRendererContext, y: CGFloat, width: CGFloat, petName: String, generatedDate: Date) -> CGFloat {
        var currentY = y
        
        // Get current graphics context
        guard let cgContext = UIGraphicsGetCurrentContext() else {
            return currentY
        }
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: primaryColor
        ]
        let title = "PET HEALTH REPORT"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(x: (width - titleSize.width) / 2, y: currentY, width: titleSize.width, height: titleSize.height)
        title.draw(in: titleRect, withAttributes: titleAttributes)
        currentY += titleSize.height + 10
        
        // Pet Name
        let petNameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: textPrimary
        ]
        let petNameText = "For: \(petName)"
        let petNameSize = petNameText.size(withAttributes: petNameAttributes)
        let petNameRect = CGRect(x: (width - petNameSize.width) / 2, y: currentY, width: petNameSize.width, height: petNameSize.height)
        petNameText.draw(in: petNameRect, withAttributes: petNameAttributes)
        currentY += petNameSize.height + 5
        
        // Generated Date
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: textSecondary
        ]
        let dateText = "Generated: \(dateFormatter.string(from: generatedDate))"
        let dateSize = dateText.size(withAttributes: dateAttributes)
        let dateRect = CGRect(x: (width - dateSize.width) / 2, y: currentY, width: dateSize.width, height: dateSize.height)
        dateText.draw(in: dateRect, withAttributes: dateAttributes)
        currentY += dateSize.height + 20
        
        // Separator line
        cgContext.setStrokeColor(borderPrimary.cgColor)
        cgContext.setLineWidth(1.0)
        cgContext.move(to: CGPoint(x: 0, y: currentY))
        cgContext.addLine(to: CGPoint(x: width, y: currentY))
        cgContext.strokePath()
        currentY += 10
        
        return currentY
    }
    
    /**
     * Draw pet information section
     */
    private func drawPetInformationSection(context: UIGraphicsPDFRendererContext, y: CGFloat, width: CGFloat, pet: Pet) -> CGFloat {
        var currentY = y
        
        // Section Title
        currentY = drawSectionTitle("PET INFORMATION", y: currentY, width: width)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: textPrimary
        ]
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: primaryColor
        ]
        
        // Name
        drawLabelValue(label: "Name:", value: pet.name, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        
        // Species
        drawLabelValue(label: "Species:", value: pet.species.displayName, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        
        // Breed
        if let breed = pet.breed, !breed.isEmpty {
            drawLabelValue(label: "Breed:", value: breed, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        }
        
        // Age
        if let ageDescription = pet.ageDescription {
            drawLabelValue(label: "Age:", value: ageDescription, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        }
        
        // Weight
        if let weightKg = pet.weightKg {
            let weightText = String(format: "%.1f kg (%.1f lbs)", weightKg, weightKg * 2.20462)
            drawLabelValue(label: "Weight:", value: weightText, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        }
        
        // Activity Level
        if let activityLevel = pet.activityLevel {
            drawLabelValue(label: "Activity Level:", value: activityLevel.displayName, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        }
        
        // Life Stage
        drawLabelValue(label: "Life Stage:", value: pet.lifeStage.displayName, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        
        // Veterinary Contact
        if let vetName = pet.vetName, !vetName.isEmpty {
            drawLabelValue(label: "Veterinarian:", value: vetName, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        }
        
        if let vetPhone = pet.vetPhone, !vetPhone.isEmpty {
            drawLabelValue(label: "Vet Phone:", value: vetPhone, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        }
        
        return currentY
    }
    
    /**
     * Draw nutritional requirements section
     */
    private func drawNutritionalRequirementsSection(context: UIGraphicsPDFRendererContext, y: CGFloat, width: CGFloat, requirements: PetNutritionalRequirements) -> CGFloat {
        var currentY = y
        
        // Section Title
        currentY = drawSectionTitle("NUTRITIONAL REQUIREMENTS", y: currentY, width: width)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: textPrimary
        ]
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: primaryColor
        ]
        
        // Daily Calories
        let caloriesText = String(format: "%.0f kcal", requirements.dailyCalories)
        drawLabelValue(label: "Daily Calorie Goal:", value: caloriesText, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        
        // Protein
        let proteinText = String(format: "%.1f%%", requirements.proteinPercentage)
        drawLabelValue(label: "Protein Requirement:", value: proteinText, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        
        // Fat
        let fatText = String(format: "%.1f%%", requirements.fatPercentage)
        drawLabelValue(label: "Fat Requirement:", value: fatText, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        
        // Fiber
        let fiberText = String(format: "%.1f%%", requirements.fiberPercentage)
        drawLabelValue(label: "Fiber Requirement:", value: fiberText, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        
        // Life Stage
        drawLabelValue(label: "Life Stage:", value: requirements.lifeStage.displayName, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        
        // Activity Level
        drawLabelValue(label: "Activity Level:", value: requirements.activityLevel.displayName, y: &currentY, width: width, labelAttributes: labelAttributes, valueAttributes: attributes)
        
        return currentY
    }
    
    /**
     * Draw sensitivities section
     */
    private func drawSensitivitiesSection(context: UIGraphicsPDFRendererContext, y: CGFloat, width: CGFloat, sensitivities: [String]) -> CGFloat {
        var currentY = y
        
        // Section Title
        currentY = drawSectionTitle("KNOWN FOOD SENSITIVITIES", y: currentY, width: width)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: textPrimary
        ]
        
        let sensitivityText = sensitivities.joined(separator: ", ")
        let boundingRect = sensitivityText.boundingRect(
            with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        sensitivityText.draw(in: CGRect(x: 0, y: currentY, width: width, height: boundingRect.height), withAttributes: attributes)
        currentY += boundingRect.height + 10
        
        return currentY
    }
    
    /**
     * Draw feeding history section
     */
    private func drawFeedingHistorySection(context: UIGraphicsPDFRendererContext, y: CGFloat, width: CGFloat, records: [FeedingRecord], pageHeight: CGFloat, data: VetReportData) -> CGFloat {
        var currentY = y
        
        // Section Title
        currentY = drawSectionTitle("RECENT FEEDING HISTORY (Last 30 Days)", y: currentY, width: width)
        
        if records.isEmpty {
            let noDataText = "None Logged"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 12),
                .foregroundColor: textSecondary
            ]
            noDataText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: attributes)
            currentY += 20
            return currentY
        }
        
        // Table Header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: primaryColor
        ]
        
        let rowHeight: CGFloat = 30
        let colWidths: [CGFloat] = [width * 0.25, width * 0.35, width * 0.20, width * 0.20]
        var colX: CGFloat = 0
        
        // Draw header
        "Date".draw(at: CGPoint(x: colX, y: currentY), withAttributes: headerAttributes)
        colX += colWidths[0]
        "Food".draw(at: CGPoint(x: colX, y: currentY), withAttributes: headerAttributes)
        colX += colWidths[1]
        "Amount".draw(at: CGPoint(x: colX, y: currentY), withAttributes: headerAttributes)
        colX += colWidths[2]
        "Time".draw(at: CGPoint(x: colX, y: currentY), withAttributes: headerAttributes)
        
        currentY += rowHeight
        
        // Draw records (limit to first 20 for readability)
        let displayRecords = Array(records.prefix(20))
        let recordAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: textPrimary
        ]
        
        for record in displayRecords {
            // Check if we need a new page
            if currentY > pageHeight - 100 {
                context.cgContext.restoreGState()
                context.beginPage()
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 72.0, y: 0)
                // Draw header on new page
                currentY = drawHeader(context: context, y: 0, width: width, pageWidth: 8.5 * 72.0)
                currentY += 20 // Add spacing after header
            }
            
            colX = 0
            dateFormatter.string(from: record.feedingTime).draw(at: CGPoint(x: colX, y: currentY), withAttributes: recordAttributes)
            colX += colWidths[0]
            
            // Get food name from food analysis
            let foodName = getFoodName(for: record.foodAnalysisId, from: data.fedFoodAnalyses)
            foodName.draw(at: CGPoint(x: colX, y: currentY), withAttributes: recordAttributes)
            colX += colWidths[1]
            
            String(format: "%.0fg", record.amountGrams).draw(at: CGPoint(x: colX, y: currentY), withAttributes: recordAttributes)
            colX += colWidths[2]
            dateTimeFormatter.string(from: record.feedingTime).draw(at: CGPoint(x: colX, y: currentY), withAttributes: recordAttributes)
            
            currentY += rowHeight
        }
        
        if records.count > 20 {
            let moreText = "... and \(records.count - 20) more records"
            let moreAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: textSecondary
            ]
            moreText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: moreAttributes)
            currentY += 20
        }
        
        return currentY
    }
    
    /**
     * Draw scan history section
     */
    private func drawScanHistorySection(context: UIGraphicsPDFRendererContext, y: CGFloat, width: CGFloat, scans: [Scan], pageHeight: CGFloat) -> CGFloat {
        var currentY = y
        
        // Section Title
        currentY = drawSectionTitle("PRODUCT SAFETY ASSESSMENTS (Last 30 Days)", y: currentY, width: width)
        
        if scans.isEmpty {
            let noDataText = "None Logged"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 12),
                .foregroundColor: textSecondary
            ]
            noDataText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: attributes)
            currentY += 20
            return currentY
        }
        
        let recordAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: textPrimary
        ]
        
        let _: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: primaryColor
        ]
        
        // Display scans (limit to first 15 for readability)
        let displayScans = Array(scans.prefix(15))
        
        for scan in displayScans {
            // Check if we need a new page
            if currentY > pageHeight - 100 {
                context.cgContext.restoreGState()
                context.beginPage()
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 72.0, y: 0)
                // Draw header on new page
                currentY = drawHeader(context: context, y: 0, width: width, pageWidth: 8.5 * 72.0)
                currentY += 20 // Add spacing after header
            }
            
            // Date
            let dateText = dateFormatter.string(from: scan.createdAt)
            dateText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: recordAttributes)
            
            // Product Name
            let productName = scan.result?.productName ?? "Unknown Product"
            productName.draw(at: CGPoint(x: width * 0.25, y: currentY), withAttributes: recordAttributes)
            
            // Safety Status with semantic colors
            if let result = scan.result {
                // Determine color based on safety status
                let safetyColor: UIColor
                switch result.overallSafety.lowercased() {
                case "safe":
                    safetyColor = safeColor
                case "caution":
                    safetyColor = warningColor
                case "unsafe", "dangerous":
                    safetyColor = errorColor
                default:
                    safetyColor = textPrimary
                }
                
                let safetyTextAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: safetyColor
                ]
                let safetyText = result.safetyDisplayName
                safetyText.draw(at: CGPoint(x: width * 0.65, y: currentY), withAttributes: safetyTextAttributes)
                
                // Unsafe ingredients count with warning color
                if !result.unsafeIngredients.isEmpty {
                    let warningTextAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 10),
                        .foregroundColor: warmCoral
                    ]
                    let warningText = "⚠️ \(result.unsafeIngredients.count) unsafe ingredient(s)"
                    warningText.draw(at: CGPoint(x: 0, y: currentY + 15), withAttributes: warningTextAttributes)
                    currentY += 15
                }
            } else {
                "Processing".draw(at: CGPoint(x: width * 0.65, y: currentY), withAttributes: recordAttributes)
            }
            
            currentY += 20
        }
        
        if scans.count > 15 {
            let moreText = "... and \(scans.count - 15) more scans"
            let moreAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: textSecondary
            ]
            moreText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: moreAttributes)
            currentY += 20
        }
        
        return currentY
    }
    
    /**
     * Draw daily nutrition summary section
     */
    private func drawDailySummarySection(context: UIGraphicsPDFRendererContext, y: CGFloat, width: CGFloat, summaries: [DailyNutritionSummary], pageHeight: CGFloat) -> CGFloat {
        var currentY = y
        
        // Section Title
        currentY = drawSectionTitle("DAILY NUTRITION SUMMARY (Last 30 Days)", y: currentY, width: width)
        
        if summaries.isEmpty {
            let noDataText = "None Logged"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 12),
                .foregroundColor: textSecondary
            ]
            noDataText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: attributes)
            currentY += 20
            return currentY
        }
        
        // Display summaries (limit to first 10 for readability)
        let displaySummaries = Array(summaries.prefix(10))
        let recordAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: textPrimary
        ]
        
        for summary in displaySummaries {
            // Check if we need a new page
            if currentY > pageHeight - 100 {
                context.cgContext.restoreGState()
                context.beginPage()
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 72.0, y: 0)
                // Draw header on new page
                currentY = drawHeader(context: context, y: 0, width: width, pageWidth: 8.5 * 72.0)
                currentY += 20 // Add spacing after header
            }
            
            let dateText = dateFormatter.string(from: summary.date)
            let summaryText = "\(dateText): \(String(format: "%.0f", summary.totalCalories)) kcal, \(summary.feedingCount) feeding(s)"
            summaryText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: recordAttributes)
            currentY += 18
        }
        
        if summaries.count > 10 {
            let moreText = "... and \(summaries.count - 10) more summaries"
            let moreAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: textSecondary
            ]
            moreText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: moreAttributes)
            currentY += 20
        }
        
        return currentY
    }
    
    /**
     * Draw health events section
     */
    private func drawHealthEventsSection(context: UIGraphicsPDFRendererContext, y: CGFloat, width: CGFloat, events: [HealthEvent], pageHeight: CGFloat, pageWidth: CGFloat) -> CGFloat {
        var currentY = y
        
        // Section Title
        currentY = drawSectionTitle("HEALTH EVENTS (Last 30 Days)", y: currentY, width: width)
        
        if events.isEmpty {
            let noDataText = "None Logged"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 12),
                .foregroundColor: textSecondary
            ]
            noDataText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: attributes)
            currentY += 20
            return currentY
        }
        
        let recordAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: textPrimary
        ]
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: primaryColor
        ]
        
        // Display events (limit to first 20 for readability)
        let displayEvents = Array(events.prefix(20))
        
        for event in displayEvents {
            // Check if we need a new page
            if currentY > pageHeight - 100 {
                context.cgContext.restoreGState()
                context.beginPage()
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 72.0, y: 0)
                // Draw header on new page
                currentY = drawHeader(context: context, y: 0, width: width, pageWidth: pageWidth)
                currentY += 20 // Add spacing after header
            }
            
            // Date
            let dateText = dateFormatter.string(from: event.eventDate)
            dateText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: recordAttributes)
            
            // Event Type
            event.eventType.displayName.draw(at: CGPoint(x: width * 0.2, y: currentY), withAttributes: headerAttributes)
            
            // Title
            event.title.draw(at: CGPoint(x: width * 0.4, y: currentY), withAttributes: recordAttributes)
            
            // Severity
            let severityText = "Severity: \(event.severityDescription)"
            severityText.draw(at: CGPoint(x: width * 0.7, y: currentY), withAttributes: recordAttributes)
            
            currentY += 18
            
            // Notes if available
            if let notes = event.notes, !notes.isEmpty {
                let notesText = "Notes: \(notes)"
                let notesRect = notesText.boundingRect(
                    with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: recordAttributes,
                    context: nil
                )
                notesText.draw(in: CGRect(x: 0, y: currentY, width: width, height: notesRect.height), withAttributes: recordAttributes)
                currentY += notesRect.height + 5
            }
            
            currentY += 5
        }
        
        if events.count > 20 {
            let moreText = "... and \(events.count - 20) more events"
            let moreAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: textSecondary
            ]
            moreText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: moreAttributes)
            currentY += 20
        }
        
        return currentY
    }
    
    // MARK: - Helper Methods
    
    /**
     * Draw section title
     */
    private func drawSectionTitle(_ title: String, y: CGFloat, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: primaryColor
        ]
        let titleSize = title.size(withAttributes: attributes)
        let titleRect = CGRect(x: 0, y: y, width: width, height: titleSize.height)
        title.draw(in: titleRect, withAttributes: attributes)
        return y + titleSize.height + 10
    }
    
    /**
     * Draw label-value pair
     */
    private func drawLabelValue(label: String, value: String, y: inout CGFloat, width: CGFloat, labelAttributes: [NSAttributedString.Key: Any], valueAttributes: [NSAttributedString.Key: Any]) {
        let labelSize = label.size(withAttributes: labelAttributes)
        let valueSize = value.size(withAttributes: valueAttributes)
        
        let labelRect = CGRect(x: 0, y: y, width: width * 0.3, height: labelSize.height)
        label.draw(in: labelRect, withAttributes: labelAttributes)
        
        let valueRect = CGRect(x: width * 0.3, y: y, width: width * 0.7, height: valueSize.height)
        value.draw(in: valueRect, withAttributes: valueAttributes)
        
        y += max(max(labelSize.height, valueSize.height), 16)
    }
    
    /**
     * Get food name from food analysis ID
     * - Parameter foodAnalysisId: The food analysis ID
     * - Parameter foodAnalyses: Array of food analyses
     * - Returns: Food name or "Unknown Food"
     */
    private func getFoodName(for foodAnalysisId: String, from foodAnalyses: [FoodNutritionalAnalysis]) -> String {
        return foodAnalyses.first { $0.id == foodAnalysisId }?.foodName ?? "Unknown Food"
    }
    
    /**
     * Draw ingredients section showing all unique ingredients from logged foods
     * - Parameter context: PDF renderer context
     * - Parameter y: Starting Y position
     * - Parameter width: Content width
     * - Parameter foodAnalyses: Array of food analyses for foods that were fed
     * - Parameter pageHeight: Page height for pagination
     * - Returns: Y position after section
     */
    private func drawIngredientsSection(context: UIGraphicsPDFRendererContext, y: CGFloat, width: CGFloat, foodAnalyses: [FoodNutritionalAnalysis], pageHeight: CGFloat) -> CGFloat {
        var currentY = y
        
        // Section Title
        currentY = drawSectionTitle("INGREDIENTS FROM LOGGED FOODS", y: currentY, width: width)
        
        // Collect all unique ingredients from all fed foods (case-insensitive deduplication)
        var allIngredients: [String] = []
        var seenIngredients: Set<String> = []
        
        for foodAnalysis in foodAnalyses {
            for ingredient in foodAnalysis.ingredients {
                // Normalize ingredient name (trim whitespace)
                let normalized = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalized.isEmpty {
                    // Use lowercase for case-insensitive comparison
                    let lowercased = normalized.lowercased()
                    if !seenIngredients.contains(lowercased) {
                        seenIngredients.insert(lowercased)
                        // Store the original (properly capitalized) version
                        allIngredients.append(normalized)
                    }
                }
            }
        }
        
        // Sort ingredients alphabetically (case-insensitive)
        let sortedIngredients = allIngredients.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        
        if sortedIngredients.isEmpty {
            let noDataText = "None Logged"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 12),
                .foregroundColor: textSecondary
            ]
            noDataText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: attributes)
            currentY += 20
            return currentY
        }
        
        // Display ingredients in a comma-separated list format
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: textPrimary
        ]
        
        // Format ingredients as a comma-separated list
        let ingredientsText = sortedIngredients.joined(separator: ", ")
        
        // Calculate text size and wrap if needed
        let maxWidth = width
        let textRect = ingredientsText.boundingRect(
            with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        
        // Draw ingredients text with word wrapping
        let drawingRect = CGRect(x: 0, y: currentY, width: maxWidth, height: textRect.height)
        ingredientsText.draw(in: drawingRect, withAttributes: attributes)
        
        currentY += textRect.height + 10
        
        // Add count information
        let countText = "Total unique ingredients: \(sortedIngredients.count)"
        let countAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 10),
            .foregroundColor: textSecondary
        ]
        countText.draw(at: CGPoint(x: 0, y: currentY), withAttributes: countAttributes)
        currentY += 20
        
        return currentY
    }
}

