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
 * - Enhanced accessibility and user experience
 * - Search and filter capabilities
 * - Detailed scan information with safety indicators
 */
struct HistoryView: View {
    @StateObject private var scanService = ScanService.shared
    @EnvironmentObject var notificationManager: NotificationManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedFilter: ScanFilter = .all
    @State private var showingFilters = false
    @State private var selectedScan: Scan?
    @State private var showingScanDetail = false
    @State private var showingClearHistoryAlert = false
    
    enum ScanFilter: String, CaseIterable {
        case all = "All"
        case safe = "Safe"
        case caution = "Caution"
        case unsafe = "Unsafe"
        
        var color: Color {
            switch self {
            case .all: return ModernDesignSystem.Colors.textPrimary
            case .safe: return ModernDesignSystem.Colors.safe
            case .caution: return ModernDesignSystem.Colors.warning
            case .unsafe: return ModernDesignSystem.Colors.error
            }
        }
    }
    
    var filteredScans: [Scan] {
        let scans = scanService.recentScans
        
        // Filter by search text
        let searchFiltered = searchText.isEmpty ? scans : scans.filter { scan in
            scan.result?.productName?.localizedCaseInsensitiveContains(searchText) == true
        }
        
        // Filter by safety status
        switch selectedFilter {
        case .all:
            return searchFiltered
        case .safe:
            return searchFiltered.filter { $0.result?.overallSafety == "safe" }
        case .caution:
            return searchFiltered.filter { $0.result?.overallSafety == "caution" }
        case .unsafe:
            return searchFiltered.filter { $0.result?.overallSafety == "unsafe" }
        }
    }
    
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
                        dismiss()
                        notificationManager.handleNavigateToScan()
                    })
                } else {
                    VStack(spacing: 0) {
                        // Search and Filter Header
                        SearchAndFilterHeader(
                            searchText: $searchText,
                            selectedFilter: $selectedFilter,
                            showingFilters: $showingFilters,
                            scanCount: filteredScans.count
                        )
                        
                        // Scan History List
                        if filteredScans.isEmpty {
                            EmptyFilterResultsView(filter: selectedFilter)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: ModernDesignSystem.Spacing.md) {
                                    ForEach(filteredScans) { scan in
                                        ModernScanHistoryCard(
                                            scan: scan,
                                            onTap: {
                                                selectedScan = scan
                                                showingScanDetail = true
                                            }
                                        )
                                    }
                                }
                                .padding(ModernDesignSystem.Spacing.md)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Scan History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                if !scanService.recentScans.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            showingClearHistoryAlert = true
                        }
                        .foregroundColor(ModernDesignSystem.Colors.error)
                    }
                }
            }
            .onAppear {
                scanService.loadRecentScans()
            }
        }
        .sheet(isPresented: $showingScanDetail) {
            if let scan = selectedScan {
                ScanDetailView(scan: scan)
            }
        }
        .alert("Clear Scan History", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearScanHistory()
            }
        } message: {
            Text("This will permanently delete all your scan history from the server. This action cannot be undone.")
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Clear all scan history from server and local storage
     */
    private func clearScanHistory() {
        Task {
            do {
                try await scanService.clearAllScans()
                await MainActor.run {
                    scanService.recentScans = []
                }
            } catch {
                await MainActor.run {
                    // Handle error - could show an alert here
                    print("Failed to clear scan history: \(error.localizedDescription)")
                }
            }
        }
    }
}

/**
 * Search and Filter Header - Trust & Nature Design System
 * 
 * Features:
 * - Modern search bar with Trust & Nature styling
 * - Filter chips with semantic colors
 * - Clean, accessible interface
 * - Proper spacing and typography
 */
struct SearchAndFilterHeader: View {
    @Binding var searchText: String
    @Binding var selectedFilter: HistoryView.ScanFilter
    @Binding var showingFilters: Bool
    let scanCount: Int
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                TextField("Search scans...", text: $searchText)
                    .font(ModernDesignSystem.Typography.body)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
            }
            .padding(ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.softCream)
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
            
            // Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    ForEach(HistoryView.ScanFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            title: filter.rawValue,
                            isSelected: selectedFilter == filter,
                            color: filter.color,
                            action: { selectedFilter = filter }
                        )
                    }
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
            }
            
            // Results Count
            HStack {
                Text("\(scanCount) scan\(scanCount == 1 ? "" : "s") found")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.md)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
    }
}

/**
 * Filter Chip - Trust & Nature Design System
 * 
 * Features:
 * - Semantic color coding for different filter types
 * - Smooth selection animations
 * - Accessible design with proper contrast
 * - Consistent with design system spacing
 */
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ModernDesignSystem.Typography.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, ModernDesignSystem.Spacing.md)
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                .background(
                    isSelected ? color : color.opacity(0.1)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(color, lineWidth: isSelected ? 0 : 1)
                )
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/**
 * Modern Scan History Card - Trust & Nature Design System
 * 
 * Features:
 * - Enhanced card design with better visual hierarchy
 * - Comprehensive scan information display
 * - Trust & Nature color palette for safety indicators
 * - Smooth animations and interactions
 * - Accessibility support
 */
struct ModernScanHistoryCard: View {
    let scan: Scan
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                // Header with product name and safety status
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text(scan.result?.productName ?? "Unknown Product")
                            .font(ModernDesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        Text(scan.createdAt, style: .date)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    if let result = scan.result {
                        SafetyStatusIndicator(
                            safety: result.overallSafety,
                            size: .medium
                        )
                    }
                }
                
                // Scan Details
                if let result = scan.result {
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        // Ingredients and confidence
                        HStack(spacing: ModernDesignSystem.Spacing.md) {
                            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                                Image(systemName: "list.bullet")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                
                                Text("\(result.ingredientsFound.count) ingredients")
                                    .font(ModernDesignSystem.Typography.subheadline)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Confidence score with star rating
                            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                                Image(systemName: "star.fill")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                                
                                Text("\(Int(result.confidenceScore * 100))%")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            }
                        }
                        
                        // Safety summary
                        if !result.ingredientsFound.isEmpty {
                            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                Image(systemName: "shield.checkered")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(safetyColor)
                                
                                Text(safetySummary)
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
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
                color: Color.black.opacity(0.05),
                radius: 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scan of \(scan.result?.productName ?? "unknown product")")
        .accessibilityHint("Tap to view detailed scan results")
    }
    
    private var safetyColor: Color {
        guard let result = scan.result else { return ModernDesignSystem.Colors.textSecondary }
        
        switch result.overallSafety {
        case "safe": return ModernDesignSystem.Colors.safe
        case "caution": return ModernDesignSystem.Colors.warning
        case "unsafe": return ModernDesignSystem.Colors.error
        default: return ModernDesignSystem.Colors.textSecondary
        }
    }
    
    private var safetySummary: String {
        guard let result = scan.result else { return "No analysis available" }
        
        switch result.overallSafety {
        case "safe": return "All ingredients appear safe"
        case "caution": return "Some ingredients may cause issues"
        case "unsafe": return "Contains unsafe ingredients"
        default: return "Analysis incomplete"
        }
    }
}

/**
 * Empty Filter Results View - Trust & Nature Design System
 * 
 * Features:
 * - Contextual empty state based on selected filter
 * - Encouraging messaging with clear next steps
 * - Trust & Nature color palette and typography
 * - Proper accessibility support
 */
struct EmptyFilterResultsView: View {
    let filter: HistoryView.ScanFilter
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Spacer()
            
            // Empty state icon
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary.opacity(0.4))
            
            // Empty state content
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Text(emptyStateTitle)
                    .font(ModernDesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(emptyStateMessage)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ModernDesignSystem.Spacing.xl)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateIcon: String {
        switch filter {
        case .all: return "magnifyingglass"
        case .safe: return "checkmark.shield"
        case .caution: return "exclamationmark.triangle"
        case .unsafe: return "xmark.shield"
        }
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .all: return "No Scans Found"
        case .safe: return "No Safe Scans"
        case .caution: return "No Caution Scans"
        case .unsafe: return "No Unsafe Scans"
        }
    }
    
    private var emptyStateMessage: String {
        switch filter {
        case .all: return "Try adjusting your search or start scanning to build your history."
        case .safe: return "All your scans so far have safety concerns. Keep scanning to find safe options!"
        case .caution: return "No scans with caution warnings found. This is good news!"
        case .unsafe: return "No unsafe ingredients detected yet. Your pets are staying safe!"
        }
    }
}

/**
 * Empty History State - Trust & Nature Design System
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
 * Scan Detail View - Trust & Nature Design System
 * 
 * Features:
 * - Comprehensive scan information display
 * - Detailed ingredient analysis
 * - Safety recommendations
 * - Trust & Nature color palette throughout
 * - Proper accessibility support
 */
struct ScanDetailView: View {
    let scan: Scan
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // Scan Header
                    ScanDetailHeader(scan: scan)
                    
                    // Safety Summary
                    if let result = scan.result {
                        SafetySummaryCard(result: result)
                        
                        // Ingredients List
                        IngredientsListCard(ingredients: result.ingredientsFound)
                        
                        // Recommendations
                        ScanRecommendationsCard(result: result)
                    }
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(ModernDesignSystem.Colors.softCream)
            .navigationTitle("Scan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/**
 * Scan Detail Header - Trust & Nature Design System
 */
struct ScanDetailHeader: View {
    let scan: Scan
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(scan.result?.productName ?? "Unknown Product")
                        .font(ModernDesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text(scan.createdAt, style: .date)
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                if let result = scan.result {
                    SafetyStatusIndicator(
                        safety: result.overallSafety,
                        size: .large
                    )
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
}

/**
 * Safety Summary Card - Trust & Nature Design System
 */
struct SafetySummaryCard: View {
    let result: ScanResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Safety Summary")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            HStack(spacing: ModernDesignSystem.Spacing.lg) {
                SafetyMetric(
                    title: "Ingredients",
                    count: result.ingredientsFound.count,
                    color: ModernDesignSystem.Colors.primary
                )
                
                SafetyMetric(
                    title: "Confidence",
                    count: Int(result.confidenceScore * 100),
                    color: ModernDesignSystem.Colors.goldenYellow
                )
                
                SafetyMetric(
                    title: "Status",
                    count: 1,
                    color: safetyColor
                )
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
    
    private var safetyColor: Color {
        switch result.overallSafety {
        case "safe": return ModernDesignSystem.Colors.safe
        case "caution": return ModernDesignSystem.Colors.warning
        case "unsafe": return ModernDesignSystem.Colors.error
        default: return ModernDesignSystem.Colors.textSecondary
        }
    }
}

/**
 * Safety Metric - Trust & Nature Design System
 */
struct SafetyMetric: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xs) {
            Text("\(count)")
                .font(ModernDesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/**
 * Ingredients List Card - Trust & Nature Design System
 */
struct IngredientsListCard: View {
    let ingredients: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Ingredients Found")
                .font(ModernDesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            LazyVStack(spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(ingredients, id: \.self) { ingredient in
                    IngredientRow(ingredient: ingredient)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
}

/**
 * Ingredient Row - Trust & Nature Design System
 */
struct IngredientRow: View {
    let ingredient: String
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Ingredient icon
            Image(systemName: "leaf.fill")
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .font(ModernDesignSystem.Typography.caption)
            
            // Ingredient name
            Text(ingredient)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Spacer()
        }
    }
}

/**
 * Scan Recommendations Card - Trust & Nature Design System
 */
struct ScanRecommendationsCard: View {
    let result: ScanResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                
                Text("Recommendations")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            Text(recommendationText)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
    }
    
    private var recommendationText: String {
        switch result.overallSafety {
        case "unsafe":
            return "⚠️ This product contains unsafe ingredients. We recommend avoiding this product for your pet's safety."
        case "caution":
            return "⚠️ This product may cause issues for some pets. Monitor your pet closely if feeding this product."
        case "safe":
            return "✅ This product appears safe for your pet. All ingredients are within safe parameters."
        default:
            return "❓ Unable to determine safety status. Please consult with your veterinarian."
        }
    }
}

#Preview {
    HistoryView()
}