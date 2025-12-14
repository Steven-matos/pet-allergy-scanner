//
//  OnboardingFeatureTourView.swift
//  SniffTest
//
//  Created for enhanced onboarding experience
//  Feature tour screens to introduce app capabilities
//

import SwiftUI

/**
 * OnboardingFeatureTourView - Feature Tour Component
 *
 * Introduces users to SniffTest's key features through swipeable screens:
 * 1. Ingredient Scanning - Camera-based food label analysis
 * 2. Health Tracking - Feeding, weight, and health event logging
 * 3. Vet Visit Summary - One-tap summaries for veterinary visits
 * 4. Safety Explanations - Clear, calm explanations for flagged ingredients
 * 5. Timeline Clarity - The app's core value proposition
 *
 * Design Principles:
 * - Simple text + icon style for fast comprehension
 * - Calm, informative tone (not salesy)
 * - Progress indicators and skip option throughout
 * - Trust & Nature design system compliant
 */
struct OnboardingFeatureTourView: View {
    /// Current feature screen index
    @Binding var currentIndex: Int
    
    /// Callback when tour is completed or skipped
    let onComplete: () -> Void
    
    /// Total number of feature screens
    let totalScreens = 5
    
    var body: some View {
        VStack(spacing: 0) {
            // Feature screens
            TabView(selection: $currentIndex) {
                ForEach(0..<totalScreens, id: \.self) { index in
                    FeatureScreenView(feature: features[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentIndex)
            
            // Bottom section with dots and navigation
            bottomSection
        }
        .background(ModernDesignSystem.Colors.softCream)
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Page dots
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(0..<totalScreens, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex 
                              ? ModernDesignSystem.Colors.primary 
                              : ModernDesignSystem.Colors.borderPrimary)
                        .frame(width: index == currentIndex ? 10 : 8, 
                               height: index == currentIndex ? 10 : 8)
                        .animation(.spring(response: 0.3), value: currentIndex)
                }
            }
            .padding(.top, ModernDesignSystem.Spacing.md)
            
            // Navigation buttons
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                // Skip button
                Button("Skip Tour") {
                    onComplete()
                }
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                )
                
                // Next/Continue button
                Button(action: {
                    if currentIndex < totalScreens - 1 {
                        withAnimation {
                            currentIndex += 1
                        }
                    } else {
                        onComplete()
                    }
                }) {
                    Text(currentIndex < totalScreens - 1 ? "Next" : "Get Started")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                        .fill(ModernDesignSystem.Colors.primary)
                )
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.bottom, ModernDesignSystem.Spacing.lg)
        }
        .background(
            ModernDesignSystem.Colors.softCream
                .shadow(color: ModernDesignSystem.Shadows.small.color, 
                        radius: ModernDesignSystem.Shadows.small.radius,
                        y: -2)
        )
    }
    
    // MARK: - Feature Data
    
    /// Feature screen content definitions
    private var features: [FeatureContent] {
        [
            FeatureContent(
                icon: "camera.viewfinder",
                title: "Scan Any Pet Food",
                description: "Point your camera at ingredients lists. We'll instantly identify what's safe and what's not for your pet.",
                highlights: [
                    "Barcode and OCR scanning",
                    "Instant ingredient analysis",
                    "Database of 10,000+ ingredients"
                ]
            ),
            FeatureContent(
                icon: "chart.line.uptrend.xyaxis",
                title: "Track Health Over Time",
                description: "Log feedings, weight, and health events. Build a complete picture of your pet's wellness journey.",
                highlights: [
                    "Daily feeding logs",
                    "Weight trends & goals",
                    "Health event timeline"
                ]
            ),
            FeatureContent(
                icon: "stethoscope",
                title: "Vet Visit Ready",
                description: "Generate one-tap summaries with food history, weight trends, and medications. Give your vet clarity, not confusion.",
                highlights: [
                    "30/60/90 day summaries",
                    "Food change history",
                    "Medication tracking"
                ]
            ),
            FeatureContent(
                icon: "exclamationmark.shield",
                title: "Clear Safety Explanations",
                description: "Every flagged ingredient explains WHY it's flagged, for WHICH species, and at WHAT confidence level.",
                highlights: [
                    "Calm, not alarming",
                    "Species-specific info",
                    "Actionable guidance"
                ]
            ),
            FeatureContent(
                icon: "clock.arrow.circlepath",
                title: "Your Pet's Timeline",
                description: "Owners forget timelines. Vets distrust memory. SniffTest remembers everything so you don't have to.",
                highlights: [
                    "Complete food history",
                    "Health event records",
                    "Never lose data"
                ]
            )
        ]
    }
}

// MARK: - Feature Content Model

/// Data model for feature screen content
private struct FeatureContent {
    let icon: String
    let title: String
    let description: String
    let highlights: [String]
}

// MARK: - Feature Screen View

/// Individual feature screen display
private struct FeatureScreenView: View {
    let feature: FeatureContent
    
    @State private var hasAppeared = false
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            Spacer()
            
            // Icon with animated background
            ZStack {
                // Background circle
                Circle()
                    .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .scaleEffect(hasAppeared ? 1.0 : 0.8)
                
                // Icon
                Image(systemName: feature.icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .scaleEffect(hasAppeared ? 1.0 : 0.6)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: hasAppeared)
            
            // Title
            Text(feature.title)
                .font(ModernDesignSystem.Typography.largeTitle)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(hasAppeared ? 1.0 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: hasAppeared)
            
            // Description
            Text(feature.description)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, ModernDesignSystem.Spacing.xl)
                .opacity(hasAppeared ? 1.0 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: hasAppeared)
            
            // Highlights
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(Array(feature.highlights.enumerated()), id: \.offset) { index, highlight in
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        Text(highlight)
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                    .opacity(hasAppeared ? 1.0 : 0)
                    .offset(x: hasAppeared ? 0 : -20)
                    .animation(.easeOut(duration: 0.4).delay(0.3 + Double(index) * 0.1), value: hasAppeared)
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .fill(ModernDesignSystem.Colors.softCream)
                    .shadow(color: ModernDesignSystem.Shadows.small.color,
                            radius: ModernDesignSystem.Shadows.small.radius,
                            x: ModernDesignSystem.Shadows.small.x,
                            y: ModernDesignSystem.Shadows.small.y)
            )
            .padding(.horizontal, ModernDesignSystem.Spacing.xl)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            hasAppeared = true
        }
        .onDisappear {
            hasAppeared = false
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct OnboardingFeatureTourView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFeatureTourView(
            currentIndex: .constant(0),
            onComplete: { print("Tour completed") }
        )
    }
}
#endif

