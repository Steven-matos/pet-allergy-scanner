//
//  SubscriptionBlockerView.swift
//  SniffTest
//
//  Reusable subscription blocker view for premium-only features
//  Displays upgrade prompt when user doesn't have active subscription
//

import SwiftUI

/**
 * Subscription Blocker View
 * 
 * Blocks access to premium features and displays upgrade prompt
 * Follows SOLID principles with single responsibility for subscription gating
 * Implements DRY by providing reusable subscription blocker component
 * Follows KISS by keeping the interface simple and clear
 */
struct SubscriptionBlockerView: View {
    let featureName: String
    let featureDescription: String
    let icon: String
    @State private var showingPaywall = false
    // MEMORY OPTIMIZATION: Use @ObservedObject for observable shared singleton
    @ObservedObject private var gatekeeper = SubscriptionGatekeeper.shared
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            Spacer()
            
            // Premium Feature Illustration
            Image("Illustrations/premium-feature")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 300)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            // Title
            Text("Premium Feature")
                .font(ModernDesignSystem.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            // Feature Name
            Text(featureName)
                .font(ModernDesignSystem.Typography.title2)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            // Description
            Text(featureDescription)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ModernDesignSystem.Spacing.xl)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                // Upgrade Button
                Button(action: {
                    showingPaywall = true
                }) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Premium")
                            .fontWeight(.semibold)
                    }
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(ModernDesignSystem.Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [
                                ModernDesignSystem.Colors.primary,
                                ModernDesignSystem.Colors.primary.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                    .shadow(
                        color: ModernDesignSystem.Colors.primary.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            .padding(.bottom, ModernDesignSystem.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ModernDesignSystem.Colors.background)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
}

/**
 * Subscription Gate Modifier
 * 
 * View modifier that gates content behind subscription check
 * Shows SubscriptionBlockerView if user doesn't have premium
 */
struct SubscriptionGate: ViewModifier {
    let featureName: String
    let featureDescription: String
    let icon: String
    // MEMORY OPTIMIZATION: Use @ObservedObject for observable shared singleton
    @ObservedObject private var gatekeeper = SubscriptionGatekeeper.shared
    
    func body(content: Content) -> some View {
        Group {
            if gatekeeper.currentTier == .premium {
                content
            } else {
                SubscriptionBlockerView(
                    featureName: featureName,
                    featureDescription: featureDescription,
                    icon: icon
                )
            }
        }
    }
}

extension View {
    /**
     * Gate view behind subscription check
     * - Parameters:
     *   - featureName: Name of the premium feature
     *   - featureDescription: Description of what the feature provides
     *   - icon: SF Symbol icon name for the feature
     */
    func requiresSubscription(
        featureName: String,
        featureDescription: String,
        icon: String = "crown.fill"
    ) -> some View {
        modifier(SubscriptionGate(
            featureName: featureName,
            featureDescription: featureDescription,
            icon: icon
        ))
    }
}

