//
//  Phase3NutritionView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/**
 * Phase 3 Nutrition View
 * 
 * Comprehensive nutrition management interface with support for:
 * - Weight management and tracking
 * - Nutritional trends and analytics
 * - Food comparison and analysis
 * - Advanced health insights
 * 
 * Follows SOLID principles with single responsibility for Phase 3 features
 * Implements DRY by reusing common UI components
 * Follows KISS by keeping the interface organized and intuitive
 */
struct Phase3NutritionView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var petService = PetService.shared
    @State private var selectedPet: Pet?
    @State private var selectedTab = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading nutrition data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let pet = selectedPet {
                    phase3Content(for: pet)
                } else {
                    petSelectionView
                }
            }
            .navigationTitle("Advanced Nutrition")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadNutritionData()
                    }
                    .disabled(selectedPet == nil || isLoading)
                }
            }
        }
        .onAppear {
            loadNutritionData()
        }
    }
    
    // MARK: - Pet Selection View
    
    private var petSelectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Select a Pet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose a pet to access advanced nutrition features")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !petService.pets.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(petService.pets) { pet in
                        PetSelectionCard(pet: pet) {
                            selectedPet = pet
                            loadNutritionData()
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                Text("No pets found. Add a pet to get started.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
    
    // MARK: - Phase 3 Content
    
    @ViewBuilder
    private func phase3Content(for pet: Pet) -> some View {
        VStack(spacing: 0) {
            // Pet Header
            petHeaderSection(pet)
            
            // Tab Selection
            tabSelectionSection
            
            // Content based on selected tab
            TabView(selection: $selectedTab) {
                // Weight Management Tab
                WeightManagementView()
                    .environmentObject(authService)
                    .tag(0)
                
                // Nutritional Trends Tab
                NutritionalTrendsView()
                    .environmentObject(authService)
                    .tag(1)
                
                // Food Comparison Tab
                FoodComparisonView()
                    .environmentObject(authService)
                    .tag(2)
                
                // Advanced Analytics Tab
                AdvancedAnalyticsView()
                    .environmentObject(authService)
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
    
    // MARK: - Pet Header Section
    
    private func petHeaderSection(_ pet: Pet) -> some View {
        HStack {
            AsyncImage(url: URL(string: pet.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "pawprint.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(pet.species.capitalized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let weight = pet.weightKg {
                    Text("\(weight, specifier: "%.1f") kg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Change Pet") {
                selectedPet = nil
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Tab Selection Section
    
    private var tabSelectionSection: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabIcon(for: index))
                            .font(.title3)
                            .foregroundColor(selectedTab == index ? .blue : .gray)
                        
                        Text(tabTitle(for: index))
                            .font(.caption)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                            .foregroundColor(selectedTab == index ? .blue : .gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadNutritionData() {
        guard let pet = selectedPet else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            // Load nutrition data for the selected pet
            // This would integrate with the various services
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "scalemass"
        case 1: return "chart.line.uptrend.xyaxis"
        case 2: return "chart.bar.xaxis"
        case 3: return "brain.head.profile"
        default: return "questionmark"
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Weight"
        case 1: return "Trends"
        case 2: return "Compare"
        case 3: return "Analytics"
        default: return "Unknown"
        }
    }
}

// MARK: - Supporting Views

struct PetSelectionCard: View {
    let pet: Pet
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                AsyncImage(url: URL(string: pet.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(pet.species.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let weight = pet.weightKg {
                        Text("\(weight, specifier: "%.1f") kg")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Advanced Analytics View

struct AdvancedAnalyticsView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var analyticsService = AdvancedAnalyticsService.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var healthInsights: HealthInsights?
    @State private var nutritionalPatterns: NutritionalPatterns?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if isLoading {
                    ProgressView("Loading analytics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Health Insights Card
                    if let insights = healthInsights {
                        HealthInsightsCard(insights: insights)
                    }
                    
                    // Nutritional Patterns Card
                    if let patterns = nutritionalPatterns {
                        NutritionalPatternsCard(patterns: patterns)
                    }
                    
                    // Analytics Summary
                    analyticsSummarySection
                }
            }
            .padding()
        }
        .onAppear {
            loadAnalyticsData()
        }
    }
    
    private var analyticsSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics Summary")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                AnalyticsSummaryCard(
                    title: "Health Score",
                    value: "\(Int(healthInsights?.overallHealthScore ?? 0))",
                    unit: "/100",
                    color: .green
                )
                
                AnalyticsSummaryCard(
                    title: "Nutritional Balance",
                    value: "\(Int(healthInsights?.nutritionalAdequacyScore ?? 0))",
                    unit: "%",
                    color: .blue
                )
                
                AnalyticsSummaryCard(
                    title: "Feeding Consistency",
                    value: "\(Int(healthInsights?.feedingConsistencyScore ?? 0))",
                    unit: "%",
                    color: .orange
                )
                
                AnalyticsSummaryCard(
                    title: "Weight Management",
                    value: healthInsights?.weightManagementStatus.capitalized ?? "Unknown",
                    unit: "",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func loadAnalyticsData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // Load health insights and patterns
                // This would integrate with the analytics service
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
                
                // Mock data for now
                let mockInsights = HealthInsights(
                    petId: "mock-pet-id",
                    analysisDate: Date(),
                    weightManagementStatus: "stable",
                    nutritionalAdequacyScore: 85.0,
                    feedingConsistencyScore: 78.0,
                    healthRisks: ["Low fiber intake"],
                    positiveIndicators: ["Consistent feeding schedule", "Good weight stability"],
                    recommendations: [],
                    overallHealthScore: 82.0
                )
                
                let mockPatterns = NutritionalPatterns(
                    petId: "mock-pet-id",
                    analysisPeriod: "30_days",
                    feedingTimes: ["8:00 AM", "6:00 PM"],
                    preferredFoods: ["Chicken & Rice", "Salmon Formula"],
                    nutritionalGaps: ["Fiber intake could be improved"],
                    seasonalPatterns: [:],
                    behavioralInsights: ["Pet prefers morning feedings"],
                    optimizationSuggestions: ["Add more fiber-rich foods"]
                )
                
                await MainActor.run {
                    healthInsights = mockInsights
                    nutritionalPatterns = mockPatterns
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct HealthInsightsCard: View {
    let insights: HealthInsights
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Insights")
                .font(.headline)
            
            // Overall Health Score
            HStack {
                Text("Overall Health Score")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(insights.overallHealthScore))/100")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(healthScoreColor(insights.overallHealthScore))
            }
            
            // Health Risks
            if !insights.healthRisks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Health Risks")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    
                    ForEach(insights.healthRisks, id: \.self) { risk in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Text(risk)
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            // Positive Indicators
            if !insights.positiveIndicators.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Positive Indicators")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    ForEach(insights.positiveIndicators, id: \.self) { indicator in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(indicator)
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func healthScoreColor(_ score: Double) -> Color {
        if score >= 80 {
            return .green
        } else if score >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

struct NutritionalPatternsCard: View {
    let patterns: NutritionalPatterns
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutritional Patterns")
                .font(.headline)
            
            // Feeding Times
            if !patterns.feedingTimes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Feeding Times")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(patterns.feedingTimes, id: \.self) { time in
                            Text(time)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Preferred Foods
            if !patterns.preferredFoods.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferred Foods")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(patterns.preferredFoods, id: \.self) { food in
                            Text("• \(food)")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            
            // Optimization Suggestions
            if !patterns.optimizationSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Optimization Suggestions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(patterns.optimizationSuggestions, id: \.self) { suggestion in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct AnalyticsSummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "circle.fill")
                    .font(.caption)
                    .foregroundColor(color)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Data Models

struct HealthInsights {
    let petId: String
    let analysisDate: Date
    let weightManagementStatus: String
    let nutritionalAdequacyScore: Double
    let feedingConsistencyScore: Double
    let healthRisks: [String]
    let positiveIndicators: [String]
    let recommendations: [String]
    let overallHealthScore: Double
}

struct NutritionalPatterns {
    let petId: String
    let analysisPeriod: String
    let feedingTimes: [String]
    let preferredFoods: [String]
    let nutritionalGaps: [String]
    let seasonalPatterns: [String: Any]
    let behavioralInsights: [String]
    let optimizationSuggestions: [String]
}

// MARK: - Services

@MainActor
class AdvancedAnalyticsService: ObservableObject {
    static let shared = AdvancedAnalyticsService()
    
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {}
}

#Preview {
    Phase3NutritionView()
        .environmentObject(AuthService.shared)
}
