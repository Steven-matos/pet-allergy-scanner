//
//  VisitSummaryView.swift
//  SniffTest
//
//  Created for Gap #2: Vet-Readable Packaging
//  One-tap, read-only vet visit summary view
//

import SwiftUI

/**
 * VisitSummaryView - Vet-Readable Pet Health Summary
 *
 * One-tap view designed for veterinary visits that provides:
 * - Compressed clarity (not dashboards)
 * - Last 30/60/90 days of data
 * - Food changes with flagged ingredients
 * - Weight trend sparkline
 * - Active medications
 * - Owner notes
 * - Known sensitivities
 *
 * Design Principle: "If a vet had 10 minutes with this app, would it make the visit clearer?"
 *
 * ⚠️ No diagnoses. No recommendations. No PDFs initially.
 */
struct VisitSummaryView: View {
    let pet: Pet
    
    @StateObject private var service = VisitSummaryService.shared
    @State private var selectedDateRange: VisitSummaryDateRange = .thirtyDays
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading {
                    LoadingView()
                } else if let summary = service.currentSummary {
                    SummaryContentView(summary: summary, selectedDateRange: $selectedDateRange)
                } else if let error = service.errorMessage {
                    ErrorView(message: error, onRetry: loadSummary)
                } else {
                    EmptyStateView(onGenerate: loadSummary)
                }
            }
            .background(ModernDesignSystem.Colors.softCream)
            .navigationTitle("Visit Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(ModernDesignSystem.Colors.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    dateRangePicker
                }
            }
        }
        .task {
            await loadSummaryAsync()
        }
        .onChange(of: selectedDateRange) { _, _ in
            loadSummary()
        }
    }
    
    // MARK: - Components
    
    /// Date range picker
    private var dateRangePicker: some View {
        Menu {
            ForEach(VisitSummaryDateRange.allCases) { range in
                Button(range.displayName) {
                    selectedDateRange = range
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedDateRange.shortName)
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundColor(ModernDesignSystem.Colors.primary)
        }
    }
    
    // MARK: - Actions
    
    private func loadSummary() {
        Task {
            await loadSummaryAsync()
        }
    }
    
    private func loadSummaryAsync() async {
        do {
            _ = try await service.generateSummary(for: pet, dateRange: selectedDateRange)
        } catch {
            // Error is handled by service
        }
    }
}

// MARK: - Summary Content View

/// Main content view when summary is loaded
private struct SummaryContentView: View {
    let summary: VisitSummary
    @Binding var selectedDateRange: VisitSummaryDateRange
    
    var body: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Pet header
                PetHeaderCard(pet: summary.pet, generatedAt: summary.generatedAt)
                
                // Stats overview
                StatsOverviewCard(stats: summary.stats)
                
                // Known sensitivities
                if !summary.knownSensitivities.isEmpty {
                    SensitivitiesCard(sensitivities: summary.knownSensitivities)
                }
                
                // Weight trend
                if summary.weightTrend.hasData {
                    WeightTrendCard(weightTrend: summary.weightTrend)
                }
                
                // Active medications
                if !summary.activeMedications.isEmpty {
                    MedicationsCard(medications: summary.activeMedications)
                }
                
                // Food changes
                if !summary.foodChanges.isEmpty {
                    FoodChangesCard(foodChanges: summary.foodChanges)
                }
                
                // Health events
                if !summary.recentHealthEvents.isEmpty {
                    HealthEventsCard(events: summary.recentHealthEvents)
                }
                
                // Disclaimer
                DisclaimerCard()
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
    }
}

// MARK: - Pet Header Card

private struct PetHeaderCard: View {
    let pet: Pet
    let generatedAt: Date
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            // Pet icon
            ZStack {
                Circle()
                    .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: pet.species.icon)
                    .font(.system(size: 28))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
            }
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(pet.name)
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                if let age = pet.ageDescription {
                    Text(age)
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Text("Generated \(generatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.surface)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
}

// MARK: - Stats Overview Card

private struct StatsOverviewCard: View {
    let stats: VisitSummaryStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            Text("Overview")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                StatItem(
                    value: "\(stats.totalFoodChanges)",
                    label: "Foods",
                    icon: "fork.knife"
                )
                
                StatItem(
                    value: "\(stats.flaggedIngredientCount)",
                    label: "Flags",
                    icon: "exclamationmark.triangle",
                    highlight: stats.flaggedIngredientCount > 0
                )
                
                StatItem(
                    value: "\(stats.activeMedicationCount)",
                    label: "Meds",
                    icon: "pills"
                )
                
                StatItem(
                    value: "\(stats.healthEventCount)",
                    label: "Events",
                    icon: "heart"
                )
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
    }
}

private struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    var highlight: Bool = false
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(highlight ? ModernDesignSystem.Colors.warmCoral : ModernDesignSystem.Colors.primary)
            
            Text(value)
                .font(ModernDesignSystem.Typography.title2)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text(label)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sensitivities Card

private struct SensitivitiesCard: View {
    let sensitivities: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "exclamationmark.shield.fill")
                    .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                Text("Known Sensitivities")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            FlowLayout(spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(sensitivities, id: \.self) { sensitivity in
                    Text(sensitivity)
                        .font(ModernDesignSystem.Typography.subheadline)
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, ModernDesignSystem.Spacing.xs)
                        .background(ModernDesignSystem.Colors.warmCoral.opacity(0.1))
                        .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.warmCoral.opacity(0.05))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.warmCoral.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Weight Trend Card

private struct WeightTrendCard: View {
    let weightTrend: WeightTrendData
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "scalemass.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("Weight Trend")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                if let change = weightTrend.overallChangePercent {
                    HStack(spacing: 4) {
                        Image(systemName: weightTrend.trend.icon)
                            .font(.system(size: 12))
                        Text(String(format: "%.1f%%", abs(change)))
                            .font(ModernDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(trendColor)
                }
            }
            
            if let current = weightTrend.endWeight {
                HStack {
                    Text("Current:")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    Text(String(format: "%.1f kg", current))
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                }
            }
            
            // Sparkline placeholder (simplified for initial implementation)
            if weightTrend.dataPoints.count >= 2 {
                WeightSparkline(dataPoints: weightTrend.dataPoints)
                    .frame(height: 40)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
    }
    
    private var trendColor: Color {
        switch weightTrend.trend {
        case .increasing: return ModernDesignSystem.Colors.goldenYellow
        case .decreasing: return ModernDesignSystem.Colors.warmCoral
        case .stable: return ModernDesignSystem.Colors.safe
        case .insufficient: return ModernDesignSystem.Colors.textSecondary
        }
    }
}

/// Simple sparkline visualization
private struct WeightSparkline: View {
    let dataPoints: [WeightDataPoint]
    
    var body: some View {
        GeometryReader { geometry in
            let weights = dataPoints.map { $0.weightKg }
            let minWeight = weights.min() ?? 0
            let maxWeight = weights.max() ?? 1
            let range = maxWeight - minWeight
            
            Path { path in
                guard dataPoints.count >= 2 else { return }
                
                let stepX = geometry.size.width / CGFloat(dataPoints.count - 1)
                
                for (index, point) in dataPoints.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedY = range > 0 ? (point.weightKg - minWeight) / range : 0.5
                    let y = geometry.size.height * (1 - CGFloat(normalizedY))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(ModernDesignSystem.Colors.primary, lineWidth: 2)
        }
    }
}

// MARK: - Medications Card

private struct MedicationsCard: View {
    let medications: [ActiveMedication]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "pills.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("Active Medications")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            ForEach(medications) { med in
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(med.name)
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        Text(med.dosage)
                        Text("•")
                        Text(med.frequency)
                    }
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Text(med.durationDescription)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(ModernDesignSystem.Spacing.md)
                .background(ModernDesignSystem.Colors.primary.opacity(0.05))
                .cornerRadius(ModernDesignSystem.CornerRadius.small)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
    }
}

// MARK: - Food Changes Card

private struct FoodChangesCard: View {
    let foodChanges: [FoodChangeEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("Food Changes")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            ForEach(foodChanges) { change in
                FoodChangeRow(change: change)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
    }
}

private struct FoodChangeRow: View {
    let change: FoodChangeEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
            HStack {
                Image(systemName: change.changeType.icon)
                    .font(.system(size: 14))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                
                Text(change.displayName)
                    .font(ModernDesignSystem.Typography.bodyEmphasized)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text(change.date.formatted(date: .abbreviated, time: .omitted))
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            // Flagged ingredients
            if !change.flaggedIngredients.isEmpty {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    ForEach(change.flaggedIngredients) { ingredient in
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(severityColor(ingredient.severity))
                            
                            Text("\(ingredient.name)")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Text("- \(ingredient.reason)")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .padding(.leading, ModernDesignSystem.Spacing.lg)
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.softCream)
        .cornerRadius(ModernDesignSystem.CornerRadius.small)
    }
    
    private func severityColor(_ severity: FlaggedIngredientSeverity) -> Color {
        switch severity {
        case .caution: return ModernDesignSystem.Colors.goldenYellow
        case .unsafe: return ModernDesignSystem.Colors.warmCoral
        case .knownSensitivity: return ModernDesignSystem.Colors.warmCoral
        }
    }
}

// MARK: - Health Events Card

private struct HealthEventsCard: View {
    let events: [HealthEventSummary]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("Health Events")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            ForEach(events) { event in
                HStack {
                    Image(systemName: event.type.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: event.type.colorCode))
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text(event.date.formatted(date: .abbreviated, time: .omitted))
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Severity indicator
                    SeverityBadge(level: event.severityLevel)
                }
                .padding(ModernDesignSystem.Spacing.sm)
            }
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .modernCard()
    }
}

private struct SeverityBadge: View {
    let level: Int
    
    var body: some View {
        Text(severityText)
            .font(ModernDesignSystem.Typography.caption)
            .padding(.horizontal, ModernDesignSystem.Spacing.sm)
            .padding(.vertical, 2)
            .background(severityColor.opacity(0.1))
            .foregroundColor(severityColor)
            .cornerRadius(ModernDesignSystem.CornerRadius.small)
    }
    
    private var severityText: String {
        switch level {
        case 1: return "Mild"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "High"
        case 5: return "Severe"
        default: return "Unknown"
        }
    }
    
    private var severityColor: Color {
        switch level {
        case 1, 2: return ModernDesignSystem.Colors.safe
        case 3: return ModernDesignSystem.Colors.goldenYellow
        case 4, 5: return ModernDesignSystem.Colors.warmCoral
        default: return ModernDesignSystem.Colors.textSecondary
        }
    }
}

// MARK: - Disclaimer Card

private struct DisclaimerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
            HStack(spacing: ModernDesignSystem.Spacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                Text("For Veterinary Discussion")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            }
            
            Text("This summary provides historical data to support veterinary consultations. It does not contain diagnoses or medical recommendations.")
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .padding(ModernDesignSystem.Spacing.md)
        .background(ModernDesignSystem.Colors.primary.opacity(0.05))
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
    }
}

// MARK: - Supporting Views

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(ModernDesignSystem.Colors.primary)
            
            Text("Generating summary...")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(ModernDesignSystem.Colors.warmCoral)
            
            Text("Unable to Generate Summary")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text(message)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") { onRetry() }
                .modernButton(style: .primary)
        }
        .padding(ModernDesignSystem.Spacing.xl)
    }
}

private struct EmptyStateView: View {
    let onGenerate: () -> Void
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Generate Visit Summary")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Text("Create a comprehensive summary of your pet's health data for your next vet visit.")
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Generate Summary") { onGenerate() }
                .modernButton(style: .primary)
        }
        .padding(ModernDesignSystem.Spacing.xl)
    }
}

// MARK: - Flow Layout

/// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0
        
        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            height = y + lineHeight
        }
    }
}
