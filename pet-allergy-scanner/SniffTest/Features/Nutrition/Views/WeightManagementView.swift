//
//  WeightManagementView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI
import Charts

/**
 * Weight Management View
 * 
 * Comprehensive weight tracking and management interface with support for:
 * - Weight recording and history
 * - Goal setting and tracking
 * - Trend analysis and visualization
 * - Progress monitoring and recommendations
 * 
 * Follows SOLID principles with single responsibility for weight management
 * Implements DRY by reusing common UI components
 * Follows KISS by keeping the interface intuitive and focused
 */
struct WeightManagementView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var weightService = WeightTrackingService.shared
    @StateObject private var petService = PetService.shared
    @State private var selectedPet: Pet?
    @State private var showingWeightEntry = false
    @State private var showingGoalSetting = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading weight data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let pet = selectedPet {
                    weightManagementContent(for: pet)
                } else {
                    petSelectionView
                }
            }
            .navigationTitle("Weight Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Weight") {
                        showingWeightEntry = true
                    }
                    .disabled(selectedPet == nil)
                }
            }
        }
        .sheet(isPresented: $showingWeightEntry) {
            if let pet = selectedPet {
                WeightEntryView(pet: pet)
            }
        }
        .sheet(isPresented: $showingGoalSetting) {
            if let pet = selectedPet {
                WeightGoalSettingView(pet: pet)
            }
        }
        .onAppear {
            loadWeightData()
        }
    }
    
    // MARK: - Pet Selection View
    
    private var petSelectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Select a Pet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose a pet to view weight management data")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !petService.pets.isEmpty {
                LazyVStack(spacing: 12) {
                    ForEach(petService.pets) { pet in
                        PetSelectionCard(pet: pet) {
                            selectedPet = pet
                            loadWeightData()
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
    
    // MARK: - Weight Management Content
    
    @ViewBuilder
    private func weightManagementContent(for pet: Pet) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Current Weight Card
                CurrentWeightCard(
                    pet: pet,
                    currentWeight: weightService.currentWeight(for: pet.id),
                    weightGoal: weightService.activeWeightGoal(for: pet.id)
                )
                
                // Weight Trend Chart
                if !weightService.weightHistory(for: pet.id).isEmpty {
                    WeightTrendChart(
                        weightHistory: weightService.weightHistory(for: pet.id),
                        petName: pet.name
                    )
                }
                
                // Goal Progress
                if let goal = weightService.activeWeightGoal(for: pet.id) {
                    GoalProgressCard(goal: goal, currentWeight: weightService.currentWeight(for: pet.id))
                }
                
                // Recent Weight Entries
                RecentWeightEntriesCard(
                    pet: pet,
                    weightHistory: weightService.weightHistory(for: pet.id)
                )
                
                // Recommendations
                if !weightService.recommendations(for: pet.id).isEmpty {
                    RecommendationsCard(recommendations: weightService.recommendations(for: pet.id))
                }
            }
            .padding()
        }
        .refreshable {
            await loadWeightDataAsync()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadWeightData() {
        guard let pet = selectedPet else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            await loadWeightDataAsync()
        }
    }
    
    private func loadWeightDataAsync() async {
        guard let pet = selectedPet else { return }
        
        do {
            try await weightService.loadWeightData(for: pet.id)
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
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
                        .foregroundColor(.orange)
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

struct CurrentWeightCard: View {
    let pet: Pet
    let currentWeight: Double?
    let weightGoal: WeightGoal?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Weight")
                    .font(.headline)
                
                Spacer()
                
                if let weight = currentWeight {
                    Text("\(weight, specifier: "%.1f") kg")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                } else {
                    Text("Not recorded")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let goal = weightGoal {
                HStack {
                    Text("Goal: \(goal.targetWeightKg ?? 0, specifier: "%.1f") kg")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let current = currentWeight, let target = goal.targetWeightKg {
                        let progress = (current / target) * 100
                        Text("\(progress, specifier: "%.0f")%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(progress >= 95 && progress <= 105 ? .green : .orange)
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

struct WeightTrendChart: View {
    let weightHistory: [WeightRecord]
    let petName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weight Trend")
                .font(.headline)
            
            if #available(iOS 16.0, *) {
                Chart(weightHistory.prefix(30)) { record in
                    LineMark(
                        x: .value("Date", record.recordedAt),
                        y: .value("Weight", record.weightKg)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Date", record.recordedAt),
                        y: .value("Weight", record.weightKg)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(50)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text("\(weight, specifier: "%.1f") kg")
                            }
                        }
                    }
                }
            } else {
                // Fallback for iOS 15 and earlier
                Text("Weight trend chart requires iOS 16+")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct GoalProgressCard: View {
    let goal: WeightGoal
    let currentWeight: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Goal Progress")
                    .font(.headline)
                
                Spacer()
                
                Text(goal.goalType.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let current = currentWeight, let target = goal.targetWeightKg {
                let progress = calculateProgress(current: current, target: target, goalType: goal.goalType)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progress")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(progress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: progressColor(progress)))
                }
            } else {
                Text("Set a target weight to track progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func calculateProgress(current: Double, target: Double, goalType: WeightGoalType) -> Double {
        switch goalType {
        case .weightLoss:
            // For weight loss, progress is how much weight has been lost
            return min(1.0, max(0.0, (target - current) / target))
        case .weightGain:
            // For weight gain, progress is how much weight has been gained
            return min(1.0, max(0.0, (current - target) / target))
        case .maintenance, .healthImprovement:
            // For maintenance, progress is how close to target
            return min(1.0, max(0.0, 1.0 - abs(current - target) / target))
        }
    }
    
    private func progressColor(_ progress: Double) -> Color {
        if progress >= 0.8 {
            return .green
        } else if progress >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

struct RecentWeightEntriesCard: View {
    let pet: Pet
    let weightHistory: [WeightRecord]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Entries")
                    .font(.headline)
                
                Spacer()
                
                if weightHistory.count > 5 {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            if weightHistory.isEmpty {
                Text("No weight entries yet. Tap 'Add Weight' to get started.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(weightHistory.prefix(5)) { record in
                        WeightEntryRow(record: record)
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

struct WeightEntryRow: View {
    let record: WeightRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(record.weightKg, specifier: "%.1f") kg")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(record.recordedAt, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct RecommendationsCard: View {
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
            
            LazyVStack(spacing: 8) {
                ForEach(recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                        
                        Text(recommendation)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
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

// MARK: - Weight Entry View

struct WeightEntryView: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weightService = WeightTrackingService.shared
    @State private var weight: String = ""
    @State private var notes: String = ""
    @State private var isRecording = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Weight Information") {
                    HStack {
                        TextField("Weight (kg)", text: $weight)
                            .keyboardType(.decimalPad)
                        
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Notes (Optional)") {
                    TextField("Add notes about this weight measurement", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Record Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        recordWeight()
                    }
                    .disabled(weight.isEmpty || isRecording)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func recordWeight() {
        guard let weightValue = Double(weight), weightValue > 0 else {
            errorMessage = "Please enter a valid weight"
            return
        }
        
        isRecording = true
        
        Task {
            do {
                try await weightService.recordWeight(
                    petId: pet.id,
                    weight: weightValue,
                    notes: notes.isEmpty ? nil : notes
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRecording = false
                }
            }
        }
    }
}

// MARK: - Weight Goal Setting View

struct WeightGoalSettingView: View {
    let pet: Pet
    @Environment(\.dismiss) private var dismiss
    @StateObject private var weightService = WeightTrackingService.shared
    @State private var goalType: WeightGoalType = .maintenance
    @State private var targetWeight: String = ""
    @State private var targetDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @State private var notes: String = ""
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Type") {
                    Picker("Goal Type", selection: $goalType) {
                        ForEach(WeightGoalType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Target Weight") {
                    HStack {
                        TextField("Target weight (kg)", text: $targetWeight)
                            .keyboardType(.decimalPad)
                        
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Target Date") {
                    DatePicker("When do you want to reach this goal?", selection: $targetDate, in: Date()..., displayedComponents: .date)
                }
                
                Section("Notes (Optional)") {
                    TextField("Add notes about this goal", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Set Weight Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createGoal()
                    }
                    .disabled(targetWeight.isEmpty || isCreating)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func createGoal() {
        guard let targetWeightValue = Double(targetWeight), targetWeightValue > 0 else {
            errorMessage = "Please enter a valid target weight"
            return
        }
        
        isCreating = true
        
        Task {
            do {
                try await weightService.createWeightGoal(
                    petId: pet.id,
                    goalType: goalType,
                    targetWeight: targetWeightValue,
                    targetDate: targetDate,
                    notes: notes.isEmpty ? nil : notes
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}

// MARK: - Extensions

extension WeightGoalType {
    var displayName: String {
        switch self {
        case .weightLoss:
            return "Weight Loss"
        case .weightGain:
            return "Weight Gain"
        case .maintenance:
            return "Maintenance"
        case .healthImprovement:
            return "Health Improvement"
        }
    }
}

#Preview {
    WeightManagementView()
        .environmentObject(AuthService.shared)
}
