//
//  SubscriptionView.swift
//  pet-allergy-scanner
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
                VStack(spacing: 24) {
                    // Current Plan Header
                    VStack(spacing: 16) {
                        Image(systemName: authService.currentUser?.role == .premium ? "crown.fill" : "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(authService.currentUser?.role == .premium ? ModernDesignSystem.Colors.goldenYellow : ModernDesignSystem.Colors.deepForestGreen)
                        
                        Text("Current Plan")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(authService.currentUser?.role.displayName ?? "Free")
                            .font(.title2)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(authService.currentUser?.role == .premium ? ModernDesignSystem.Colors.goldenYellow : ModernDesignSystem.Colors.lightGray)
                            .foregroundColor(authService.currentUser?.role == .premium ? ModernDesignSystem.Colors.textOnAccent : ModernDesignSystem.Colors.textPrimary)
                            .cornerRadius(12)
                    }
                    .padding(.top, 40)
                    
                    // Current Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Features")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        SubscriptionFeatureRow(icon: "camera.fill", title: "Unlimited Scans", isIncluded: authService.currentUser?.role == .premium)
                        SubscriptionFeatureRow(icon: "checkmark.shield.fill", title: "Advanced Allergen Detection", isIncluded: authService.currentUser?.role == .premium)
                        SubscriptionFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Detailed Analytics", isIncluded: authService.currentUser?.role == .premium)
                        SubscriptionFeatureRow(icon: "pawprint.fill", title: "Unlimited Pets", isIncluded: authService.currentUser?.role == .premium)
                        SubscriptionFeatureRow(icon: "bell.badge.fill", title: "Priority Support", isIncluded: authService.currentUser?.role == .premium)
                        SubscriptionFeatureRow(icon: "star.fill", title: "Early Access to Features", isIncluded: authService.currentUser?.role == .premium)
                    }
                    .padding()
                    .background(ModernDesignSystem.Colors.surfaceVariant)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Premium Plan Benefits (if free user)
                    if authService.currentUser?.role != .premium {
                        VStack(spacing: 16) {
                            Text("Upgrade to Premium")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Unlock all features and get the most out of your pet's health")
                                .font(.subheadline)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
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
                            .padding(.horizontal)
                            
                            Button(action: {
                                // TODO: Implement subscription purchase flow
                                HapticFeedback.medium()
                            }) {
                                Text("Upgrade Now")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(ModernDesignSystem.Colors.deepForestGreen)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    } else {
                        // Manage Subscription (if premium user)
                        VStack(spacing: 16) {
                            Text("Subscription Management")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Button(action: {
                                // TODO: Implement subscription management
                                HapticFeedback.medium()
                            }) {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Manage Subscription")
                                }
                                .font(.headline)
                                .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(ModernDesignSystem.Colors.surfaceVariant)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            
                            Button(action: {
                                // TODO: Implement restore purchases
                                HapticFeedback.medium()
                            }) {
                                Text("Restore Purchases")
                                    .font(.subheadline)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Feature row component for subscription features
struct SubscriptionFeatureRow: View {
    let icon: String
    let title: String
    let isIncluded: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isIncluded ? ModernDesignSystem.Colors.deepForestGreen : ModernDesignSystem.Colors.textSecondary)
                .frame(width: 30)
            
            Text(title)
                .font(.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Spacer()
            
            Image(systemName: isIncluded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isIncluded ? ModernDesignSystem.Colors.deepForestGreen : ModernDesignSystem.Colors.textSecondary)
        }
        .padding(.horizontal)
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
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                HStack(spacing: 4) {
                    Text(price)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text(period)
                        .font(.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                if let savings = savings {
                    Text(savings)
                        .font(.caption)
                        .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                        .fontWeight(.semibold)
                }
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? ModernDesignSystem.Colors.deepForestGreen : ModernDesignSystem.Colors.textSecondary)
                .font(.title3)
        }
        .padding()
        .background(isSelected ? ModernDesignSystem.Colors.deepForestGreen.opacity(0.1) : ModernDesignSystem.Colors.surfaceVariant)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? ModernDesignSystem.Colors.deepForestGreen : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(AuthService.shared)
}

