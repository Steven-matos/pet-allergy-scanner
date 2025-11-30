//
//  FeedingLogView.swift
//  SniffTest
//
//  Created by Steven Matos on 1/15/25.
//

import SwiftUI

/**
 * Feeding Log View
 * 
 * Simple interface for users to log pet feeding data with minimal friction.
 * Follows SOLID principles with single responsibility for feeding input
 * Implements DRY by reusing common UI components
 * Follows KISS by keeping the interface intuitive and focused
 */
struct FeedingLogView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var feedingService = FeedingLogService.shared
    @State private var petService = CachedPetService.shared
    @StateObject private var petSelectionService = NutritionPetSelectionService.shared
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    
    @State private var selectedFood: FoodItem?
    @State private var feedingAmount: String = ""
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var notes: String = ""
    @State private var showingFoodSelection = false
    @State private var showingAmountInput = false
    @State private var isLoading = false
    @State private var showingSuccessAlert = false
    @State private var errorMessage: String?
    
    private var selectedPet: Pet? {
        petSelectionService.selectedPet
    }
    
    private var isFormValid: Bool {
        selectedFood != nil && !feedingAmount.isEmpty && Double(feedingAmount) ?? 0 > 0
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ModernLoadingView(message: "Saving feeding log...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    feedingLogContent
                }
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Log Feeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.red.opacity(0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFeedingLog()
                    }
                    .disabled(!isFormValid)
                    .foregroundColor(isFormValid ? 
                                   ModernDesignSystem.Colors.primary : 
                                   ModernDesignSystem.Colors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showingFoodSelection) {
            FoodSelectionView(selectedFood: $selectedFood)
        }
        .alert("Feeding Logged", isPresented: $showingSuccessAlert) {
            Button("OK") {
                // Reset form or navigate back
                resetForm()
            }
        } message: {
            Text("Your pet's feeding has been logged successfully.")
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
    }
    
    // MARK: - Feeding Log Content
    
    private var feedingLogContent: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Pet Selection Card
                if let pet = selectedPet {
                    PetSelectionCard(pet: pet)
                }
                
                // Food Selection Card
                FoodSelectionCard(
                    selectedFood: selectedFood,
                    onTap: { showingFoodSelection = true }
                )
                
                // Amount Input Card
                AmountInputCard(
                    amount: $feedingAmount,
                    food: selectedFood,
                    onTap: { showingAmountInput = true }
                )
                
                // Date & Time Selection
                DateTimeSelectionCard(
                    selectedDate: $selectedDate,
                    selectedTime: $selectedTime
                )
                
                // Notes Section (Optional)
                NotesInputCard(notes: $notes)
                
                // Estimated Calories Display
                if let food = selectedFood, let amount = Double(feedingAmount), amount > 0 {
                    EstimatedCaloriesCard(
                        food: food,
                        amount: amount
                    )
                }
                
                Spacer(minLength: ModernDesignSystem.Spacing.xl)
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
    }
    
    // MARK: - Helper Methods
    
    /**
     * Save the feeding log entry
     */
    private func saveFeedingLog() {
        guard let pet = selectedPet,
              let food = selectedFood,
              let amount = Double(feedingAmount),
              amount > 0 else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let feedingDateTime = Calendar.current.date(
                    bySettingHour: Calendar.current.component(.hour, from: selectedTime),
                    minute: Calendar.current.component(.minute, from: selectedTime),
                    second: Calendar.current.component(.second, from: selectedTime),
                    of: selectedDate
                ) ?? selectedDate
                
                // Convert cups to grams (1 cup ≈ 120 grams for dry pet food)
                // This is an approximation - actual weight varies by food density
                let amountInGrams = amount * 120.0
                
                let feedingRecord = FeedingRecordRequest(
                    petId: pet.id,
                    foodAnalysisId: food.id,
                    amountGrams: amountInGrams,
                    feedingTime: feedingDateTime,
                    notes: notes.isEmpty ? nil : notes
                )
                
                try await feedingService.logFeeding(feedingRecord)
                
                await MainActor.run {
                    isLoading = false
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to save feeding log: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /**
     * Reset the form after successful save
     */
    private func resetForm() {
        selectedFood = nil
        feedingAmount = ""
        notes = ""
        selectedDate = Date()
        selectedTime = Date()
    }
}

// MARK: - Supporting Views


/**
 * Food Selection Card
 * Allows user to select or scan food items
 */
struct FoodSelectionCard: View {
    let selectedFood: FoodItem?
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: selectedFood == nil ? "plus.circle" : "checkmark.circle.fill")
                    .foregroundColor(selectedFood == nil ? 
                                   ModernDesignSystem.Colors.primary : 
                                   ModernDesignSystem.Colors.primary)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(selectedFood?.name ?? "Select Food")
                        .font(ModernDesignSystem.Typography.title3)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    if let food = selectedFood {
                        Text("\(food.brand ?? "Unknown Brand")")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    } else {
                        Text("Tap to scan or select food")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .font(.caption)
            }
            .padding(ModernDesignSystem.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
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

/**
 * Amount Input Card
 * Simple amount input with common presets
 */
struct AmountInputCard: View {
    @Binding var amount: String
    let food: FoodItem?
    let onTap: () -> Void
    
    private let commonAmounts = ["0.25", "0.5", "0.75", "1.0", "1.25", "1.5", "2.0"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "scalemass")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title2)
                
                Text("Amount")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            // Custom amount input
            HStack {
                TextField("Enter amount", text: $amount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 120)
                
                Text("cups")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                Spacer()
            }
            
            // Quick amount buttons
            if food != nil {
                Text("Quick amounts:")
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: ModernDesignSystem.Spacing.sm) {
                    ForEach(commonAmounts, id: \.self) { quickAmount in
                        Button(quickAmount) {
                            amount = quickAmount
                        }
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(amount == quickAmount ? 
                                       ModernDesignSystem.Colors.textOnPrimary : 
                                       ModernDesignSystem.Colors.textPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.sm)
                        .padding(.vertical, ModernDesignSystem.Spacing.xs)
                        .background(amount == quickAmount ? 
                                  ModernDesignSystem.Colors.primary : 
                                  ModernDesignSystem.Colors.softCream)
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                    }
                }
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
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

/**
 * Date & Time Selection Card
 * Simple date and time picker
 */
struct DateTimeSelectionCard: View {
    @Binding var selectedDate: Date
    @Binding var selectedTime: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title2)
                
                Text("When")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            HStack(spacing: ModernDesignSystem.Spacing.lg) {
                VStack(alignment: .leading) {
                    Text("Date")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }
                
                VStack(alignment: .leading) {
                    Text("Time")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(CompactDatePickerStyle())
                }
                
                Spacer()
            }
        }
        .padding(ModernDesignSystem.Spacing.md)
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

/**
 * Notes Input Card
 * Optional notes field
 */
struct NotesInputCard: View {
    @Binding var notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(.title2)
                
                Text("Notes (Optional)")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            TextField("Any additional notes...", text: $notes, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
        .padding(ModernDesignSystem.Spacing.md)
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

/**
 * Estimated Calories Card
 * Shows calculated calories for the feeding
 */
struct EstimatedCaloriesCard: View {
    let food: FoodItem
    let amount: Double
    
    private var estimatedCalories: Double {
        guard let caloriesPer100g = food.nutritionalInfo?.caloriesPer100g else { return 0 }
        return (caloriesPer100g / 100.0) * amount
    }
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: "flame.fill")
                .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text("Estimated Calories")
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("\(estimatedCalories, specifier: "%.1f") kcal")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
            }
            
            Spacer()
            
            Image(systemName: "info.circle")
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .font(.caption)
        }
        .padding(ModernDesignSystem.Spacing.md)
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
    FeedingLogView()
        .environmentObject(AuthService.shared)
}
