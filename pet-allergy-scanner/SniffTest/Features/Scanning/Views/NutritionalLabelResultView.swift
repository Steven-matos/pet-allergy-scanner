//
//  NutritionalLabelResultView.swift
//  SniffTest
//
//  View displayed after successfully scanning a nutritional label
//  Shows parsed nutritional information with editable fields
//

import SwiftUI

/**
 * View displayed after scanning nutritional label with OCR
 * Shows parsed nutritional information in user-friendly format
 * Allows editing of brand name and other details
 * Follows Trust & Nature design system
 */
struct NutritionalLabelResultView: View {
    let result: HybridScanResult
    let onAnalyzeForPet: () -> Void
    let onUploadToDatabase: (String, String, [String], ParsedNutrition) -> Void
    let onRetry: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var isAnimating = false
    @State private var editableBrand: String = ""
    @State private var editableProductName: String = ""
    @State private var editableIngredients: [String] = []
    @State private var parsedNutrition: ParsedNutrition
    
    init(result: HybridScanResult, onAnalyzeForPet: @escaping () -> Void, onUploadToDatabase: @escaping (String, String, [String], ParsedNutrition) -> Void, onRetry: @escaping () -> Void) {
        self.result = result
        self.onAnalyzeForPet = onAnalyzeForPet
        self.onUploadToDatabase = onUploadToDatabase
        self.onRetry = onRetry
        
        // Parse nutrition from OCR text
        let parsed = NutritionalLabelResultView.parseNutritionalInfo(from: result.ocrText)
        _parsedNutrition = State(initialValue: parsed)
        
        // Initialize editable fields
        let initialBrand = result.foodProduct?.brand ?? parsed.brand ?? ""
        let initialProductName = result.foodProduct?.name ?? parsed.productName ?? "Unknown Product"
        
        _editableBrand = State(initialValue: initialBrand)
        _editableProductName = State(initialValue: initialProductName)
        _editableIngredients = State(initialValue: parsed.ingredients)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Header with success indicator
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    // Success icon with Trust & Nature styling
                    ZStack {
                        Circle()
                            .fill(ModernDesignSystem.Colors.softCream)
                            .frame(width: 80, height: 80)
                            .shadow(color: Color.black.opacity(0.1), radius: 8)
                        
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 48))
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                            .scaleEffect(isAnimating ? 1.0 : 0.8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.5), value: isAnimating)
                    }
                    .padding(.bottom, ModernDesignSystem.Spacing.sm)
                    
                    // Title
                    VStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Label Scanned!")
                            .font(ModernDesignSystem.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text("Review and edit the information below")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    
                    // Barcode (if detected)
                    if let barcode = result.barcode {
                        Text("Barcode: \(barcode.value)")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .padding(.horizontal, ModernDesignSystem.Spacing.md)
                            .padding(.vertical, ModernDesignSystem.Spacing.xs)
                            .background(ModernDesignSystem.Colors.softCream)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, ModernDesignSystem.Spacing.xl)
                
                // Scan quality indicator
                ScanQualityCard(confidence: Double(result.confidence))
                    .padding(.horizontal, ModernDesignSystem.Spacing.md)
                
                // Editable product information
                EditableProductInfoCard(
                    productName: $editableProductName,
                    brand: $editableBrand
                )
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                
                // Ingredients section
                EditableIngredientsCard(ingredients: $editableIngredients)
                    .padding(.horizontal, ModernDesignSystem.Spacing.md)
                
                // Guaranteed Analysis (Macronutrients)
                if parsedNutrition.hasMacronutrients {
                    GuaranteedAnalysisCard(nutrition: parsedNutrition)
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                }
                
                // Calorie information
                if parsedNutrition.calories != nil || parsedNutrition.caloriesPerTreat != nil {
                    ParsedCalorieInfoCard(
                        calories: parsedNutrition.calories,
                        caloriesPerTreat: parsedNutrition.caloriesPerTreat
                    )
                    .padding(.horizontal, ModernDesignSystem.Spacing.md)
                }
                
                // Additional nutritional values
                if parsedNutrition.hasAdditionalNutrients {
                    AdditionalNutrientsCard(nutrition: parsedNutrition)
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                }
                
                Spacer()
                
                // Action buttons with Trust & Nature styling
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    // Primary action: Analyze for pet
                    Button(action: {
                        dismiss()
                        onAnalyzeForPet()
                    }) {
                        HStack(spacing: ModernDesignSystem.Spacing.sm) {
                            Image(systemName: "pawprint.fill")
                                .font(ModernDesignSystem.Typography.title3)
                            Text("Analyze for My Pet")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ModernDesignSystem.Spacing.md)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ModernDesignSystem.Colors.primary,
                                    ModernDesignSystem.Colors.primary.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
                        .shadow(color: ModernDesignSystem.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    
                    // Secondary action: Upload to database
                    Button(action: {
                        dismiss()
                        onUploadToDatabase(editableProductName, editableBrand, editableIngredients, parsedNutrition)
                    }) {
                        HStack(spacing: ModernDesignSystem.Spacing.sm) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Upload to Database")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ModernDesignSystem.Spacing.md)
                        .background(ModernDesignSystem.Colors.softCream)
                        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .stroke(ModernDesignSystem.Colors.primary, lineWidth: 2)
                        )
                    }
                    
                    // Tertiary action: Retry
                    Button(action: {
                        dismiss()
                        onRetry()
                    }) {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Rescan Label")
                                .font(ModernDesignSystem.Typography.caption)
                        }
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.bottom, ModernDesignSystem.Spacing.xl)
            }
        }
        .background(Color.white)
        .onAppear {
            
            isAnimating = true
        }
    }
    
    /**
     * Parse nutritional information from OCR text
     * Extracts ingredients, macronutrients, calories, and other values
     * Includes spell-checking and correction of common OCR errors
     */
    static func parseNutritionalInfo(from text: String) -> ParsedNutrition {
        // First, run spell-check and correction on the OCR text
        let correctedText = OCRSpellChecker.correctText(text)
        
        var nutrition = ParsedNutrition()
        
        let lines = correctedText.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
            
            // Extract product name (usually first non-empty line)
            if nutrition.productName == nil && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                nutrition.productName = line.trimmingCharacters(in: .whitespaces)
            }
            
            // Extract brand
            if lowercased.contains("brand") || lowercased.contains("by ") {
                nutrition.brand = line.replacingOccurrences(of: "brand:", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "by ", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespaces)
            }
            
            // Extract ingredients
            if lowercased.contains("ingredient") {
                // Get the rest of the text after "ingredients"
                let ingredientText = lines[index...].joined(separator: " ")
                let components = ingredientText.components(separatedBy: ":")
                if components.count > 1 {
                    let ingredientList = components[1].components(separatedBy: ",")
                    nutrition.ingredients = ingredientList.map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            }
            
            // Extract protein
            if lowercased.contains("protein") {
                if let value = extractPercentage(from: line) {
                    nutrition.protein = value
                }
            }
            
            // Extract fat
            if lowercased.contains("fat") && !lowercased.contains("saturated") {
                if let value = extractPercentage(from: line) {
                    nutrition.fat = value
                }
            }
            
            // Extract fiber
            if lowercased.contains("fiber") || lowercased.contains("fibre") {
                if let value = extractPercentage(from: line) {
                    nutrition.fiber = value
                }
            }
            
            // Extract moisture
            if lowercased.contains("moisture") {
                if let value = extractPercentage(from: line) {
                    nutrition.moisture = value
                }
            }
            
            // Extract ash
            if lowercased.contains("ash") {
                if let value = extractPercentage(from: line) {
                    nutrition.ash = value
                }
            }
            
            // Extract carbohydrates
            if lowercased.contains("carbohydrate") || lowercased.contains("carbs") {
                if let value = extractPercentage(from: line) {
                    nutrition.carbohydrates = value
                }
            }
            
            // Extract calories (capture both kcal/kg and per-treat values)
            if lowercased.contains("calorie") || lowercased.contains("kcal") {
                if let value = extractCalories(from: line) {
                    let isKcalPerKg = lowercased.contains("kcal/kg") || lowercased.contains("kcal / kg") || 
                                     lowercased.contains("per kg") || lowercased.contains("/kg")
                    let isPerTreat = lowercased.contains("per treat") || lowercased.contains("per serving") || 
                                    lowercased.contains("per piece") || lowercased.contains("per cup")
                    
                    if isKcalPerKg {
                        // This is the standardized kcal/kg value (metabolizable energy)
                        nutrition.calories = value
                    } else if isPerTreat {
                        // This is the per-treat/serving value
                        nutrition.caloriesPerTreat = value
                    } else if nutrition.calories == nil {
                        // Fallback: use any calorie value if we don't have kcal/kg yet
                        nutrition.calories = value
                    }
                }
            }
            
            // Extract sodium
            if lowercased.contains("sodium") {
                if let value = extractPercentage(from: line) {
                    nutrition.sodium = value
                }
            }
            
            // Extract calcium
            if lowercased.contains("calcium") {
                if let value = extractPercentage(from: line) {
                    nutrition.calcium = value
                }
            }
            
            // Extract phosphorus
            if lowercased.contains("phosphorus") {
                if let value = extractPercentage(from: line) {
                    nutrition.phosphorus = value
                }
            }
        }
        
        return nutrition
    }
    
    /**
     * Extract percentage value from text
     */
    private static func extractPercentage(from text: String) -> Double? {
        let pattern = #"(\d+\.?\d*)\s*%"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return Double(text[range])
        }
        return nil
    }
    
    /**
     * Extract numeric value from text
     */
    private static func extractNumber(from text: String) -> Double? {
        let pattern = #"(\d+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return Double(text[range])
        }
        return nil
    }
    
    /**
     * Extract calorie value from text
     * Prioritizes kcal/kg format over per-treat or per-serving values
     * 
     * Examples:
     * - "3013 kcal/kg" → 3013
     * - "3,013 kcal/kg" → 3013
     * - "3 013 kcal/kg" → 3013
     * - "16 kcal per treat" → 16 (only if no kcal/kg found)
     */
    private static func extractCalories(from text: String) -> Double? {
        let lowercased = text.lowercased()
        
        // Priority 1: Look for kcal/kg pattern (metabolizable energy)
        // Pattern matches: "3013 kcal/kg", "3,013 kcal/kg", "3 013 kcal/kg"
        let kcalPerKgPatterns = [
            #"(\d[\d\s,]*\d|\d+)\s*kcal\s*/\s*kg"#,  // 3013 kcal/kg or 3,013 kcal/kg
            #"(\d[\d\s,]*\d|\d+)\s*kcal\s*per\s*kg"#, // 3013 kcal per kg
            #"(\d[\d\s,]*\d|\d+)\s*kcal\s*\/\s*kilogram"#, // 3013 kcal/kilogram
        ]
        
        for pattern in kcalPerKgPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                // Extract the number and remove spaces/commas
                let numberString = text[range]
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: ",", with: "")
                if let value = Double(numberString) {
                    return value
                }
            }
        }
        
        // Priority 2: Look for ME (Metabolizable Energy) notation
        // Pattern: "ME: 3013 kcal/kg" or "ME (calculated): 3013 kcal/kg"
        let mePattern = #"me[^:]*:\s*(\d[\d\s,]*\d|\d+)"#
        if let regex = try? NSRegularExpression(pattern: mePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            let numberString = text[range]
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: "")
            if let value = Double(numberString) {
                return value
            }
        }
        
        // Priority 3: Look for any calorie value with "per kg" or "/kg"
        if lowercased.contains("per kg") || lowercased.contains("/kg") {
            let pattern = #"(\d[\d\s,]*\d|\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let numberString = text[range]
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: ",", with: "")
                if let value = Double(numberString) {
                    return value
                }
            }
        }
        
        // Priority 4: Fallback to any number (per treat, per serving, etc.)
        // Only used if no kcal/kg pattern found
        return extractNumber(from: text)
    }
}

// MARK: - Data Model

/**
 * Parsed nutritional information structure
 */
struct ParsedNutrition {
    var productName: String?
    var brand: String?
    var ingredients: [String] = []
    var protein: Double?
    var fat: Double?
    var fiber: Double?
    var moisture: Double?
    var ash: Double?
    var carbohydrates: Double?
    var calories: Double?  // kcal/kg (metabolizable energy)
    var caloriesPerTreat: Double?  // kcal per treat/serving
    var sodium: Double?
    var calcium: Double?
    var phosphorus: Double?
    
    var hasMacronutrients: Bool {
        protein != nil || fat != nil || fiber != nil || moisture != nil || ash != nil
    }
    
    var hasAdditionalNutrients: Bool {
        carbohydrates != nil || sodium != nil || calcium != nil || phosphorus != nil
    }
}

// MARK: - Supporting Cards

/**
 * Card showing scan quality/confidence
 */
struct ScanQualityCard: View {
    let confidence: Double
    
    private var qualityLevel: (text: String, color: Color) {
        switch confidence {
        case 0.8...1.0:
            return ("Excellent", ModernDesignSystem.Colors.safe)
        case 0.6..<0.8:
            return ("Good", ModernDesignSystem.Colors.primary)
        case 0.4..<0.6:
            return ("Fair", ModernDesignSystem.Colors.goldenYellow)
        default:
            return ("Limited", ModernDesignSystem.Colors.error)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(qualityLevel.color)
                Text("Scan Quality")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text(qualityLevel.text)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(qualityLevel.color)
                    .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                    .background(qualityLevel.color.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ModernDesignSystem.Colors.softCream)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(qualityLevel.color)
                        .frame(width: geometry.size.width * confidence, height: 8)
                }
            }
            .frame(height: 8)
            
            Text("\(Int(confidence * 100))% confidence")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
}

/**
 * Editable product information card
 */
struct EditableProductInfoCard: View {
    @Binding var productName: String
    @Binding var brand: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("Product Information")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                // Product Name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Product Name")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    TextField("Enter product name", text: $productName)
                        .font(ModernDesignSystem.Typography.body)
                        .padding(ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.softCream)
                        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small))
                }
                
                // Brand Name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    HStack {
                        Text("Brand")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        Text("Tap to edit")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                    }
                    
                    TextField("Enter brand name", text: $brand)
                        .font(ModernDesignSystem.Typography.body)
                        .padding(ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.softCream)
                        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small))
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
}

/**
 * Editable ingredients card
 * Allows users to edit, add, and remove ingredients
 */
struct EditableIngredientsCard: View {
    @Binding var ingredients: [String]
    @State private var isExpanded = false
    @State private var editingIndex: Int?
    @State private var newIngredient: String = ""
    @State private var showingAddField = false
    
    private var displayedIndices: [Int] {
        if isExpanded {
            return Array(ingredients.indices)
        } else {
            return Array(ingredients.prefix(5).indices)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            headerView
            ingredientsListView
            actionButtonsView
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "list.bullet")
                .foregroundColor(ModernDesignSystem.Colors.primary)
            Text("Ingredients")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Image(systemName: "pencil")
                .font(.caption2)
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Tap to edit")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Spacer()
            
            Text("\(ingredients.count) items")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
    }
    
    private var ingredientsListView: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            ForEach(displayedIndices, id: \.self) { index in
                EditableIngredientRow(
                    index: index,
                    ingredient: $ingredients[index],
                    isEditing: editingIndex == index,
                    onEdit: { editingIndex = index },
                    onFinishEditing: { editingIndex = nil },
                    onDelete: {
                        withAnimation {
                            let _ = ingredients.remove(at: index)
                        }
                    }
                )
            }
            
            if showingAddField {
                AddIngredientRow(
                    newIngredient: $newIngredient,
                    nextIndex: ingredients.count + 1,
                    onAdd: {
                        if !newIngredient.trimmingCharacters(in: .whitespaces).isEmpty {
                            withAnimation {
                                ingredients.append(newIngredient)
                                newIngredient = ""
                                showingAddField = false
                            }
                        }
                    },
                    onCancel: {
                        newIngredient = ""
                        showingAddField = false
                    }
                )
            }
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            if !showingAddField {
                Button(action: { showingAddField = true }) {
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Ingredient")
                    }
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
            
            if ingredients.count > 5 {
                Button(action: { isExpanded.toggle() }) {
                    HStack {
                        Text(isExpanded ? "Show Less" : "Show All (\(ingredients.count))")
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    }
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
        }
        .padding(.top, ModernDesignSystem.Spacing.xs)
    }
}

/**
 * Individual editable ingredient row with edit/delete capabilities
 */
struct EditableIngredientRow: View {
    let index: Int
    @Binding var ingredient: String
    let isEditing: Bool
    let onEdit: () -> Void
    let onFinishEditing: () -> Void
    let onDelete: () -> Void
    
    @State private var showSpellingSuggestion = false
    @State private var spellingSuggestion: String?
    
    var body: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Text("\(index + 1).")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .frame(width: 20, alignment: .trailing)
                    
                    TextField("Ingredient", text: $ingredient)
                        .font(ModernDesignSystem.Typography.body)
                        .padding(.horizontal, ModernDesignSystem.Spacing.xs)
                        .padding(.vertical, 4)
                        .background(ModernDesignSystem.Colors.softCream)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .onChange(of: ingredient) {
                            checkSpelling(ingredient)
                        }
                    
                    Button(action: {
                        // Apply spell correction before finishing
                        ingredient = OCRSpellChecker.correctText(ingredient)
                        onFinishEditing()
                    }) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.safe)
                    }
                }
                
                // Spelling suggestion banner
                if showSpellingSuggestion, let suggestion = spellingSuggestion {
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption2)
                            .foregroundColor(ModernDesignSystem.Colors.warning)
                        
                        Text("Did you mean ")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        +
                        Text(suggestion)
                            .font(ModernDesignSystem.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        +
                        Text("?")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Button("Use") {
                            ingredient = suggestion
                            showSpellingSuggestion = false
                        }
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                    }
                    .padding(.leading, 24)
                    .padding(.vertical, 2)
                }
            }
        } else {
            HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.xs) {
                Text("\(index + 1).")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(width: 20, alignment: .trailing)
                
                Text(ingredient)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .font(.caption)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(.caption)
                        .foregroundColor(ModernDesignSystem.Colors.error)
                }
            }
        }
    }
    
    /**
     * Check spelling as user types and show suggestions
     */
    private func checkSpelling(_ text: String) {
        // Only check individual words
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        // If it's likely misspelled, offer suggestion
        if OCRSpellChecker.isLikelyMisspelled(trimmed) {
            if let suggestion = OCRSpellChecker.suggestion(for: trimmed) {
                spellingSuggestion = suggestion
                showSpellingSuggestion = true
                return
            }
        }
        
        // Hide suggestion if not needed
        showSpellingSuggestion = false
        spellingSuggestion = nil
    }
}

/**
 * Add new ingredient row
 */
struct AddIngredientRow: View {
    @Binding var newIngredient: String
    let nextIndex: Int
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.xs) {
            Text("\(nextIndex).")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .frame(width: 20, alignment: .trailing)
            
            TextField("New ingredient", text: $newIngredient)
                .font(ModernDesignSystem.Typography.body)
                .padding(.horizontal, ModernDesignSystem.Spacing.xs)
                .padding(.vertical, 4)
                .background(ModernDesignSystem.Colors.softCream)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            
            Button(action: {
                // Auto-correct before adding
                newIngredient = OCRSpellChecker.correctText(newIngredient)
                onAdd()
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.safe)
            }
            
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.error)
            }
        }
    }
}

/**
 * Guaranteed Analysis card (Macronutrients)
 */
struct GuaranteedAnalysisCard: View {
    let nutrition: ParsedNutrition
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("Guaranteed Analysis")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.xs) {
                if let protein = nutrition.protein {
                    ColoredNutrientRow(name: "Crude Protein", value: protein, unit: "%", color: ModernDesignSystem.Colors.primary)
                }
                if let fat = nutrition.fat {
                    ColoredNutrientRow(name: "Crude Fat", value: fat, unit: "%", color: ModernDesignSystem.Colors.secondary)
                }
                if let fiber = nutrition.fiber {
                    ColoredNutrientRow(name: "Crude Fiber", value: fiber, unit: "%", color: ModernDesignSystem.Colors.safe)
                }
                if let moisture = nutrition.moisture {
                    ColoredNutrientRow(name: "Moisture", value: moisture, unit: "%", color: ModernDesignSystem.Colors.goldenYellow)
                }
                if let ash = nutrition.ash {
                    ColoredNutrientRow(name: "Ash", value: ash, unit: "%", color: ModernDesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
}

/**
 * Parsed calorie information card
 * Displays both metabolizable energy (kcal/kg) and per-treat values
 */
struct ParsedCalorieInfoCard: View {
    let calories: Double?  // kcal/kg (metabolizable energy)
    let caloriesPerTreat: Double?  // kcal per treat/serving
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                Text("Calorie Information")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                // Metabolizable Energy (kcal/kg) - Primary value
                if let calories = calories {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(formattedNumber(calories))")
                            .font(ModernDesignSystem.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        Text("kcal/kg")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Spacer()
                    }
                    
                    Text("Metabolizable Energy (ME)")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                // Per-treat value - Secondary value
                if let caloriesPerTreat = caloriesPerTreat {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(formattedNumber(caloriesPerTreat))")
                            .font(ModernDesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.secondary)
                        
                        Text("kcal per treat")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Spacer()
                    }
                    
                    Text("Practical feeding reference")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            
            // Helpful context
            if calories != nil && caloriesPerTreat != nil {
                Text("Both values help compare products and plan feeding")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            } else if calories != nil {
                Text("Standard measurement for pet food energy density")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            } else if caloriesPerTreat != nil {
                Text("Per-treat value for practical feeding")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
    
    /// Format numbers with comma for thousands separator
    private func formattedNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
    }
}

/**
 * Additional nutrients card
 */
struct AdditionalNutrientsCard: View {
    let nutrition: ParsedNutrition
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "pills.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("Additional Nutrients")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.xs) {
                if let carbs = nutrition.carbohydrates {
                    ColoredNutrientRow(name: "Carbohydrates", value: carbs, unit: "%", color: ModernDesignSystem.Colors.primary)
                }
                if let sodium = nutrition.sodium {
                    ColoredNutrientRow(name: "Sodium", value: sodium, unit: "%", color: ModernDesignSystem.Colors.secondary)
                }
                if let calcium = nutrition.calcium {
                    ColoredNutrientRow(name: "Calcium", value: calcium, unit: "%", color: ModernDesignSystem.Colors.safe)
                }
                if let phosphorus = nutrition.phosphorus {
                    ColoredNutrientRow(name: "Phosphorus", value: phosphorus, unit: "%", color: ModernDesignSystem.Colors.goldenYellow)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
}

/**
 * Nutrient row component with color indicator
 */
struct ColoredNutrientRow: View {
    let name: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(name)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Text(String(format: "%.1f%@", value, unit))
                .font(ModernDesignSystem.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.xs)
    }
}

#Preview {
    NutritionalLabelResultView(
        result: HybridScanResult(
            barcode: BarcodeResult(value: "1234567890", type: "EAN-13", confidence: 0.95, timestamp: Date()),
            productInfo: nil,
            foodProduct: nil,
            ocrText: """
            Premium Dog Food
            Brand: Acme Pet Foods
            Ingredients: Chicken, Rice, Vegetables, Vitamins
            Guaranteed Analysis:
            Crude Protein (min): 25%
            Crude Fat (min): 15%
            Crude Fiber (max): 4%
            Moisture (max): 10%
            Calories: 350 kcal/cup
            """,
            ocrAnalysis: nil,
            scanMethod: .ocrOnly,
            confidence: 0.85,
            processingTime: 1.2,
            lastCapturedImage: nil
        ),
        onAnalyzeForPet: {},
        onUploadToDatabase: { _, _, _, _ in },
        onRetry: {}
    )
}
