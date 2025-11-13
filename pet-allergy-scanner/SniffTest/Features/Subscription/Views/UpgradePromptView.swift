//
//  UpgradePromptView.swift
//  SniffTest
//
//  Soft gate prompt view for encouraging upgrades to premium
//

import SwiftUI

/// Soft gate prompt that encourages users to upgrade to premium
struct UpgradePromptView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: ModernDesignSystem.Spacing.xl) {
                Spacer()
                
                // Icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 80))
                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                    .padding(.top, ModernDesignSystem.Spacing.xxl)
                
                // Title
                Text(title)
                    .font(ModernDesignSystem.Typography.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                
                // Message
                Text(message)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ModernDesignSystem.Spacing.xl)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    // Upgrade Button
                    NavigationLink(destination: PaywallView()) {
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
                    
                    // Maybe Later Button
                    Button {
                        dismiss()
                    } label: {
                        Text("Maybe Later")
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(ModernDesignSystem.Spacing.sm)
                    }
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.bottom, ModernDesignSystem.Spacing.xl)
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }
}

// MARK: - Preview

#Preview {
    UpgradePromptView(
        title: "Daily Scan Limit Reached",
        message: "You've reached your 5 free scans today! 🐾\n\nUnlock unlimited scans and deeper insights with SniffTest Premium."
    )
}

