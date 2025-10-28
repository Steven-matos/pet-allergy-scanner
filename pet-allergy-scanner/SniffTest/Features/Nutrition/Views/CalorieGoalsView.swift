//
//  CalorieGoalsView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import SwiftUI

/**
 * Calorie Goals View
 * 
 * Interface for users to set and manage their pet's calorie goals.
 * Follows SOLID principles with single responsibility for goal management
 * Implements DRY by reusing common UI components
 * Follows KISS by keeping the interface simple and focused
 */
struct CalorieGoalsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var petService = CachedPetService.shared
    @StateObject private var petSelectionService = NutritionPetSelectionService.shared
    @StateObject private var calorieGoalsService = CalorieGoalsService.shared
    
    @State private var dailyCalorieGoal: String = ""
    @State private var isEditing = false
    @State private var isLoading = false
    @State private var showingSuccessAlert = false
    @State private var errorMessage: String?
    
    private var selectedPet: Pet? {
        petSelectionService.selectedPet
    }
    
    private var currentGoal: Double? {
        guard let pet = selectedPet else { return nil }
        return calorieGoalsService.getGoal(for: pet.id)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ModernLoadingView(message: "Saving goal...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    calorieGoalsContent
                }
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Calorie Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveGoal()
                        } else {
                            startEditing()
                        }
                    }
                    .disabled(isEditing && dailyCalorieGoal.isEmpty)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
        }
        .alert("Goal Saved", isPresented: $showingSuccessAlert) {
            Button("OK") {
                isEditing = false
            }
        } message: {
            Text("Your pet's daily calorie goal has been updated.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            loadCurrentGoal()
        }
    }
    
    // MARK: - Calorie Goals Content
    
    private var calorieGoalsContent: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Pet Selection Card
                if let pet = selectedPet {
                    PetSelectionCard(pet: pet)
                }
                
                // Current Goal Card
                currentGoalCard
                
                // Goal Input Card
                if isEditing {
                    goalInputCard
                }
                
                // Information Card
                informationCard
                
                // Quick Goal Suggestions
                if isEditing {
                    quickGoalSuggestions
                }
                
                Spacer(minLength: ModernDesignSystem.Spacing.xl)
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
    }
    
    // MARK: - Current Goal Card
    
    private var currentGoalCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title2)
                
                Text("Current Daily Goal")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                }
                
                if let goal = currentGoal {
                    HStack {
                        Text("\(Int(goal))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        Text("kcal/day")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Spacer()
                    }
                    
                    Text("Based on your pet's needs and veterinary recommendations")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                } else {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        Text("No goal set")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Text("Set a daily calorie goal to track your pet's nutritional progress")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Button("Set Goal") {
                            startEditing()
                        }
                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(ModernDesignSystem.Colors.buttonPrimary)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                        .padding(.top, ModernDesignSystem.Spacing.sm)
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
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
    }
    
    // MARK: - Goal Input Card
    
    private var goalInputCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "pencil")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title2)
                
                Text("Set Daily Goal")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                }
                
                HStack {
                    TextField("Enter calories", text: $dailyCalorieGoal)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 120)
                    
                    Text("kcal/day")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Spacer()
                }
                
                Text("💡 Tip: Consult with your veterinarian to determine the appropriate daily calorie intake for your pet")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .padding(.top, ModernDesignSystem.Spacing.sm)
            }
            .padding(ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.softCream)
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
    }
    
    // MARK: - Information Card
    
    private var informationCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title2)
                
                Text("About Calorie Goals")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    InfoRow(
                        icon: "stethoscope",
                        title: "Veterinary Guidance",
                        description: "Always consult your veterinarian when setting nutritional goals"
                    )
                    
                    InfoRow(
                        icon: "scalemass",
                        title: "Weight Monitoring",
                        description: "Track your pet's weight alongside calorie intake"
                    )
                    
                    InfoRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Trend Analysis",
                        description: "Monitor trends to adjust goals as needed"
                    )
                    
                    InfoRow(
                        icon: "pawprint.fill",
                        title: "Individual Needs",
                        description: "Each pet has unique nutritional requirements"
                    )
                }
            }
            .padding(ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.softCream)
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
    }
    
    // MARK: - Quick Goal Suggestions
    
    private var quickGoalSuggestions: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title2)
                
                Text("Quick Suggestions")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Spacer()
                }
                
                Text("Common daily calorie ranges (consult your vet for specific recommendations):")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: ModernDesignSystem.Spacing.sm) {
                    QuickGoalButton(
                        title: "Small Dogs",
                        range: "200-400",
                        description: "Under 20 lbs"
                    ) {
                        dailyCalorieGoal = "300"
                    }
                    
                    QuickGoalButton(
                        title: "Medium Dogs",
                        range: "400-800",
                        description: "20-50 lbs"
                    ) {
                        dailyCalorieGoal = "600"
                    }
                    
                    QuickGoalButton(
                        title: "Large Dogs",
                        range: "800-1200",
                        description: "50-80 lbs"
                    ) {
                        dailyCalorieGoal = "1000"
                    }
                    
                    QuickGoalButton(
                        title: "Cats",
                        range: "200-350",
                        description: "Adult cats"
                    ) {
                        dailyCalorieGoal = "275"
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
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
    }
    
    // MARK: - Helper Methods
    
    /**
     * Load current goal for selected pet
     */
    private func loadCurrentGoal() {
        guard let pet = selectedPet else { return }
        
        if let goal = calorieGoalsService.getGoal(for: pet.id) {
            dailyCalorieGoal = String(Int(goal))
        }
    }
    
    /**
     * Start editing mode
     */
    private func startEditing() {
        isEditing = true
        loadCurrentGoal()
    }
    
    /**
     * Save the calorie goal
     */
    private func saveGoal() {
        guard let pet = selectedPet,
              let goal = Double(dailyCalorieGoal),
              goal > 0 else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await calorieGoalsService.setGoal(for: pet.id, calories: goal)
                
                await MainActor.run {
                    isLoading = false
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save goal: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Supporting Views

/**
 * Info Row
 * Displays information with icon and text
 */
struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .font(.caption)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

/**
 * Quick Goal Button
 * Button for quick goal selection
 */
struct QuickGoalButton: View {
    let title: String
    let range: String
    let description: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(title)
                    .font(ModernDesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(range)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                
                Text(description)
                    .font(ModernDesignSystem.Typography.caption2)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(ModernDesignSystem.Spacing.sm)
            .background(ModernDesignSystem.Colors.softCream)
            .cornerRadius(ModernDesignSystem.CornerRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CalorieGoalsView()
        .environmentObject(AuthService.shared)
}
