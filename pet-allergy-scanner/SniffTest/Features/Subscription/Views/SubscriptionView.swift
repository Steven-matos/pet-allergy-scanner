//
//  SubscriptionView.swift
//  SniffTest
//
//  View for managing user subscription and premium features
//

import SwiftUI
import StoreKit

/// View for managing user subscription and premium features
struct SubscriptionView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var viewModel = SubscriptionViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // MARK: - Current Plan Status Card
                    currentPlanStatusCard
                    
                    // MARK: - Features Card
                    featuresCard
                    
                    // MARK: - Premium Options or Management
                    if !viewModel.hasActiveSubscription {
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
            .overlay {
                if viewModel.isLoading {
                    LoadingOverlay(message: "Loading...")
                }
            }
            .alert("Success", isPresented: $viewModel.showingPurchaseSuccess) {
                Button("OK") { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .alert("Purchases Restored", isPresented: $viewModel.showingRestoreSuccess) {
                Button("OK") { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
        .task {
            await viewModel.refreshStatus()
        }
    }
    
    // MARK: - Current Plan Status Card
    
    private var currentPlanStatusCard: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: viewModel.hasActiveSubscription ? "crown.fill" : "person.circle.fill")
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
                Image(systemName: viewModel.hasActiveSubscription ? "crown.fill" : "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(viewModel.hasActiveSubscription ? ModernDesignSystem.Colors.goldenYellow : ModernDesignSystem.Colors.primary)
                
                Text(viewModel.hasActiveSubscription ? "Premium" : "Free")
                    .font(ModernDesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                    .background(viewModel.hasActiveSubscription ? ModernDesignSystem.Colors.goldenYellow : ModernDesignSystem.Colors.textSecondary)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                
                if let expirationDate = viewModel.expirationDateText {
                    Text("Renews on \(expirationDate)")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
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
                SubscriptionFeatureRow(icon: "camera.fill", title: "Unlimited Scans", isIncluded: viewModel.hasActiveSubscription)
                SubscriptionFeatureRow(icon: "checkmark.shield.fill", title: "Advanced Allergen Detection", isIncluded: viewModel.hasActiveSubscription)
                SubscriptionFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Detailed Analytics", isIncluded: viewModel.hasActiveSubscription)
                SubscriptionFeatureRow(icon: "pawprint.fill", title: "Unlimited Pets", isIncluded: viewModel.hasActiveSubscription)
                SubscriptionFeatureRow(icon: "bell.badge.fill", title: "Priority Support", isIncluded: viewModel.hasActiveSubscription)
                SubscriptionFeatureRow(icon: "star.fill", title: "Early Access to Features", isIncluded: viewModel.hasActiveSubscription)
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
            VStack(spacing: ModernDesignSystem.Spacing.xs) {
                Text("Unlock all features and get the most out of your pet's health")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Text("Cancel anytime")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary.opacity(0.7))
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.sm)
            
            // Pricing Options
            if !viewModel.products.isEmpty {
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    ForEach(viewModel.products) { product in
                        PricingOptionButton(
                            product: product,
                            isSelected: viewModel.isSelected(product),
                            savings: viewModel.savings(for: product)
                        ) {
                            viewModel.selectProduct(product)
                        }
                    }
                }
            } else {
                Text("Loading subscription options...")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .padding()
            }
            
            // Upgrade Button
            Button {
                Task {
                    await viewModel.purchaseSubscription()
                }
            } label: {
                Text("Upgrade Now")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(ModernDesignSystem.Spacing.md)
                    .background(ModernDesignSystem.Colors.primary)
                    .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            }
            .disabled(viewModel.selectedProductID == nil)
            .opacity(viewModel.selectedProductID == nil ? 0.5 : 1.0)
            
            // Terms
            Text("Subscription automatically renews. Cancel anytime in Settings.")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, ModernDesignSystem.Spacing.xs)
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
                Button {
                    viewModel.manageSubscription()
                } label: {
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
                
                Button {
                    Task {
                        await viewModel.restorePurchases()
                    }
                } label: {
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

// MARK: - Supporting Views

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

/// Pricing option button component
struct PricingOptionButton: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let savings: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(product.planLabel)
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Text(product.price)
                            .font(ModernDesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text(product.duration)
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
}

// MARK: - Preview

#Preview {
    SubscriptionView()
        .environmentObject(AuthService.shared)
}
