//
//  HealthGuidanceCard.swift
//  SniffTest
//
//  Created for Gap #1: Guided Health Moments
//  Lightweight dismissible banner for contextual health prompts
//

import SwiftUI

/**
 * HealthGuidanceCard - Dismissible Contextual Health Guidance Banner
 *
 * Displays rule-based guidance prompts triggered by user actions.
 * Designed for calm clarity - not alarmist, optional interactions.
 *
 * UI/UX Principles:
 * - Calm language, not fear-based
 * - Dismissible (respects user autonomy)
 * - Passive insights, not demands
 * - Trust & Nature design system compliant
 */
struct HealthGuidanceCard: View {
    let guidance: HealthGuidance
    let onDismiss: () -> Void
    let onActionTap: ((String) -> Void)?
    
    @State private var isExpanded: Bool = false
    @State private var isVisible: Bool = true
    
    init(
        guidance: HealthGuidance,
        onDismiss: @escaping () -> Void,
        onActionTap: ((String) -> Void)? = nil
    ) {
        self.guidance = guidance
        self.onDismiss = onDismiss
        self.onActionTap = onActionTap
    }
    
    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                // Header with icon, title, and dismiss button
                HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.md) {
                    // Icon
                    Image(systemName: guidance.icon)
                        .font(.system(size: 24))
                        .foregroundColor(iconColor)
                        .frame(width: 32, height: 32)
                        .accessibilityLabel("Guidance icon")
                    
                    // Title and message
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text(guidance.title)
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        
                        Text(guidance.message)
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    // Dismiss button (if dismissable)
                    if guidance.dismissable {
                        Button(action: dismissWithAnimation) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .frame(width: 24, height: 24)
                        }
                        .accessibilityLabel("Dismiss guidance")
                    }
                }
                
                // Monitoring period badge (if applicable)
                if let days = guidance.monitoringDays {
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text("Monitor for \(days) days")
                            .font(ModernDesignSystem.Typography.caption)
                    }
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                    .padding(.vertical, ModernDesignSystem.Spacing.xs)
                    .background(ModernDesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                }
                
                // Expandable action items (if available)
                if !guidance.actionItems.isEmpty {
                    DisclosureGroup(
                        isExpanded: $isExpanded,
                        content: {
                            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                                ForEach(guidance.actionItems, id: \.self) { item in
                                    actionItemRow(item)
                                }
                            }
                            .padding(.top, ModernDesignSystem.Spacing.sm)
                        },
                        label: {
                            Text("What to watch for")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(ModernDesignSystem.Colors.primary)
                        }
                    )
                    .tint(ModernDesignSystem.Colors.primary)
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .background(backgroundColor)
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
            ))
        }
    }
    
    // MARK: - Subviews
    
    /// Individual action item row
    private func actionItemRow(_ item: String) -> some View {
        Button(action: { onActionTap?(item) }) {
            HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .padding(.top, 6)
                
                Text(item)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    
    /// Background color based on guidance type
    private var backgroundColor: Color {
        switch guidance.guidanceType {
        case .monitoring:
            return ModernDesignSystem.Colors.primary.opacity(0.05)
        case .logging:
            return ModernDesignSystem.Colors.goldenYellow.opacity(0.05)
        case .celebration:
            return ModernDesignSystem.Colors.safe.opacity(0.05)
        case .awareness:
            return guidance.priority == .high 
                ? ModernDesignSystem.Colors.warmCoral.opacity(0.05)
                : ModernDesignSystem.Colors.softCream
        case .reminder:
            return ModernDesignSystem.Colors.primary.opacity(0.05)
        }
    }
    
    /// Border color based on guidance type
    private var borderColor: Color {
        switch guidance.guidanceType {
        case .monitoring:
            return ModernDesignSystem.Colors.primary.opacity(0.2)
        case .logging:
            return ModernDesignSystem.Colors.goldenYellow.opacity(0.2)
        case .celebration:
            return ModernDesignSystem.Colors.safe.opacity(0.2)
        case .awareness:
            return guidance.priority == .high
                ? ModernDesignSystem.Colors.warmCoral.opacity(0.3)
                : ModernDesignSystem.Colors.borderPrimary.opacity(0.5)
        case .reminder:
            return ModernDesignSystem.Colors.primary.opacity(0.2)
        }
    }
    
    /// Icon color based on guidance type
    private var iconColor: Color {
        switch guidance.guidanceType {
        case .monitoring:
            return ModernDesignSystem.Colors.primary
        case .logging:
            return ModernDesignSystem.Colors.goldenYellow
        case .celebration:
            return ModernDesignSystem.Colors.safe
        case .awareness:
            return guidance.priority == .high
                ? ModernDesignSystem.Colors.warmCoral
                : ModernDesignSystem.Colors.primary
        case .reminder:
            return ModernDesignSystem.Colors.primary
        }
    }
    
    // MARK: - Actions
    
    /// Dismiss with animation
    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        // Delay callback to allow animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Guidance Stack View

/**
 * HealthGuidanceStack - Container for multiple guidance cards
 * Displays guidance prompts in priority order
 */
struct HealthGuidanceStack: View {
    let guidanceItems: [HealthGuidance]
    let onDismiss: (String) -> Void
    
    var body: some View {
        if !guidanceItems.isEmpty {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                ForEach(guidanceItems) { guidance in
                    HealthGuidanceCard(
                        guidance: guidance,
                        onDismiss: { onDismiss(guidance.id) }
                    )
                }
            }
        }
    }
}

// MARK: - Compact Guidance Banner

/**
 * CompactGuidanceBanner - Minimal banner for non-intrusive guidance
 * Used when space is limited or for lower-priority guidance
 */
struct CompactGuidanceBanner: View {
    let guidance: HealthGuidance
    let onDismiss: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: guidance.icon)
                    .font(.system(size: 16))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                
                Text(guidance.title)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                if guidance.dismissable {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12))
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
            }
            .padding(ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.softCream)
            .cornerRadius(ModernDesignSystem.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                    .stroke(ModernDesignSystem.Colors.borderPrimary.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct HealthGuidanceCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Monitoring guidance
                HealthGuidanceCard(
                    guidance: HealthGuidance(
                        title: "Monitor Your Pet",
                        message: "Watch for changes in stool, itching, or appetite over the next 7 days.",
                        icon: "eye.fill",
                        guidanceType: .monitoring,
                        monitoringDays: 7,
                        actionItems: [
                            "Check stool consistency daily",
                            "Watch for excessive scratching",
                            "Note any changes in appetite"
                        ]
                    ),
                    onDismiss: {}
                )
                
                // Celebration guidance
                HealthGuidanceCard(
                    guidance: HealthGuidance(
                        title: "Looking Good!",
                        message: "No concerning ingredients detected. Still, introduce new foods gradually.",
                        icon: "checkmark.circle.fill",
                        guidanceType: .celebration,
                        actionItems: [
                            "Introduce gradually over 5-7 days",
                            "Mix with current food initially"
                        ]
                    ),
                    onDismiss: {}
                )
                
                // High priority awareness
                HealthGuidanceCard(
                    guidance: HealthGuidance(
                        title: "Ingredient Alert",
                        message: "This food contains ingredients that may not be safe for your pet.",
                        icon: "exclamationmark.triangle.fill",
                        guidanceType: .awareness,
                        priority: .high,
                        actionItems: [
                            "Review flagged ingredients",
                            "Consider alternative foods"
                        ]
                    ),
                    onDismiss: {}
                )
            }
            .padding()
        }
        .background(Color.white)
    }
}
#endif
