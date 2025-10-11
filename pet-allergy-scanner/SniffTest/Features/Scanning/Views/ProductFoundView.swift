//
//  ProductFoundView.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import SwiftUI

/**
 * View displayed when product is found in database with full information
 *
 * Shows product details and nutritional information
 * Allows user to proceed with pet safety analysis
 * Follows Trust & Nature design system
 */
struct ProductFoundView: View {
    let product: FoodProduct
    let onAnalyzeForPet: () -> Void
    let onCancel: () -> Void
    
    @State private var isAnimating = false
    @State private var showingFullIngredients = false
    
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
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                            .scaleEffect(isAnimating ? 1.0 : 0.8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.5), value: isAnimating)
                    }
                    .padding(.bottom, ModernDesignSystem.Spacing.sm)
                    
                    // Product name and brand
                    VStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Product Found!")
                            .font(ModernDesignSystem.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        if let brand = product.brand, !brand.isEmpty {
                            Text(brand)
                                .font(ModernDesignSystem.Typography.title3)
                                .foregroundColor(ModernDesignSystem.Colors.primary)
                        }
                        
                        Text(product.name)
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    
                    // Barcode
                    if let barcode = product.barcode {
                        Text("Barcode: \(barcode)")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .padding(.horizontal, ModernDesignSystem.Spacing.md)
                            .padding(.vertical, ModernDesignSystem.Spacing.xs)
                            .background(ModernDesignSystem.Colors.softCream)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, ModernDesignSystem.Spacing.xl)
                
                // Nutritional information cards (Issue #20: All 22 fields)
                if let nutritionalInfo = product.nutritionalInfo {
                    VStack(spacing: ModernDesignSystem.Spacing.md) {
                        // Data quality indicator (Issue #20)
                        DataQualityCard(nutritionalInfo: nutritionalInfo)
                        
                        // Macronutrients card
                        if nutritionalInfo.hasBasicMacros {
                            NutritionalMacrosCard(nutritionalInfo: nutritionalInfo)
                        }
                        
                        // Extended nutrition card (Issue #20: carbs, sugars, saturated fat, sodium)
                        if nutritionalInfo.hasExtendedNutrition {
                            ExtendedNutritionCard(nutritionalInfo: nutritionalInfo)
                        }
                        
                        // Ingredients card
                        if !nutritionalInfo.ingredients.isEmpty {
                            IngredientsCard(
                                ingredients: nutritionalInfo.ingredients,
                                isExpanded: $showingFullIngredients
                            )
                        }
                        
                        // Allergens card (if any)
                        if !nutritionalInfo.allergens.isEmpty {
                            AllergensCard(allergens: nutritionalInfo.allergens)
                        }
                        
                        // Additives card (Issue #20)
                        if nutritionalInfo.hasAdditives {
                            AdditivesCard(additives: nutritionalInfo.additives)
                        }
                        
                        // Vitamins card (Issue #20)
                        if nutritionalInfo.hasVitamins {
                            VitaminsCard(vitamins: nutritionalInfo.vitamins)
                        }
                        
                        // Minerals card (Issue #20)
                        if nutritionalInfo.hasMinerals {
                            MineralsCard(minerals: nutritionalInfo.minerals)
                        }
                        
                        // Source attribution (Issue #20)
                        SourceAttributionCard(nutritionalInfo: nutritionalInfo)
                    }
                    .padding(.horizontal, ModernDesignSystem.Spacing.md)
                } else {
                    // No nutritional info available
                    Text("Limited nutritional information available")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                }
                
                Spacer(minLength: ModernDesignSystem.Spacing.xl)
            }
        }
        .overlay(alignment: .bottom) {
            // Action buttons at bottom
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                // Primary action: Analyze for pet
                Button(action: onAnalyzeForPet) {
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
                
                // Cancel button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.vertical, ModernDesignSystem.Spacing.md)
            .background(
                Color.white
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -2)
            )
        }
        .background(Color.white)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }
    }
}

/**
 * Card displaying nutritional macros
 */
struct NutritionalMacrosCard: View {
    let nutritionalInfo: NutritionalInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card title
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("Nutritional Analysis")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            // Macro grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ModernDesignSystem.Spacing.sm) {
                if let protein = nutritionalInfo.proteinPercentage {
                    MacroItem(name: "Protein", value: protein, unit: "%")
                }
                if let fat = nutritionalInfo.fatPercentage {
                    MacroItem(name: "Fat", value: fat, unit: "%")
                }
                if let fiber = nutritionalInfo.fiberPercentage {
                    MacroItem(name: "Fiber", value: fiber, unit: "%")
                }
                if let moisture = nutritionalInfo.moisturePercentage {
                    MacroItem(name: "Moisture", value: moisture, unit: "%")
                }
                if let ash = nutritionalInfo.ashPercentage {
                    MacroItem(name: "Ash", value: ash, unit: "%")
                }
                if let calories = nutritionalInfo.caloriesPer100g {
                    MacroItem(name: "Calories", value: calories, unit: "/100g")
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
    }
}

/**
 * Individual macro nutrient item
 */
struct MacroItem: View {
    let name: String
    let value: Double
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            Text(name)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", value))
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(unit)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
        .padding(ModernDesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small))
    }
}

/**
 * Card displaying ingredients list
 */
struct IngredientsCard: View {
    let ingredients: [String]
    @Binding var isExpanded: Bool
    
    private var displayedIngredients: [String] {
        isExpanded ? ingredients : Array(ingredients.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card title
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "list.bullet")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("Ingredients")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(ingredients.count)")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            // Ingredients list
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                ForEach(displayedIngredients, id: \.self) { ingredient in
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Circle()
                            .fill(ModernDesignSystem.Colors.primary)
                            .frame(width: 4, height: 4)
                        
                        Text(ingredient)
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Spacer(minLength: 0)
                    }
                }
            }
            
            // Show more/less button
            if ingredients.count > 5 {
                Button(action: { isExpanded.toggle() }) {
                    Text(isExpanded ? "Show Less" : "Show All (\(ingredients.count))")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
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
    }
}

/**
 * Card displaying allergen warnings
 */
struct AllergensCard: View {
    let allergens: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card title
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                Text("Allergens")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            // Allergen tags
            FlowLayout(spacing: ModernDesignSystem.Spacing.xs) {
                ForEach(allergens, id: \.self) { allergen in
                    Text(allergen)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, ModernDesignSystem.Spacing.xs)
                        .background(ModernDesignSystem.Colors.goldenYellow.opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(ModernDesignSystem.Colors.goldenYellow, lineWidth: 1)
                        )
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
    }
}

/**
 * Simple flow layout for wrapping views
 */
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        
        for size in sizes {
            if currentWidth + size.width > (proposal.width ?? .infinity) {
                totalHeight += currentHeight + spacing
                currentWidth = size.width + spacing
                currentHeight = size.height
            } else {
                currentWidth += size.width + spacing
                currentHeight = max(currentHeight, size.height)
            }
        }
        
        totalHeight += currentHeight
        return CGSize(width: proposal.width ?? currentWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/**
 * Data quality indicator card (Issue #20)
 */
struct DataQualityCard: View {
    let nutritionalInfo: NutritionalInfo
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Quality icon
            Image(systemName: nutritionalInfo.qualityLevel.icon)
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(qualityColor)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text("Data Quality: \(nutritionalInfo.qualityLevel.rawValue)")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Completeness: \(Int(nutritionalInfo.dataQualityScore * 100))%")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Progress ring
            ZStack {
                Circle()
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: CGFloat(nutritionalInfo.dataQualityScore))
                    .stroke(qualityColor, lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
    
    private var qualityColor: Color {
        switch nutritionalInfo.qualityLevel {
        case .excellent:
            return .green
        case .good:
            return .blue
        case .fair:
            return .orange
        case .poor:
            return .gray
        }
    }
}

/**
 * Extended nutrition card (Issue #20: carbs, sugars, saturated fat, sodium)
 */
struct ExtendedNutritionCard: View {
    let nutritionalInfo: NutritionalInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card title
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("Extended Nutrition")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            // Extended nutrition grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ModernDesignSystem.Spacing.sm) {
                if let carbs = nutritionalInfo.carbohydratesPercentage {
                    MacroItem(name: "Carbohydrates", value: carbs, unit: "%")
                }
                if let sugars = nutritionalInfo.sugarsPercentage {
                    MacroItem(name: "Sugars", value: sugars, unit: "%")
                }
                if let saturatedFat = nutritionalInfo.saturatedFatPercentage {
                    MacroItem(name: "Saturated Fat", value: saturatedFat, unit: "%")
                }
                if let sodium = nutritionalInfo.sodiumPercentage {
                    MacroItem(name: "Sodium", value: sodium, unit: "%")
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
    }
}

/**
 * Additives card (Issue #20)
 */
struct AdditivesCard: View {
    let additives: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card title
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "flask.fill")
                    .foregroundColor(.orange)
                Text("Additives")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(additives.count)")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            // Additive tags
            FlowLayout(spacing: ModernDesignSystem.Spacing.xs) {
                ForEach(additives, id: \.self) { additive in
                    Text(additive)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, ModernDesignSystem.Spacing.xs)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.orange, lineWidth: 1)
                        )
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
    }
}

/**
 * Vitamins card (Issue #20)
 */
struct VitaminsCard: View {
    let vitamins: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card title
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "pills.fill")
                    .foregroundColor(.green)
                Text("Vitamins")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(vitamins.count)")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            // Vitamin tags
            FlowLayout(spacing: ModernDesignSystem.Spacing.xs) {
                ForEach(vitamins, id: \.self) { vitamin in
                    Text(vitamin)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, ModernDesignSystem.Spacing.xs)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.green, lineWidth: 1)
                        )
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
    }
}

/**
 * Minerals card (Issue #20)
 */
struct MineralsCard: View {
    let minerals: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card title
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "cube.fill")
                    .foregroundColor(.blue)
                Text("Minerals")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(minerals.count)")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            // Mineral tags
            FlowLayout(spacing: ModernDesignSystem.Spacing.xs) {
                ForEach(minerals, id: \.self) { mineral in
                    Text(mineral)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, ModernDesignSystem.Spacing.xs)
                        .background(Color.blue.opacity(0.2))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.blue, lineWidth: 1)
                        )
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
    }
}

/**
 * Source attribution card (Issue #20)
 */
struct SourceAttributionCard: View {
    let nutritionalInfo: NutritionalInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                Image(systemName: "doc.text.fill")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text("Source: \(nutritionalInfo.source.isEmpty ? "Unknown" : nutritionalInfo.source)")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                Image(systemName: "clock.fill")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Text("Updated: \(nutritionalInfo.formattedLastUpdated)")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
        .padding(ModernDesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ModernDesignSystem.Colors.softCream.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small))
    }
}

#Preview {
    ProductFoundView(
        product: FoodProduct(
            id: "1",
            name: "Premium Dog Food",
            brand: "Pet Nutrition Co",
            barcode: "1234567890123",
            nutritionalInfo: NutritionalInfo(
                caloriesPer100g: 350,
                proteinPercentage: 26.0,
                fatPercentage: 15.0,
                fiberPercentage: 4.0,
                moisturePercentage: 10.0,
                ashPercentage: 7.0,
                carbohydratesPercentage: 38.0,
                sugarsPercentage: nil,
                saturatedFatPercentage: nil,
                sodiumPercentage: nil,
                ingredients: ["Chicken", "Brown Rice", "Vegetables", "Fish Oil", "Vitamins", "Minerals"],
                allergens: ["Fish", "Soy"],
                additives: [],
                vitamins: [],
                minerals: [],
                source: "OpenPetFoodFacts",
                externalId: "123",
                dataQualityScore: 0.9,
                lastUpdated: "2025-01-01",
                nutrientLevels: [:],
                packagingInfo: [:],
                manufacturingInfo: [:]
            ),
            category: "Dog Food",
            description: nil,
            createdAt: Date(),
            updatedAt: Date()
        ),
        onAnalyzeForPet: {},
        onCancel: {}
    )
}


