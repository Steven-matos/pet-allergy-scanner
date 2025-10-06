//
//  ScanComponents.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import SwiftUI

/**
 * Reusable scan-specific components following Trust & Nature design system
 * 
 * These components provide consistent styling and behavior across all scanning views
 * while maintaining the warm, trustworthy, and natural feeling of the design system.
 */

// MARK: - Scan Status Components

/**
 * Safety status indicator with Trust & Nature color coding
 */
struct SafetyStatusIndicator: View {
    let safety: String
    let size: SafetyIndicatorSize
    
    enum SafetyIndicatorSize {
        case small, medium, large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 40
            }
        }
        
        var circleSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }
    }
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            if size == .small {
                Circle()
                    .fill(safetyColor)
                    .frame(width: size.circleSize, height: size.circleSize)
            } else {
                Image(systemName: safetyIcon)
                    .font(.system(size: size.iconSize))
                    .foregroundColor(safetyColor)
            }
            
            Text(safetyDisplayName)
                .font(typographyForSize)
                .foregroundColor(safetyColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Safety status: \(safetyDisplayName)")
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

// MARK: - Scan Action Components

/**
 * Primary scan action button with Trust & Nature styling
 */
struct ScanActionButton: View {
    let title: String
    let icon: String
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
                    Image(systemName: icon)
                        .font(.system(size: 20))
                }
                
                Text(title)
                    .font(ModernDesignSystem.Typography.bodyEmphasized)
            }
            .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.vertical, ModernDesignSystem.Spacing.md)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ModernDesignSystem.Colors.primary,
                        ModernDesignSystem.Colors.primary.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(ModernDesignSystem.CornerRadius.large)
            .shadow(
                color: ModernDesignSystem.Colors.primary.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(isProcessing)
        .scaleEffect(isProcessing ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isProcessing)
    }
}

/**
 * Secondary action button with Trust & Nature styling
 */
struct SecondaryActionButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                
                Text(title)
                    .font(ModernDesignSystem.Typography.body)
            }
            .foregroundColor(ModernDesignSystem.Colors.primary)
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.vertical, ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.softCream)
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
        }
    }
}

// MARK: - Scan Information Components

/**
 * Scan information card with Trust & Nature styling
 */
struct ScanInfoCard: View {
    let title: String
    let subtitle: String?
    let icon: String
    let content: AnyView
    
    init(title: String, subtitle: String? = nil, icon: String, @ViewBuilder content: () -> some View) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = AnyView(content())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            content
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
    }
}

/**
 * Scan statistics card with Trust & Nature styling
 */
struct ScanStatsCard: View {
    let stats: [ScanStat]
    
    struct ScanStat {
        let label: String
        let value: String
        let color: Color
    }
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                HStack {
                    Circle()
                        .fill(stat.color)
                        .frame(width: 8, height: 8)
                    
                    Text(stat.label)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Text(stat.value)
                        .font(ModernDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                }
                
                if index < stats.count - 1 {
                    Divider()
                        .background(ModernDesignSystem.Colors.borderPrimary)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
    }
}

// MARK: - Scan Progress Components

/**
 * Scan progress indicator with Trust & Nature styling
 */
struct ScanProgressIndicator: View {
    let message: String
    let progress: Double?
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            if let progress = progress {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: ModernDesignSystem.Colors.primary))
                    .accessibilityLabel("Progress: \(Int(progress * 100)) percent")
            } else {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(ModernDesignSystem.Colors.primary)
                    .accessibilityLabel("Processing")
            }
            
            Text(message)
                .font(ModernDesignSystem.Typography.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
    }
}

/**
 * Scan error display with Trust & Nature styling
 */
struct ScanErrorDisplay: View {
    let message: String
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                .font(.system(size: 24))
            
            Text(message)
                .font(ModernDesignSystem.Typography.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                .multilineTextAlignment(.center)
            
            if let onRetry = onRetry {
                Button("Try Again", action: onRetry)
                    .modernButton(style: .error)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
    }
}

// MARK: - Scan List Components

/**
 * Scan list item with Trust & Nature styling
 */
struct ScanListItem: View {
    let scan: Scan
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                // Safety indicator
                SafetyStatusIndicator(safety: scan.result?.overallSafety ?? "unknown", size: .small)
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(scan.result?.productName ?? "Unknown Product")
                        .font(ModernDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(scan.createdAt, style: .relative)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding(ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.softCream)
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Scan Empty States

/**
 * Empty scans state with Trust & Nature styling
 */
struct EmptyScansState: View {
    let onScan: () -> Void
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary.opacity(0.4))
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Text("No Scans Yet")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Start by scanning your pet's food to check for allergens and get nutritional insights.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            ScanActionButton(
                title: "Scan Food",
                icon: "camera.viewfinder",
                isProcessing: false,
                action: onScan
            )
        }
        .padding(ModernDesignSystem.Spacing.xl)
        .modernCard()
    }
}

// MARK: - Preview Helpers

#Preview("Safety Indicators") {
    VStack(spacing: 20) {
        SafetyStatusIndicator(safety: "safe", size: .small)
        SafetyStatusIndicator(safety: "caution", size: .medium)
        SafetyStatusIndicator(safety: "unsafe", size: .large)
    }
    .padding()
}

#Preview("Action Buttons") {
    VStack(spacing: 20) {
        ScanActionButton(
            title: "Scan Food",
            icon: "camera.viewfinder",
            isProcessing: false,
            action: {}
        )
        
        ScanActionButton(
            title: "Processing...",
            icon: "camera.viewfinder",
            isProcessing: true,
            action: {}
        )
        
        SecondaryActionButton(
            title: "Cancel",
            icon: "xmark",
            action: {}
        )
    }
    .padding()
}

#Preview("Info Cards") {
    VStack(spacing: 20) {
        ScanInfoCard(
            title: "Scan Results",
            subtitle: "Analysis complete",
            icon: "checkmark.circle"
        ) {
            Text("Your pet's food is safe!")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.safe)
        }
        
        ScanStatsCard(stats: [
            ScanStatsCard.ScanStat(label: "Safe Ingredients", value: "5", color: ModernDesignSystem.Colors.safe),
            ScanStatsCard.ScanStat(label: "Unsafe Ingredients", value: "1", color: ModernDesignSystem.Colors.unsafe),
            ScanStatsCard.ScanStat(label: "Total Ingredients", value: "6", color: ModernDesignSystem.Colors.primary)
        ])
    }
    .padding()
}
