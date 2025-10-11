//
//  ProductNotFoundView.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import SwiftUI

/**
 * View displayed when barcode is detected but product not found in database
 *
 * Guides user to scan the nutritional label manually using OCR
 * Follows Trust & Nature design system
 */
struct ProductNotFoundView: View {
    let barcode: String
    let onScanNutritionalLabel: () -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Header with Trust & Nature styling
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                // Icon with golden yellow accent
                ZStack {
                    Circle()
                        .fill(ModernDesignSystem.Colors.softCream)
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.black.opacity(0.1), radius: 8)
                    
                    Image(systemName: "exclamationmark.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                .padding(.bottom, ModernDesignSystem.Spacing.sm)
                
                // Title with Trust & Nature typography
                Text("Product Not Found")
                    .font(ModernDesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                // Barcode info
                Text("Barcode: \(barcode)")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .padding(.horizontal, ModernDesignSystem.Spacing.md)
                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                    .background(ModernDesignSystem.Colors.softCream)
                    .clipShape(Capsule())
                
                // Explanation text
                Text("This product isn't in our database yet. Please scan the nutritional information label to analyze the ingredients.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            }
            
            // Instructions card with Trust & Nature design
            InstructionsCard()
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
            
            Spacer()
            
            // Action buttons with Trust & Nature styling
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                // Primary action: Scan nutritional label
                Button(action: onScanNutritionalLabel) {
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "camera.viewfinder")
                            .font(ModernDesignSystem.Typography.title3)
                        Text("Scan Nutritional Label")
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
                
                // Secondary actions row
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    // Retry button
                    Button(action: onRetry) {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry Scan")
                                .font(ModernDesignSystem.Typography.caption)
                        }
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.softCream)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                    }
                    
                    // Cancel button
                    Button(action: onCancel) {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "xmark")
                            Text("Cancel")
                                .font(ModernDesignSystem.Typography.caption)
                        }
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.softCream)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.bottom, ModernDesignSystem.Spacing.xl)
        }
        .padding(.top, ModernDesignSystem.Spacing.xl)
        .background(Color.white)
        .onAppear {
            isAnimating = true
        }
    }
}

/**
 * Instructions card for scanning nutritional label
 */
struct InstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card title
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("How to Scan")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            // Instructions list
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                InstructionRow(
                    number: 1,
                    text: "Find the nutritional information panel on the product"
                )
                InstructionRow(
                    number: 2,
                    text: "Position the label in good lighting"
                )
                InstructionRow(
                    number: 3,
                    text: "Tap the button to take a photo"
                )
                InstructionRow(
                    number: 4,
                    text: "We'll analyze the ingredients for you"
                )
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
 * Individual instruction row
 */
struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
            // Number badge
            Text("\(number)")
                .font(ModernDesignSystem.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(ModernDesignSystem.Colors.primary)
                .clipShape(Circle())
            
            // Instruction text
            Text(text)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ProductNotFoundView(
        barcode: "1234567890123",
        onScanNutritionalLabel: {},
        onRetry: {},
        onCancel: {}
    )
}


