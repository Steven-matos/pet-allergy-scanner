//
//  ScanLimitIndicator.swift
//  SniffTest
//
//  Component to show scan limit progress for free tier users
//

import SwiftUI

/// Displays scan usage and limits for free tier users
struct ScanLimitIndicator: View {
    @ObservedObject private var scanCounter = DailyScanCounter.shared
    @ObservedObject private var gatekeeper = SubscriptionGatekeeper.shared
    
    var body: some View {
        if gatekeeper.currentTier == .free {
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Progress Bar
                HStack(spacing: ModernDesignSystem.Spacing.xs) {
                    ForEach(0..<5, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index < scanCounter.todaysScanCount ? 
                                  ModernDesignSystem.Colors.primary : 
                                  ModernDesignSystem.Colors.textSecondary.opacity(0.2))
                            .frame(height: 4)
                    }
                }
                
                // Text Information
                HStack {
                    Image(systemName: "camera.fill")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Text(limitText)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    if scanCounter.todaysScanCount >= 5 {
                        // Upgrade prompt for users who hit limit
                        Button {
                            gatekeeper.showScanLimitPrompt()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                Text("Upgrade")
                            }
                            .font(ModernDesignSystem.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                        }
                    }
                }
            }
            .padding(ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.softCream)
            .cornerRadius(ModernDesignSystem.CornerRadius.small)
        }
    }
    
    private var limitText: String {
        let remaining = max(0, 5 - scanCounter.todaysScanCount)
        
        if scanCounter.todaysScanCount >= 5 {
            return "Daily limit reached • Resets tomorrow"
        } else if remaining == 1 {
            return "\(remaining) scan remaining today"
        } else {
            return "\(remaining) scans remaining today"
        }
    }
}

/// Compact scan limit badge for navigation bar or headers
struct CompactScanLimitBadge: View {
    @ObservedObject private var scanCounter = DailyScanCounter.shared
    @ObservedObject private var gatekeeper = SubscriptionGatekeeper.shared
    
    var body: some View {
        if gatekeeper.currentTier == .free {
            HStack(spacing: 4) {
                Image(systemName: "camera.fill")
                    .font(.caption2)
                
                Text("\(scanCounter.todaysScanCount)/5")
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(scanCounter.todaysScanCount >= 5 ? 
                            ModernDesignSystem.Colors.warmCoral : 
                            ModernDesignSystem.Colors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ModernDesignSystem.Colors.softCream)
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview

#Preview("Scan Limit Indicator") {
    VStack(spacing: 20) {
        // No scans used
        ScanLimitIndicator()
        
        // Some scans used
        ScanLimitIndicator()
        
        // Limit reached
        ScanLimitIndicator()
        
        // Compact badge
        CompactScanLimitBadge()
    }
    .padding()
}

