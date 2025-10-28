//
//  CacheHydrationProgressView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/**
 * Cache Hydration Progress View
 * 
 * Shows the progress of cache hydration when user signs in.
 * Provides visual feedback during the data preloading process.
 * 
 * Follows SOLID principles with single responsibility for progress display
 * Implements DRY by reusing ModernDesignSystem components
 * Follows KISS by keeping the interface simple and informative
 */
struct CacheHydrationProgressView: View {
    @State private var hydrationService = CacheHydrationService.shared
    
    var body: some View {
        if hydrationService.isHydrating {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Progress indicator
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    // Circular progress indicator
                    ZStack {
                        Circle()
                            .stroke(ModernDesignSystem.Colors.softCream, lineWidth: 8)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: hydrationService.hydrationProgress)
                            .stroke(
                                ModernDesignSystem.Colors.primary,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: hydrationService.hydrationProgress)
                        
                        // Progress percentage
                        Text("\(Int(hydrationService.hydrationProgress * 100))%")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                    }
                    
                    // Current step message
                    Text(hydrationService.currentStep)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: hydrationService.currentStep)
                }
                
                // Hydration info
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Loading Your Data")
                        .font(ModernDesignSystem.Typography.title2)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("We're preloading your profile, pets, nutrition data, and reference information for instant access.")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(ModernDesignSystem.Spacing.xl)
            .background(ModernDesignSystem.Colors.background)
            .cornerRadius(ModernDesignSystem.CornerRadius.large)
            .shadow(
                color: ModernDesignSystem.Shadows.medium.color,
                radius: ModernDesignSystem.Shadows.medium.radius,
                x: ModernDesignSystem.Shadows.medium.x,
                y: ModernDesignSystem.Shadows.medium.y
            )
        }
    }
}

/**
 * Cache Hydration Status View
 * 
 * Compact view showing hydration status in navigation or other contexts
 */
struct CacheHydrationStatusView: View {
    @State private var hydrationService = CacheHydrationService.shared
    
    var body: some View {
        if hydrationService.isHydrating {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Small progress indicator
                ProgressView(value: hydrationService.hydrationProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: ModernDesignSystem.Colors.primary))
                    .frame(width: 60)
                
                Text("Loading data...")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CacheHydrationProgressView()
        
        CacheHydrationStatusView()
    }
    .padding()
    .background(ModernDesignSystem.Colors.background)
}
