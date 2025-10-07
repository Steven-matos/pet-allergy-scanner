//
//  ScanAccessibility.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import SwiftUI

/**
 * Accessibility helpers and extensions for scan views
 * 
 * Ensures all scanning components meet WCAG 2.1 AA standards and provide
 * excellent accessibility experience for users with disabilities.
 */

// MARK: - Accessibility Extensions

extension View {
    /**
     * Adds comprehensive accessibility support for scan actions
     */
    func scanActionAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = .isButton
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "Tap to perform scan action")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityIdentifier("scanAction_\(label.replacingOccurrences(of: " ", with: "_"))")
    }
    
    /**
     * Adds accessibility support for scan results
     */
    func scanResultAccessibility(
        safety: String,
        confidence: Double? = nil,
        ingredientCount: Int? = nil
    ) -> some View {
        var accessibilityLabel = "Scan result: \(safety)"
        
        if let confidence = confidence {
            accessibilityLabel += ", confidence: \(Int(confidence * 100)) percent"
        }
        
        if let count = ingredientCount {
            accessibilityLabel += ", \(count) ingredients analyzed"
        }
        
        return self
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("scanResult_\(safety)")
    }
    
    /**
     * Adds accessibility support for ingredient lists
     */
    func ingredientListAccessibility(
        type: IngredientType,
        count: Int
    ) -> some View {
        let label = "\(type.rawValue.capitalized) ingredients: \(count) items"
        let hint = "\(type.rawValue.capitalized) ingredients found in the pet food"
        
        return self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("ingredientList_\(type.rawValue)")
    }
}

enum IngredientType: String, CaseIterable {
    case safe = "safe"
    case unsafe = "unsafe"
    case caution = "caution"
}

// MARK: - Accessibility Components

/**
 * Accessible scan button with comprehensive accessibility support
 */
struct AccessibleScanButton: View {
    let title: String
    let isProcessing: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(ModernDesignSystem.Colors.textOnPrimary)
                } else {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 20))
                }
                
                Text(title)
                    .font(ModernDesignSystem.Typography.bodyEmphasized)
            }
            .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.vertical, ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.primary)
            .cornerRadius(ModernDesignSystem.CornerRadius.large)
        }
        .disabled(isProcessing)
        .scanActionAccessibility(
            label: isProcessing ? "Processing scan" : title,
            hint: isProcessing ? "Scan is being processed" : "Opens camera to scan pet food ingredients",
            value: isProcessing ? "Processing" : nil
        )
    }
}

/**
 * Accessible safety indicator with comprehensive accessibility support
 */
struct AccessibleSafetyIndicator: View {
    let safety: String
    let size: SafetyIndicatorSize
    
    enum SafetyIndicatorSize {
        case small, medium, large
    }
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            if size == .small {
                Circle()
                    .fill(safetyColor)
                    .frame(width: 8, height: 8)
            } else {
                Image(systemName: safetyIcon)
                    .font(.system(size: size == .large ? 24 : 16))
                    .foregroundColor(safetyColor)
            }
            
            Text(safetyDisplayName)
                .font(typographyForSize)
                .foregroundColor(safetyColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Safety status: \(safetyDisplayName)")
        .accessibilityHint("Overall safety assessment of the scanned pet food")
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("safetyIndicator_\(safety)")
    }
    
    private var safetyColor: Color {
        switch safety.lowercased() {
        case "safe":
            return ModernDesignSystem.Colors.safe
        case "caution":
            return ModernDesignSystem.Colors.caution
        case "unsafe":
            return ModernDesignSystem.Colors.unsafe
        default:
            return ModernDesignSystem.Colors.textSecondary
        }
    }
    
    private var safetyIcon: String {
        switch safety.lowercased() {
        case "safe":
            return "checkmark.circle.fill"
        case "caution":
            return "exclamationmark.triangle.fill"
        case "unsafe":
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private var safetyDisplayName: String {
        switch safety.lowercased() {
        case "safe":
            return "Safe"
        case "caution":
            return "Caution"
        case "unsafe":
            return "Unsafe"
        default:
            return "Unknown"
        }
    }
    
    private var typographyForSize: Font {
        switch size {
        case .small:
            return ModernDesignSystem.Typography.caption2
        case .medium:
            return ModernDesignSystem.Typography.caption
        case .large:
            return ModernDesignSystem.Typography.subheadline
        }
    }
}

/**
 * Accessible ingredient list with comprehensive accessibility support
 */
struct AccessibleIngredientList: View {
    let ingredients: [String]
    let type: IngredientType
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: iconForType)
                    .foregroundColor(colorForType)
                    .accessibilityLabel("\(type.rawValue.capitalized) icon")
                
                Text("\(title) (\(ingredients.count))")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(colorForType)
                    .accessibilityAddTraits(.isHeader)
            }
            
            ForEach(ingredients, id: \.self) { ingredient in
                HStack {
                    Text("•")
                        .foregroundColor(colorForType)
                    Text(ingredient)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityLabel("\(type.rawValue.capitalized) ingredient: \(ingredient)")
                    Spacer()
                }
                .padding(.leading, ModernDesignSystem.Spacing.md)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(colorForType.opacity(0.1))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(colorForType, lineWidth: 1)
        )
        .ingredientListAccessibility(type: type, count: ingredients.count)
    }
    
    private var colorForType: Color {
        switch type {
        case .safe:
            return ModernDesignSystem.Colors.safe
        case .unsafe:
            return ModernDesignSystem.Colors.unsafe
        case .caution:
            return ModernDesignSystem.Colors.caution
        }
    }
    
    private var iconForType: String {
        switch type {
        case .safe:
            return "checkmark.circle.fill"
        case .unsafe:
            return "exclamationmark.triangle.fill"
        case .caution:
            return "exclamationmark.triangle.fill"
        }
    }
}

/**
 * Accessible progress indicator with comprehensive accessibility support
 */
struct AccessibleProgressIndicator: View {
    let message: String
    let progress: Double?
    let isIndeterminate: Bool
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            if isIndeterminate {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(ModernDesignSystem.Colors.primary)
                    .accessibilityLabel("Processing")
            } else if let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: ModernDesignSystem.Colors.primary))
                    .accessibilityLabel("Progress: \(Int(progress * 100)) percent")
            }
            
            Text(message)
                .font(ModernDesignSystem.Typography.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel(message)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("progressIndicator")
    }
}

// MARK: - Accessibility Testing Helpers

/**
 * Accessibility testing utilities for scan views
 */
struct ScanAccessibilityTester: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Accessibility Testing")
                .font(ModernDesignSystem.Typography.title)
                .accessibilityAddTraits(.isHeader)
            
            // Test safety indicators
            VStack(spacing: 10) {
                AccessibleSafetyIndicator(safety: "safe", size: .small)
                AccessibleSafetyIndicator(safety: "caution", size: .medium)
                AccessibleSafetyIndicator(safety: "unsafe", size: .large)
            }
            
            // Test scan button
            AccessibleScanButton(
                title: "Test Scan",
                isProcessing: false,
                action: {}
            )
            
            // Test ingredient lists
            AccessibleIngredientList(
                ingredients: ["chicken", "rice", "carrots"],
                type: .safe,
                title: "Safe Ingredients"
            )
            
            AccessibleIngredientList(
                ingredients: ["corn", "wheat"],
                type: .unsafe,
                title: "Unsafe Ingredients"
            )
            
            // Test progress indicator
            AccessibleProgressIndicator(
                message: "Analyzing ingredients...",
                progress: 0.75,
                isIndeterminate: false
            )
        }
        .padding()
    }
}

#Preview("Accessibility Testing") {
    ScanAccessibilityTester()
}
