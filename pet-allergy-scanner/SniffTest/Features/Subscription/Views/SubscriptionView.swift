//
//  SubscriptionView.swift
//  SniffTest
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI

/// View for managing user subscription and premium features
struct SubscriptionView: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // MARK: - Current Plan Status Card
                    currentPlanStatusCard
                    
                    // MARK: - Features Card
                    featuresCard
                    
                    // MARK: - Premium Options or Management
                    if authService.currentUser?.role != .premium {
                        premiumUpgradeCard
                    } else {
                        subscriptionManagementCard
                    }
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
        }
    }
    
    // MARK: - Current Plan Status Card
    private var currentPlanStatusCard: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: authService.currentUser?.role == .premium ? "crown.fill" : "person.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Current Plan")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            // Plan Status
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: authService.currentUser?.role == .premium ? "crown.fill" : "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(authService.currentUser?.role == .premium ? ModernDesignSystem.Colors.goldenYellow : ModernDesignSystem.Colors.primary)
                
                Text(authService.currentUser?.role.displayName ?? "Free")
                    .font(ModernDesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                    .background(authService.currentUser?.role == .premium ? ModernDesignSystem.Colors.goldenYellow : ModernDesignSystem.Colors.textSecondary)
                    .foregroundColor(authService.currentUser?.role == .premium ? ModernDesignSystem.Colors.textPrimary : ModernDesignSystem.Colors.textPrimary)
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Features Card
    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Current Features")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                SubscriptionFeatureRow(icon: "camera.fill", title: "Unlimited Scans", isIncluded: authService.currentUser?.role == .premium)
                SubscriptionFeatureRow(icon: "checkmark.shield.fill", title: "Advanced Allergen Detection", isIncluded: authService.currentUser?.role == .premium)
                SubscriptionFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Detailed Analytics", isIncluded: authService.currentUser?.role == .premium)
                SubscriptionFeatureRow(icon: "pawprint.fill", title: "Unlimited Pets", isIncluded: authService.currentUser?.role == .premium)
                SubscriptionFeatureRow(icon: "bell.badge.fill", title: "Priority Support", isIncluded: authService.currentUser?.role == .premium)
                SubscriptionFeatureRow(icon: "star.fill", title: "Early Access to Features", isIncluded: authService.currentUser?.role == .premium)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Premium Upgrade Card
    private var premiumUpgradeCard: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Upgrade to Premium")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            // Description
            Text("Unlock all features and get the most out of your pet's health")
                .font(ModernDesignSystem.Typography.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ModernDesignSystem.Spacing.sm)
            
            // Pricing Options
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                PricingOption(
                    title: "Monthly",
                    price: "$4.99",
                    period: "per month",
                    isSelected: false
                )
                
                PricingOption(
                    title: "Annual",
                    price: "$49.99",
                    period: "per year",
                    savings: "Save 17%",
                    isSelected: true
                )
            }
            
            // Upgrade Button
            Button(action: {
                // TODO: Implement subscription purchase flow
                HapticFeedback.medium()
            }) {
                Text("Upgrade Now")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(ModernDesignSystem.Spacing.md)
                    .background(ModernDesignSystem.Colors.primary)
                    .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
    
    // MARK: - Subscription Management Card
    private var subscriptionManagementCard: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Subscription Management")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            // Management Actions
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                Button(action: {
                    // TODO: Implement subscription management
                    HapticFeedback.medium()
                }) {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        Text("Manage Subscription")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .font(ModernDesignSystem.Typography.caption)
                    }
                    .padding(ModernDesignSystem.Spacing.md)
                    .background(ModernDesignSystem.Colors.textSecondary.opacity(0.1))
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                }
                
                Button(action: {
                    // TODO: Implement restore purchases
                    HapticFeedback.medium()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Text("Restore Purchases")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .font(ModernDesignSystem.Typography.caption)
                    }
                    .padding(ModernDesignSystem.Spacing.md)
                    .background(ModernDesignSystem.Colors.textSecondary.opacity(0.05))
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
}

/// Feature row component for subscription features
struct SubscriptionFeatureRow: View {
    let icon: String
    let title: String
    let isIncluded: Bool
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(isIncluded ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
                .frame(width: 30)
            
            Text(title)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Image(systemName: isIncluded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isIncluded ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
                .font(ModernDesignSystem.Typography.title3)
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
    }
}

/// Pricing option component
struct PricingOption: View {
    let title: String
    let price: String
    let period: String
    let savings: String?
    let isSelected: Bool
    
    init(title: String, price: String, period: String, savings: String? = nil, isSelected: Bool = false) {
        self.title = title
        self.price = price
        self.period = period
        self.savings = savings
        self.isSelected = isSelected
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(title)
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    Text(price)
                        .font(ModernDesignSystem.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text(period)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                if let savings = savings {
                    Text(savings)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
                .font(ModernDesignSystem.Typography.title3)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(isSelected ? ModernDesignSystem.Colors.primary.opacity(0.1) : ModernDesignSystem.Colors.textSecondary.opacity(0.05))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(isSelected ? ModernDesignSystem.Colors.primary : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(AuthService.shared)
}

