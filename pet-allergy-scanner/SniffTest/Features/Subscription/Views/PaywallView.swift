//
//  PaywallView.swift
//  SniffTest
//
//  Custom paywall view using Trust & Nature design system that displays subscription offerings from RevenueCat.
//

import SwiftUI
import RevenueCat

/// Custom paywall view that displays subscription offerings using Trust & Nature design system
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SubscriptionViewModel()
    @State private var selectedPackageIndex: Int = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // Hero Section
                    heroSection
                    
                    // Features List
                    featuresSection
                    
                    // Pricing Options
                    if !viewModel.products.isEmpty {
                        pricingSection
                    } else {
                        loadingSection
                    }
                    
                    // CTA Button
                    ctaButton
                    
                    // Restore Button
                    restoreButton
                    
                    // Legal Text
                    legalSection
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Track analytics - determine source from context if available
                let source = "unknown" // Could be enhanced to track where paywall was triggered from
                PostHogAnalytics.trackPaywallViewed(source: source)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .font(ModernDesignSystem.Typography.title3)
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    PaywallLoadingOverlay(message: "Processing...")
                }
            }
            .alert("Success", isPresented: $viewModel.showingPurchaseSuccess) {
                Button("Continue") {
                    dismiss()
                }
            } message: {
                Text(viewModel.alertMessage)
            }
            .alert("Restored", isPresented: $viewModel.showingRestoreSuccess) {
                Button("OK") {
                    dismiss()
                }
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
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Premium Feature Image
            Image("Illustrations/premium-feature")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 200)
            
            // Title
            Text("Unlock Premium")
                .font(ModernDesignSystem.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            // Subtitle
            Text("Give your pet the best care with unlimited access to all features")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
        }
        .padding(.top, ModernDesignSystem.Spacing.lg)
    }
    
    // MARK: - Features Section
    
    private var featuresSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.sm) {
            PaywallFeatureRow(icon: "camera.fill", title: "Unlimited Scans", subtitle: "Scan as many products as you need")
            PaywallFeatureRow(icon: "checkmark.shield.fill", title: "Advanced Detection", subtitle: "Get detailed sensitivity analysis")
            PaywallFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Health Analytics", subtitle: "Track your pet's nutrition trends")
            PaywallFeatureRow(icon: "chart.xyaxis.line", title: "Nutrition Trends", subtitle: "See diet changes over time")
            PaywallFeatureRow(icon: "pawprint.fill", title: "Unlimited Pets", subtitle: "Manage unlimited pet profiles")
            PaywallFeatureRow(icon: "heart.text.square.fill", title: "Health Tracking", subtitle: "Monitor weight and wellness")
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
    
    // MARK: - Pricing Section
    
    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            Text("Choose Your Plan")
                .font(ModernDesignSystem.Typography.title2)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .padding(.horizontal, ModernDesignSystem.Spacing.xs)
            
            ForEach(Array(viewModel.products.enumerated()), id: \.element.id) { index, product in
                PricingCard(
                    product: product,
                    isSelected: viewModel.isSelected(product),
                    savings: viewModel.savings(for: product),
                    isPopular: isPopularPlan(product)
                ) {
                    viewModel.selectProduct(product)
                }
            }
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            ProgressView()
                .tint(ModernDesignSystem.Colors.primary)
            Text("Loading subscription options...")
                .font(ModernDesignSystem.Typography.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(ModernDesignSystem.Spacing.xxl)
    }
    
    // MARK: - CTA Button
    
    private var ctaButton: some View {
        Button {
            Task {
                await viewModel.purchaseSubscription()
            }
        } label: {
            HStack {
                Image(systemName: "crown.fill")
                Text("Start Premium")
                    .fontWeight(.semibold)
            }
            .font(ModernDesignSystem.Typography.title3)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(ModernDesignSystem.Spacing.md)
            .background(
                LinearGradient(
                    colors: [ModernDesignSystem.Colors.primary, ModernDesignSystem.Colors.primary.opacity(0.8)],
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
        .disabled(viewModel.selectedProductID == nil || viewModel.isLoading)
        .opacity(viewModel.selectedProductID == nil || viewModel.isLoading ? 0.5 : 1.0)
    }
    
    // MARK: - Restore Button
    
    private var restoreButton: some View {
        Button {
            Task {
                await viewModel.restorePurchases()
            }
        } label: {
            Text("Restore Purchases")
                .font(ModernDesignSystem.Typography.subheadline)
                .foregroundColor(ModernDesignSystem.Colors.primary)
        }
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Legal Section
    
    private var legalSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xs) {
            Text("Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                if let privacyURL = URL(string: "https://www.snifftestapp.com/privacy") {
                    Link("Privacy Policy", destination: privacyURL)
                }
                Text("•")
                if let termsURL = URL(string: "https://www.snifftestapp.com/terms") {
                    Link("Terms of Service", destination: termsURL)
                }
            }
            .font(ModernDesignSystem.Typography.caption)
            .foregroundColor(ModernDesignSystem.Colors.primary)
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        .padding(.bottom, ModernDesignSystem.Spacing.md)
    }
    
    // MARK: - Helper Methods
    
    /// Determine if a product is the popular/recommended plan
    /// - Parameter product: The subscription product
    /// - Returns: True if this is the yearly or monthly plan
    private func isPopularPlan(_ product: SubscriptionProduct) -> Bool {
        product.id == SubscriptionProductID.yearly.rawValue ||
        product.id == SubscriptionProductID.monthly.rawValue
    }
}

// MARK: - Supporting Views

/// Feature row component for paywall features list
struct PaywallFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .frame(width: 32, height: 32)
            
            // Text
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(title)
                    .font(ModernDesignSystem.Typography.bodyEmphasized)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(subtitle)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.primary)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.xs)
    }
}

/// Pricing card component for subscription options
struct PricingCard: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let savings: String?
    let isPopular: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Popular Badge
                if isPopular {
                    HStack {
                        Spacer()
                        Text("MOST POPULAR")
                            .font(ModernDesignSystem.Typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                            .padding(.vertical, ModernDesignSystem.Spacing.xs)
                            .background(ModernDesignSystem.Colors.goldenYellow)
                            .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        Spacer()
                    }
                    .offset(y: -ModernDesignSystem.Spacing.md)
                }
                
                HStack {
                    // Plan Info
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text(product.planLabel)
                            .font(ModernDesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Text(product.price)
                                .font(ModernDesignSystem.Typography.title2)
                                .fontWeight(.bold)
                                .foregroundColor(ModernDesignSystem.Colors.primary)
                            
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
                    
                    // Selection Indicator
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(ModernDesignSystem.Typography.title2)
                        .foregroundColor(isSelected ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(
                isSelected ?
                ModernDesignSystem.Colors.primary.opacity(0.1) :
                ModernDesignSystem.Colors.softCream
            )
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(
                        isSelected ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.borderPrimary,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .shadow(
                color: isSelected ? ModernDesignSystem.Shadows.medium.color : ModernDesignSystem.Shadows.small.color,
                radius: isSelected ? ModernDesignSystem.Shadows.medium.radius : ModernDesignSystem.Shadows.small.radius,
                x: 0,
                y: isSelected ? ModernDesignSystem.Shadows.medium.y : ModernDesignSystem.Shadows.small.y
            )
        }
    }
}

/// Loading overlay component for paywall
struct PaywallLoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(.white)
            }
            .padding(ModernDesignSystem.Spacing.xl)
            .background(ModernDesignSystem.Colors.textPrimary.opacity(0.9))
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        }
    }
}

/// Wrapper view that can be presented modally
struct PaywallHostView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        PaywallView()
    }
}

// MARK: - Preview

#Preview {
    PaywallHostView()
}
