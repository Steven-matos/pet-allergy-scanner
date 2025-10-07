//
//  HistoryView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/**
 * Scan History View - Redesigned with Trust & Nature Design System
 * 
 * Features:
 * - Soft cream background for warmth and comfort
 * - Modern card-based layout for scan history items
 * - Consistent spacing and typography following design system
 * - Trust & Nature color palette throughout
 * - Proper loading and empty states
 * - Navigation to scan view via NotificationManager
 */
struct HistoryView: View {
    @StateObject private var scanService = ScanService.shared
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Trust & Nature background
                ModernDesignSystem.Colors.softCream
                    .ignoresSafeArea()
                
                if scanService.isLoading {
                    ModernLoadingView(message: "Loading your scan history...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if scanService.recentScans.isEmpty {
                    EmptyHistoryView(onStartScanning: {
                        notificationManager.handleNavigateToScan()
                    })
                } else {
                    ScrollView {
                        LazyVStack(spacing: ModernDesignSystem.Spacing.md) {
                            ForEach(scanService.recentScans) { scan in
                                ScanHistoryRowView(scan: scan)
                            }
                        }
                        .padding(ModernDesignSystem.Spacing.md)
                    }
                }
            }
            .navigationTitle("Scan History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .onAppear {
                scanService.loadRecentScans()
            }
        }
    }
}

/**
 * Empty History State - Redesigned with Trust & Nature Design System
 * 
 * Features:
 * - Uses ModernEmptyState component for consistency
 * - Trust & Nature color palette and typography
 * - Warm, inviting messaging that encourages action
 * - Proper spacing and accessibility
 * - Navigation callback to switch to scan tab
 */
struct EmptyHistoryView: View {
    let onStartScanning: () -> Void
    
    var body: some View {
        ModernEmptyState(
            icon: "clock.arrow.circlepath",
            title: "No Scans Yet",
            message: "Start scanning pet food ingredients to build your nutrition history and keep your pets healthy.",
            actionTitle: "Start Scanning",
            action: onStartScanning
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/**
 * Scan History Row View - Redesigned with Trust & Nature Design System
 * 
 * Features:
 * - Modern card styling with soft cream background
 * - Trust & Nature color palette for safety indicators
 * - Proper spacing and typography hierarchy
 * - Status indicators with semantic colors
 * - Clean, professional layout
 */
struct ScanHistoryRowView: View {
    let scan: Scan
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Header with product name and safety status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(scan.result?.productName ?? "Unknown Product")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Text(scan.createdAt, style: .date)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                if let result = scan.result {
                    StatusIndicator(
                        status: result.overallSafety,
                        text: result.safetyDisplayName
                    )
                }
            }
            
            // Ingredients count and additional info
            if let result = scan.result {
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Image(systemName: "list.bullet")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Text("Found \(result.ingredientsFound.count) ingredients")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    // Confidence score indicator
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                        
                        Text("\(Int(result.confidenceScore * 100))%")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
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

#Preview {
    HistoryView()
}
