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
    @State private var searchText = ""
    @State private var selectedFilter: ScanFilter = .all
    @State private var showingFilters = false
    @State private var selectedScan: Scan?
    @State private var showingScanDetail = false
    
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
            .onAppear {
                scanService.loadRecentScans()
            }
        }
        .sheet(isPresented: $showingScanDetail) {
            if let scan = selectedScan {
                ScanDetailView(scan: scan)
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
    @State private var showingAddToDatabase = false
    @State private var showingSaveSuccess = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // Scan Header
                    ScanDetailHeader(scan: scan)
                    
                    // Raw extracted text (if available)
                    if let rawText = scan.rawText, !rawText.isEmpty {
                        ExtractedTextCard(text: rawText)
                    }
                    
                    // Safety Summary
                    if let result = scan.result {
                        SafetySummaryCard(result: result)
                        
                        // Ingredients List
                        IngredientsListCard(ingredients: result.ingredientsFound)
                        
                        // Recommendations
                        ScanRecommendationsCard(result: result)
                    }
                    
                    // Add to Database section (if barcode is available and not already in database)
                    if canAddToDatabase {
                        AddToDatabaseCard(onTap: { showingAddToDatabase = true })
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
            .sheet(isPresented: $showingAddToDatabase) {
                if let result = scan.result {
                    AddProductToDatabaseView(
                        scan: scan,
                        scanResult: result,
                        onSuccess: {
                            showingAddToDatabase = false
                            showingSaveSuccess = true
                        },
                        scannedBarcode: extractBarcodeFromRawText()
                    )
                }
            }
            .alert("Product Saved", isPresented: $showingSaveSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This product has been added to the database and will be available for other users.")
            }
        }
    }
    
    /// Check if this scan can be added to database
    /// Only allow if we have meaningful data to contribute
    private var canAddToDatabase: Bool {
        guard let result = scan.result else { return false }
        // Can add if we have ingredients or nutritional analysis
        return !result.ingredientsFound.isEmpty || scan.nutritionalAnalysis != nil
    }
    
    /// Extract barcode from raw text if available
    /// Looks for common barcode patterns in the OCR text
    private func extractBarcodeFromRawText() -> String? {
        guard let rawText = scan.rawText else { return nil }
        
        // Common barcode patterns (EAN-13, UPC-A, etc.)
        let barcodePatterns = [
            #"\b\d{13}\b"#,  // EAN-13 (13 digits)
            #"\b\d{12}\b"#,  // UPC-A (12 digits)
            #"\b\d{8}\b"#    // EAN-8 (8 digits)
        ]
        
        for pattern in barcodePatterns {
            if let range = rawText.range(of: pattern, options: .regularExpression) {
                return String(rawText[range])
            }
        }
        
        return nil
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

/**
 * Extracted Text Card - Shows the raw OCR text
 */
struct ExtractedTextCard: View {
    let text: String
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "text.viewfinder")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                
                Text("Extracted Text")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Text(isExpanded ? "Show Less" : "Show More")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
            
            Text(text)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .lineLimit(isExpanded ? nil : 5)
                .fixedSize(horizontal: false, vertical: true)
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
 * Add to Database Card - Prompts user to contribute scan data
 */
struct AddToDatabaseCard: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(ModernDesignSystem.Typography.title2)
                        .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                    
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Add to Database")
                            .font(ModernDesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text("Help other pet owners by sharing this product data")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ModernDesignSystem.Colors.primary.opacity(0.05),
                        ModernDesignSystem.Colors.goldenYellow.opacity(0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                ModernDesignSystem.Colors.primary,
                                ModernDesignSystem.Colors.goldenYellow
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/**
 * Add Product to Database View - Form for contributing scan data
 */
struct AddProductToDatabaseView: View {
    let scan: Scan
    let scanResult: ScanResult
    let onSuccess: () -> Void
    let scannedBarcode: String?  // Optional barcode from scan
    
    @Environment(\.dismiss) private var dismiss
    @State private var productName: String = ""
    @State private var brand: String = ""
    @State private var category: String = "Dog Food"
    @State private var species: String = "Dog"  // Dog or Cat
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNutritionalFields = false
    @State private var showIngredientsFields = false
    
    // Editable ingredients list - pre-populated from scan
    @State private var ingredients: [String] = []
    @State private var ingredientsText: String = ""
    
    // Editable nutritional fields - pre-populated from scan
    @State private var caloriesPer100g: String = ""
    @State private var proteinPercent: String = ""
    @State private var fatPercent: String = ""
    @State private var fiberPercent: String = ""
    @State private var moisturePercent: String = ""
    @State private var ashPercent: String = ""
    
    // Default metadata
    let language = "en"
    let country = "en:united-states"  // Format: language:country
    let externalSource = "snifftest"
    
    let categories = ["Dog Food", "Cat Food", "Dog Treats", "Cat Treats", "Supplements", "Other"]
    let speciesOptions = ["Dog", "Cat"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // Info banner
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(ModernDesignSystem.Colors.primary)
                            
                            Text("Help the Community")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        }
                        
                        Text("By adding this product to the database, you're helping other pet owners make informed decisions.")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(ModernDesignSystem.Spacing.md)
                    .background(ModernDesignSystem.Colors.primary.opacity(0.1))
                    .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                    
                    // Form fields
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.lg) {
                        // Product Name
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Product Name *")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            TextField("e.g., Premium Adult Dog Food", text: $productName)
                                .textFieldStyle(ModernTextFieldStyle())
                        }
                        
                        // Brand
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Brand")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            TextField("e.g., Blue Buffalo", text: $brand)
                                .textFieldStyle(ModernTextFieldStyle())
                        }
                        
                        // Barcode (if available from scan)
                        if let barcode = scannedBarcode {
                            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                                HStack {
                                    Text("Barcode")
                                        .font(ModernDesignSystem.Typography.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                    
                                    Image(systemName: "barcode.viewfinder")
                                        .font(ModernDesignSystem.Typography.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                                }
                                
                                // Read-only barcode display
                                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                    Text(barcode)
                                        .font(ModernDesignSystem.Typography.body)
                                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                        .padding(ModernDesignSystem.Spacing.md)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(ModernDesignSystem.Colors.primary.opacity(0.05))
                                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                                .stroke(ModernDesignSystem.Colors.primary, lineWidth: 1)
                                        )
                                    
                                    // Copy button
                                    Button(action: {
                                        UIPasteboard.general.string = barcode
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(ModernDesignSystem.Typography.caption)
                                            .foregroundColor(ModernDesignSystem.Colors.primary)
                                            .padding(ModernDesignSystem.Spacing.sm)
                                    }
                                }
                                
                                Text("Scanned from product label")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Category")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Picker("Category", selection: $category) {
                                ForEach(categories, id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(ModernDesignSystem.Spacing.md)
                            .background(ModernDesignSystem.Colors.softCream)
                            .cornerRadius(ModernDesignSystem.CornerRadius.small)
                            .overlay(
                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                            )
                            .onChange(of: category) { oldValue, newValue in
                                // Auto-update species based on category
                                if newValue.contains("Dog") {
                                    species = "Dog"
                                } else if newValue.contains("Cat") {
                                    species = "Cat"
                                }
                            }
                        }
                        
                        // Species Field
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            HStack {
                                Text("Species")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                
                                Spacer()
                                
                                Text("Auto-selected based on category")
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary.opacity(0.7))
                                    .italic()
                            }
                            
                            Picker("Species", selection: $species) {
                                ForEach(speciesOptions, id: \.self) { speciesOption in
                                    Text(speciesOption).tag(speciesOption)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(ModernDesignSystem.Spacing.sm)
                            .background(ModernDesignSystem.Colors.softCream)
                            .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        }
                        
                        // Ingredients Section (Expandable)
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                            Button(action: { showIngredientsFields.toggle() }) {
                                HStack {
                                    Image(systemName: "list.bullet")
                                        .foregroundColor(ModernDesignSystem.Colors.primary)
                                    
                                    Text("Ingredients List")
                                        .font(ModernDesignSystem.Typography.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                    
                                    Spacer()
                                    
                                    Text("\(ingredients.count) items - Verify & Edit")
                                        .font(ModernDesignSystem.Typography.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    
                                    Image(systemName: showIngredientsFields ? "chevron.up" : "chevron.down")
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if showIngredientsFields {
                                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                                    // Info message
                                    HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                                        Image(systemName: "info.circle.fill")
                                            .font(ModernDesignSystem.Typography.caption)
                                            .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                                        
                                        Text("These ingredients were auto-extracted from the label. Review carefully and edit if needed. Separate with commas.")
                                            .font(ModernDesignSystem.Typography.caption)
                                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    }
                                    .padding(ModernDesignSystem.Spacing.sm)
                                    .background(ModernDesignSystem.Colors.goldenYellow.opacity(0.1))
                                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                                    
                                    // Editable ingredients text area
                                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                                        Text("Ingredients (comma-separated)")
                                            .font(ModernDesignSystem.Typography.caption)
                                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                        
                                        TextEditor(text: $ingredientsText)
                                            .font(ModernDesignSystem.Typography.body)
                                            .frame(minHeight: 100)
                                            .padding(ModernDesignSystem.Spacing.sm)
                                            .background(Color.white)
                                            .cornerRadius(ModernDesignSystem.CornerRadius.small)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                                    .stroke(ModernDesignSystem.Colors.primary, lineWidth: 2)
                                            )
                                            .onChange(of: ingredientsText) { _, newValue in
                                                // Update ingredients array when text changes
                                                updateIngredientsFromText(newValue)
                                            }
                                    }
                                    
                                    // Quick actions
                                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                        Text("\(ingredients.count) ingredients")
                                            .font(ModernDesignSystem.Typography.caption)
                                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            // Reset to original parsed ingredients
                                            ingredients = scanResult.ingredientsFound
                                            ingredientsText = ingredients.joined(separator: ", ")
                                        }) {
                                            HStack(spacing: ModernDesignSystem.Spacing.xs) {
                                                Image(systemName: "arrow.counterclockwise")
                                                Text("Reset")
                                            }
                                            .font(ModernDesignSystem.Typography.caption)
                                            .foregroundColor(ModernDesignSystem.Colors.primary)
                                        }
                                    }
                                }
                                .padding(.top, ModernDesignSystem.Spacing.sm)
                            }
                        }
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(ModernDesignSystem.Colors.softCream)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                        
                        // Nutritional Data Section (Expandable)
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                            Button(action: { showNutritionalFields.toggle() }) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .foregroundColor(ModernDesignSystem.Colors.primary)
                                    
                                    Text("Nutritional Data")
                                        .font(ModernDesignSystem.Typography.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                    
                                    Spacer()
                                    
                                    Text(hasNutritionalData ? "Verify & Edit" : "Add (Optional)")
                                        .font(ModernDesignSystem.Typography.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    
                                    Image(systemName: showNutritionalFields ? "chevron.up" : "chevron.down")
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if showNutritionalFields {
                                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                                    // Info message about auto-parsed data
                                    if hasNutritionalData {
                                        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                                            Image(systemName: "info.circle.fill")
                                                .font(ModernDesignSystem.Typography.caption)
                                                .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                                            
                                            Text("These values were automatically extracted from the label. Please verify and correct if needed.")
                                                .font(ModernDesignSystem.Typography.caption)
                                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                        }
                                        .padding(ModernDesignSystem.Spacing.sm)
                                        .background(ModernDesignSystem.Colors.goldenYellow.opacity(0.1))
                                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                                    }
                                    
                                    // Nutritional fields
                                    NutrientField(label: "Calories (per 100g)", value: $caloriesPer100g, unit: "kcal")
                                    NutrientField(label: "Protein", value: $proteinPercent, unit: "%")
                                    NutrientField(label: "Fat", value: $fatPercent, unit: "%")
                                    NutrientField(label: "Fiber", value: $fiberPercent, unit: "%")
                                    NutrientField(label: "Moisture", value: $moisturePercent, unit: "%")
                                    NutrientField(label: "Ash", value: $ashPercent, unit: "%")
                                }
                                .padding(.top, ModernDesignSystem.Spacing.sm)
                            }
                        }
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(ModernDesignSystem.Colors.softCream)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                        
                        // Data Preview Summary
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                            Text("Data to be saved:")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            
                            if let barcode = scannedBarcode {
                                DataPreviewRow(label: "Barcode", value: barcode)
                            }
                            DataPreviewRow(label: "Ingredients", value: "\(ingredients.count) items")
                            DataPreviewRow(label: "Nutritional Fields", value: nutritionalFieldCount)
                            
                            if let rawText = scan.rawText, !rawText.isEmpty {
                                DataPreviewRow(label: "Raw OCR Text", value: "Included")
                            }
                        }
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(ModernDesignSystem.Colors.primary.opacity(0.05))
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
                        )
                    }
                    .padding(ModernDesignSystem.Spacing.md)
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.error)
                            .padding(ModernDesignSystem.Spacing.md)
                            .background(ModernDesignSystem.Colors.error.opacity(0.1))
                            .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    }
                    
                    // Save button
                    Button(action: saveProduct) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isLoading ? "Saving..." : "Save to Database")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(ModernDesignSystem.Spacing.md)
                        .background(
                            productName.isEmpty ? ModernDesignSystem.Colors.textSecondary :
                            ModernDesignSystem.Colors.primary
                        )
                        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                    }
                    .disabled(productName.isEmpty || isLoading)
                    .padding(.horizontal, ModernDesignSystem.Spacing.md)
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(ModernDesignSystem.Colors.softCream)
            .navigationTitle("Add Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Pre-fill product name if available
            if let productName = scanResult.productName, !productName.isEmpty {
                self.productName = productName
            }
            
            // Pre-fill brand if available
            if let brand = scanResult.brand, !brand.isEmpty {
                self.brand = brand
            }
            
            // Pre-fill ingredients from scan
            self.ingredients = scanResult.ingredientsFound
            self.ingredientsText = scanResult.ingredientsFound.joined(separator: ", ")
            
            // Auto-expand ingredients if we have them
            if !scanResult.ingredientsFound.isEmpty {
                self.showIngredientsFields = true
            }
            
            // Pre-fill nutritional data from OCR parsing
            if let analysis = scan.nutritionalAnalysis {
                if let calories = analysis.caloriesPer100G {
                    self.caloriesPer100g = String(format: "%.1f", calories)
                }
                if let protein = analysis.proteinPercent {
                    self.proteinPercent = String(format: "%.1f", protein)
                }
                if let fat = analysis.fatPercent {
                    self.fatPercent = String(format: "%.1f", fat)
                }
                if let fiber = analysis.fiberPercent {
                    self.fiberPercent = String(format: "%.1f", fiber)
                }
                if let moisture = analysis.moisturePercent {
                    self.moisturePercent = String(format: "%.1f", moisture)
                }
                if let ash = analysis.ashPercent {
                    self.ashPercent = String(format: "%.1f", ash)
                }
                
                // Auto-expand if we have nutritional data
                if hasNutritionalData {
                    self.showNutritionalFields = true
                }
            }
        }
    }
    
    /// Check if we have any nutritional data from OCR
    private var hasNutritionalData: Bool {
        return scan.nutritionalAnalysis != nil
    }
    
    /// Count how many nutritional fields will be saved
    private var nutritionalFieldCount: String {
        var count = 0
        if !caloriesPer100g.isEmpty, Double(caloriesPer100g) != nil { count += 1 }
        if !proteinPercent.isEmpty, Double(proteinPercent) != nil { count += 1 }
        if !fatPercent.isEmpty, Double(fatPercent) != nil { count += 1 }
        if !fiberPercent.isEmpty, Double(fiberPercent) != nil { count += 1 }
        if !moisturePercent.isEmpty, Double(moisturePercent) != nil { count += 1 }
        if !ashPercent.isEmpty, Double(ashPercent) != nil { count += 1 }
        
        return count > 0 ? "\(count) field\(count == 1 ? "" : "s")" : "None"
    }
    
    /**
     * Update ingredients array from comma-separated text
     * 
     * Parses the text and cleans up ingredient names
     */
    private func updateIngredientsFromText(_ text: String) {
        // Split by commas and clean up each ingredient
        let parsed = text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        self.ingredients = parsed
    }
    
    /// Save product to database
    private func saveProduct() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Create nutritional info from scan data (matches database format)
                var nutritionalInfo: [String: Any] = [
                    "source": externalSource,  // "snifftest"
                    "external_id": scannedBarcode ?? scan.id,  // Use barcode or scan ID
                    "ingredients": ingredients  // User-verified ingredients
                ]
                
                // Add nutritional data from user-verified fields
                if !caloriesPer100g.isEmpty, let calories = Double(caloriesPer100g) {
                    nutritionalInfo["calories_per_100g"] = calories
                }
                if !proteinPercent.isEmpty, let protein = Double(proteinPercent) {
                    nutritionalInfo["protein_percentage"] = protein
                }
                if !fatPercent.isEmpty, let fat = Double(fatPercent) {
                    nutritionalInfo["fat_percentage"] = fat
                }
                if !fiberPercent.isEmpty, let fiber = Double(fiberPercent) {
                    nutritionalInfo["fiber_percentage"] = fiber
                }
                if !moisturePercent.isEmpty, let moisture = Double(moisturePercent) {
                    nutritionalInfo["moisture_percentage"] = moisture
                }
                if !ashPercent.isEmpty, let ash = Double(ashPercent) {
                    nutritionalInfo["ash_percentage"] = ash
                }
                
                // Add data quality score (user-verified data gets high score)
                nutritionalInfo["data_quality_score"] = 0.9
                
                // Create food item with all metadata
                let success = try await APIService.shared.createFoodItem(
                    name: productName,
                    brand: brand.isEmpty ? nil : brand,
                    barcode: scannedBarcode,  // Include scanned barcode
                    category: category,
                    species: species,  // Dog or Cat
                    language: language,  // "en"
                    country: country,  // "United States"
                    externalSource: externalSource,  // "snifftest"
                    nutritionalInfo: nutritionalInfo
                )
                
                await MainActor.run {
                    isLoading = false
                    if success {
                        onSuccess()
                    } else {
                        errorMessage = "Failed to save product. Please try again."
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

/**
 * Data Preview Row - Shows a key-value pair
 */
struct DataPreviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(ModernDesignSystem.Typography.caption)
                .fontWeight(.medium)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
        }
    }
}

/**
 * Modern Text Field Style
 */
struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.softCream)
            .cornerRadius(ModernDesignSystem.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
    }
}

/**
 * Nutrient Field - Editable nutritional value field with unit display
 * 
 * Allows users to verify and edit auto-parsed nutritional data
 */
struct NutrientField: View {
    let label: String
    @Binding var value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            Text(label)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                TextField("Optional", text: $value)
                    .keyboardType(.decimalPad)
                    .font(ModernDesignSystem.Typography.body)
                    .padding(ModernDesignSystem.Spacing.sm)
                    .background(Color.white)
                    .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                            .stroke(
                                value.isEmpty ? ModernDesignSystem.Colors.borderPrimary : 
                                ModernDesignSystem.Colors.primary,
                                lineWidth: value.isEmpty ? 1 : 2
                            )
                    )
                
                Text(unit)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .frame(width: 40, alignment: .leading)
            }
        }
    }
}

#Preview {
    HistoryView()
}