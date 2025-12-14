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
 *
 * Enhanced Features:
 * - Spring entrance animation for smooth appearance
 * - Visual monitoring progress indicator
 * - Haptic feedback on dismiss
 * - Swipe-to-dismiss gesture
 * - Enhanced icon with background circle
 */
struct HealthGuidanceCard: View {
    let guidance: HealthGuidance
    let onDismiss: () -> Void
    let onActionTap: ((String) -> Void)?
    
    @State private var isExpanded: Bool = false
    @State private var isVisible: Bool = true
    @State private var hasAppeared: Bool = false
    @State private var dragOffset: CGFloat = 0
    
    /// Threshold for swipe-to-dismiss gesture
    private let dismissThreshold: CGFloat = 100
    
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
                    // Enhanced icon with background circle
                    iconWithBackground
                    
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
                        Button(action: dismissWithHaptic) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(ModernDesignSystem.Colors.textSecondary.opacity(0.1))
                                )
                        }
                        .accessibilityLabel("Dismiss guidance")
                    }
                }
                
                // Visual monitoring progress indicator (if applicable)
                if let days = guidance.monitoringDays {
                    MonitoringProgressView(totalDays: days, guidanceType: guidance.guidanceType)
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
                // Gradient accent on left edge
                HStack {
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(
                            LinearGradient(
                                colors: [iconColor, iconColor.opacity(0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 4)
                    Spacer()
                }
            )
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
            // Swipe-to-dismiss gesture
            .offset(x: dragOffset)
            .opacity(Double(1 - (abs(dragOffset) / (dismissThreshold * 2))))
            .gesture(
                guidance.dismissable ? swipeToDismissGesture : nil
            )
            // Spring entrance animation
            .scaleEffect(hasAppeared ? 1.0 : 0.92)
            .opacity(hasAppeared ? 1.0 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    hasAppeared = true
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Enhanced icon with background circle for better visual weight
    private var iconWithBackground: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 44, height: 44)
            
            Image(systemName: guidance.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(iconColor)
        }
        .accessibilityLabel("Guidance icon")
    }
    
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
    
    // MARK: - Gestures
    
    /// Swipe-to-dismiss drag gesture
    private var swipeToDismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                if abs(value.translation.width) > dismissThreshold {
                    dismissWithHaptic()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        dragOffset = 0
                    }
                }
            }
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
    
    /// Dismiss with haptic feedback and animation
    private func dismissWithHaptic() {
        // Trigger haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        // Delay callback to allow animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Monitoring Progress View

/**
 * MonitoringProgressView - Visual timeline for monitoring periods
 * Shows how many days to monitor with a progress-style indicator
 */
private struct MonitoringProgressView: View {
    let totalDays: Int
    let guidanceType: GuidanceType
    
    /// Number of days elapsed (for future enhancement with persistence)
    private var daysElapsed: Int { 0 }
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14))
                    .foregroundColor(progressColor)
                
                Text("Monitor for \(totalDays) days")
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("Day \(daysElapsed + 1) of \(totalDays)")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            // Progress bar with day markers
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ModernDesignSystem.Colors.borderPrimary.opacity(0.3))
                        .frame(height: 6)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [progressColor, progressColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * progressPercentage, 20), height: 6)
                    
                    // Day markers
                    HStack(spacing: 0) {
                        ForEach(0..<totalDays, id: \.self) { day in
                            Circle()
                                .fill(day <= daysElapsed ? progressColor : ModernDesignSystem.Colors.borderPrimary.opacity(0.5))
                                .frame(width: 8, height: 8)
                            
                            if day < totalDays - 1 {
                                Spacer()
                            }
                        }
                    }
                }
            }
            .frame(height: 8)
        }
        .padding(ModernDesignSystem.Spacing.sm)
        .background(progressColor.opacity(0.08))
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
    }
    
    /// Progress percentage based on days elapsed
    private var progressPercentage: CGFloat {
        CGFloat(daysElapsed + 1) / CGFloat(totalDays)
    }
    
    /// Progress color based on guidance type
    private var progressColor: Color {
        switch guidanceType {
        case .monitoring: return ModernDesignSystem.Colors.primary
        case .logging: return ModernDesignSystem.Colors.goldenYellow
        case .celebration: return ModernDesignSystem.Colors.safe
        case .awareness: return ModernDesignSystem.Colors.warmCoral
        case .reminder: return ModernDesignSystem.Colors.primary
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
