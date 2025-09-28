//
//  ModernDesignSystem.swift
//  pet-allergy-scanner
//
//  Created by Code Assistant, 2025.
//

import SwiftUI

/// Modern design system following Apple's latest design guidelines
struct ModernDesignSystem {
    
    // MARK: - Colors
    
    struct Colors {
        // Primary colors
        static let primary = Color.blue
        static let primaryVariant = Color.blue.opacity(0.8)
        static let secondary = Color.orange
        static let secondaryVariant = Color.orange.opacity(0.8)
        
        // Semantic colors
        static let success = Color.green
        static let warning = Color.yellow
        static let error = Color.red
        static let info = Color.blue
        
        // Neutral colors
        static let background = Color(.systemBackground)
        static let surface = Color(.secondarySystemBackground)
        static let surfaceVariant = Color(.tertiarySystemBackground)
        static let onBackground = Color(.label)
        static let onSurface = Color(.label)
        static let onPrimary = Color.white
        static let onSecondary = Color.white
        
        // Status colors with accessibility
        static let safe = Color.green
        static let caution = Color.orange
        static let unsafe = Color.red
        static let unknown = Color.gray
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Display styles
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        
        // Body styles
        static let body = Font.body
        static let bodyEmphasized = Font.body.weight(.medium)
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
        
        // Monospace for codes
        static let code = Font.system(.body, design: .monospaced)
        static let codeLarge = Font.system(.title2, design: .monospaced)
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
    }
    
    // MARK: - Shadows
    
    struct Shadows {
        static let small = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let medium = Shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        static let large = Shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - View Extensions

extension View {
    /// Apply modern card styling
    func modernCard() -> some View {
        self
            .background(ModernDesignSystem.Colors.surface)
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
    }
    
    /// Apply modern button styling
    func modernButton(style: ButtonStyle = .primary) -> some View {
        self
            .font(ModernDesignSystem.Typography.bodyEmphasized)
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.vertical, ModernDesignSystem.Spacing.md)
            .background(style.backgroundColor)
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
    }
    
    /// Apply modern input field styling
    func modernInputField() -> some View {
        self
            .padding(ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.surface)
            .cornerRadius(ModernDesignSystem.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                    .stroke(ModernDesignSystem.Colors.primary.opacity(0.3), lineWidth: 1)
            )
    }
    
    /// Apply modern section styling
    func modernSection() -> some View {
        self
            .padding(ModernDesignSystem.Spacing.lg)
            .background(ModernDesignSystem.Colors.surface)
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
    }
}

// MARK: - Button Styles

enum ButtonStyle {
    case primary
    case secondary
    case success
    case warning
    case error
    case ghost
    
    var backgroundColor: Color {
        switch self {
        case .primary:
            return ModernDesignSystem.Colors.primary
        case .secondary:
            return ModernDesignSystem.Colors.secondary
        case .success:
            return ModernDesignSystem.Colors.success
        case .warning:
            return ModernDesignSystem.Colors.warning
        case .error:
            return ModernDesignSystem.Colors.error
        case .ghost:
            return Color.clear
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary, .secondary, .success, .error:
            return ModernDesignSystem.Colors.onPrimary
        case .warning:
            return ModernDesignSystem.Colors.onBackground
        case .ghost:
            return ModernDesignSystem.Colors.primary
        }
    }
}

// MARK: - Status Indicators

struct StatusIndicator: View {
    let status: String
    let text: String
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
                .accessibilityLabel("Status indicator: \(status)")
            
            Text(text)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.onBackground)
        }
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "safe":
            return ModernDesignSystem.Colors.safe
        case "caution":
            return ModernDesignSystem.Colors.caution
        case "unsafe":
            return ModernDesignSystem.Colors.unsafe
        default:
            return ModernDesignSystem.Colors.unknown
        }
    }
}

// MARK: - Loading States

struct ModernLoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(ModernDesignSystem.Colors.primary)
            
            Text(message)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.onBackground)
                .multilineTextAlignment(.center)
        }
        .padding(ModernDesignSystem.Spacing.xl)
        .modernCard()
    }
}

// MARK: - Empty States

struct ModernEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .accessibilityLabel("Empty state icon")
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text(title)
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.onBackground)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.onBackground.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .modernButton(style: .primary)
            }
        }
        .padding(ModernDesignSystem.Spacing.xl)
        .modernCard()
    }
}
