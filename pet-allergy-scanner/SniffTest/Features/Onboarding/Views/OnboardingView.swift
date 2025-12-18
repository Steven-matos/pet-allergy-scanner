//
//  OnboardingView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/2025.
//

import SwiftUI

/// Onboarding view for new users to set up their first pet
struct OnboardingView: View {
    @State private var petService = CachedPetService.shared
    @StateObject private var authService = AuthService.shared
    
    /// Callback when user skips onboarding
    let onSkip: () -> Void
    
    @State private var currentStep = 0
    @State private var name = ""
    @State private var species = PetSpecies.dog
    @State private var breed = ""
    @State private var birthYear: Int?
    @State private var birthMonth: Int?
    @State private var weightKg: Double?
    @State private var activityLevel: PetActivityLevel = .moderate
    @State private var knownSensitivities: [String] = []
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var newSensitivity = ""
    @State private var showingAlert = false
    @State private var validationErrors: [String] = []
    @State private var isCreatingPet = false
    @State private var showNameValidationError = false
    @State private var petImage: UIImage?
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isBreedFieldFocused: Bool
    @FocusState private var isWeightFieldFocused: Bool
    @StateObject private var unitService = WeightUnitPreferenceService.shared
    @StateObject private var subscriptionViewModel = SubscriptionViewModel()
    
    // MEMORY OPTIMIZATION: Track all tasks to cancel on view disappear
    @State private var animationTasks: [Task<Void, Never>] = []
    @State private var validationTasks: [Task<Void, Never>] = []
    @State private var dispatchWorkItems: [DispatchWorkItem] = []
    
    // Track if profile setup was shown initially (for back button logic)
    // This allows users to go back to profile setup even after it's completed
    @State private var profileSetupWasShown = false
    
    // Profile setup state (for Apple Sign-In users without name)
    @State private var userFirstName = ""
    @State private var userLastName = ""
    @State private var userUsername = ""
    @State private var isSavingProfile = false
    @State private var showProfileNameError = false
    
    // Animation state for validation feedback
    @State private var nameFieldShimmy = false
    @State private var profileNameFieldShimmy = false
    
    // Feature tour state
    @State private var showFeatureTour = false
    @State private var featureTourIndex = 0
    
    /// Check if user needs profile setup (missing first name from Apple Sign-In)
    private var needsProfileSetup: Bool {
        guard let user = authService.currentUser else { return false }
        return user.firstName == nil || user.firstName?.isEmpty == true
    }
    
    // Computed property to check if user should skip paywall
    // App is fully free - always skip paywall
    private var shouldSkipPaywall: Bool {
        return true // App is fully free - always skip paywall
        // if Configuration.subscriptionBypassEnabled {
        //     return true
        // }
        // guard let user = authService.currentUser else { return false }
        // return user.role == .premium || user.bypassSubscription
    }
    
    /// Total steps dynamically calculated based on whether profile setup is needed and if paywall should be shown
    /// Feature tour (5 screens) + profile setup (0-1) + pet info (3) + paywall/completion (1) = 9-10 steps
    /// Uses profileSetupWasShown to keep step count consistent even after profile is saved
    private var totalSteps: Int {
        let featureTourSteps = 5 // Feature tour screens
        let profileSetupSteps = profileSetupWasShown ? 1 : 0
        let petInfoSteps = 3 // Basic info, physical info, allergies & vet
        let finalStep = 1 // Paywall or completion
        
        return featureTourSteps + profileSetupSteps + petInfoSteps + finalStep
    }
    
    /// Step offset to account for optional profile setup step
    /// Feature tour is always 5 steps, so offset starts at 5
    /// Uses profileSetupWasShown to keep step structure consistent even after profile is saved
    private var stepOffset: Int {
        let featureTourSteps = 5
        // If profile setup was shown initially, keep it in the step structure
        // This allows users to navigate back to it even after completion
        return featureTourSteps + (profileSetupWasShown ? 1 : 0)
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Progress indicator
                        // MEMORY OPTIMIZATION: Clamp progress value to valid range to prevent out-of-bounds warning
                        ProgressView(
                            value: Double(min(max(currentStep + 1, 0), max(totalSteps, 1))),
                            total: Double(max(totalSteps, 1))
                        )
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(ModernDesignSystem.Colors.primary)
                            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                            .padding(.top, ModernDesignSystem.Spacing.sm)
                            .onAppear {
                                // Track onboarding started
                                PostHogAnalytics.trackOnboardingStarted()
                                
                                // Track if profile setup was shown initially
                                // This allows users to go back to it even after completion
                                profileSetupWasShown = needsProfileSetup
                            }
                        
                        // Step content
                        TabView(selection: $currentStep) {
                            // Step 1: Feature Tour Screen 1 - Ingredient Scanning
                            featureTourScreen1
                                .tag(0)
                            
                            // Step 2: Feature Tour Screen 2 - Health Tracking
                            featureTourScreen2
                                .tag(1)
                            
                            // Step 3: Feature Tour Screen 3 - Vet Visit Ready
                            featureTourScreen3
                                .tag(2)
                            
                            // Step 4: Feature Tour Screen 4 - Safety Explanations
                            featureTourScreen4
                                .tag(3)
                            
                            // Step 5: Feature Tour Screen 5 - Timeline Clarity
                            featureTourScreen5
                                .tag(4)
                            
                            // Step 6: Profile Setup (show if needed OR if it was shown initially)
                            // This allows users to go back to profile setup even after completing it
                            if needsProfileSetup || profileSetupWasShown {
                                profileSetupStep
                                    .tag(5)
                            }
                            
                            // Step 6/7: Basic Pet Info
                            basicInfoStep
                                .tag(5 + stepOffset)
                            
                            // Step 7/8: Physical Info
                            physicalInfoStep
                                .tag(6 + stepOffset)
                            
                            // Step 8/9: Allergies & Vet Info
                            allergiesAndVetStep
                                .tag(7 + stepOffset)
                            
                            // Step 9/10: Premium Subscription (skip if app is free or user is premium)
                            if shouldSkipPaywall {
                                // Show a completion step instead of paywall for premium users or free app
                                completionStep
                                    .tag(8 + stepOffset)
                            } else {
                                paywallStep
                                    .tag(8 + stepOffset)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut, value: currentStep)
                        .frame(height: UIScreen.main.bounds.height * 0.7) // Fixed height for TabView
                        // iOS 18.6.2 Fix: Don't use .disabled on TabView - it blocks ALL interactions including TextFields
                        // Swipe prevention is handled by onChange validation logic above
                        .onChange(of: currentStep) { oldValue, newValue in
                            // Track onboarding step viewed
                            let stepName: String
                            switch newValue {
                            case 0...4:
                                // Feature tour screens
                                let featureNames = ["feature_scan", "feature_tracking", "feature_vet", "feature_safety", "feature_timeline"]
                                stepName = featureNames[newValue]
                            case 5 where needsProfileSetup:
                                stepName = "profile_setup"
                            case 5 where !needsProfileSetup, 6 where needsProfileSetup:
                                stepName = "add_pet"
                            case 6 where !needsProfileSetup, 7 where needsProfileSetup:
                                stepName = "pet_details"
                            case 7 where !needsProfileSetup, 8 where needsProfileSetup:
                                stepName = "allergies_vet"
                            case 8 where !needsProfileSetup, 9 where needsProfileSetup:
                                stepName = shouldSkipPaywall ? "completion" : "paywall"
                            default:
                                stepName = "unknown"
                            }
                            PostHogAnalytics.trackOnboardingStepViewed(step: stepName)
                            // Prevent swiping forward if validation fails
                            if newValue > oldValue {
                                // User is trying to move forward
                                if !canProceedFromStep(oldValue) {
                                    // Haptic feedback for validation error
                                    HapticFeedback.error()
                                    
                                    // Show validation error and reset
                                    withAnimation {
                                        // Profile setup step validation
                                        if needsProfileSetup && oldValue == 5 {
                                            showProfileNameError = true
                                            profileNameFieldShimmy = true
                                        }
                                        // Pet name validation
                                        else if oldValue == (5 + stepOffset) {
                                            showNameValidationError = true
                                            isNameFieldFocused = true
                                            nameFieldShimmy = true
                                        }
                                        currentStep = oldValue
                                    }
                                    
                                    // Trigger shimmy animation sequence
                                    // MEMORY OPTIMIZATION: Store task for cancellation
                                    let animationTask = Task { @MainActor in
                                        guard !Task.isCancelled else { return }
                                        if needsProfileSetup && oldValue == 5 {
                                            // First shake right
                                            profileNameFieldShimmy = true
                                            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                            guard !Task.isCancelled else { return }
                                            // Then shake left
                                            profileNameFieldShimmy = false
                                            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                            guard !Task.isCancelled else { return }
                                            // Shake right again
                                            profileNameFieldShimmy = true
                                            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                            guard !Task.isCancelled else { return }
                                            // Return to center
                                            profileNameFieldShimmy = false
                                        } else if oldValue == (5 + stepOffset) {
                                            // First shake right
                                            nameFieldShimmy = true
                                            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                            guard !Task.isCancelled else { return }
                                            // Then shake left
                                            nameFieldShimmy = false
                                            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                            guard !Task.isCancelled else { return }
                                            // Shake right again
                                            nameFieldShimmy = true
                                            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                            guard !Task.isCancelled else { return }
                                            // Return to center
                                            nameFieldShimmy = false
                                        }
                                    }
                                    animationTasks.append(animationTask)
                                    
                                    // Auto-hide validation error after 2 seconds
                                    // MEMORY OPTIMIZATION: Store work item for cancellation
                                    // Note: OnboardingView is a struct, so no weak reference needed
                                    let workItem = DispatchWorkItem {
                                        withAnimation {
                                            showNameValidationError = false
                                            showProfileNameError = false
                                        }
                                    }
                                    dispatchWorkItems.append(workItem)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
                                } else {
                                    // Validation passed, hide any errors
                                    showNameValidationError = false
                                    showProfileNameError = false
                                    nameFieldShimmy = false
                                    profileNameFieldShimmy = false
                                    
                                    // Save profile when moving from profile setup step
                                    if needsProfileSetup && oldValue == 5 {
                                        // MEMORY OPTIMIZATION: Store task for cancellation
                                        // Note: OnboardingView is a struct, so no weak reference needed
                                        let profileTask = Task { @MainActor in
                                            guard !Task.isCancelled else { return }
                                            await saveUserProfile()
                                        }
                                        validationTasks.append(profileTask)
                                    }
                                }
                            }
                        }
                    }
            }
            .scrollDismissesKeyboard(.interactively)
            // iOS 18.6.2 Fix: Removed .dismissKeyboardOnTap() - conflicts with TabView page style
            // .scrollDismissesKeyboard(.interactively) already handles keyboard dismissal
                .onChange(of: isNameFieldFocused) { _, isFocused in
                    if isFocused {
                        // Scroll to the name field when it gets focus
                        // MEMORY OPTIMIZATION: Store work item for cancellation
                        // Note: ScrollViewProxy is a struct, so no weak reference needed
                        let workItem = DispatchWorkItem {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("nameField", anchor: UnitPoint.center)
                            }
                        }
                        dispatchWorkItems.append(workItem)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
                    }
                }
                .onChange(of: isBreedFieldFocused) { _, isFocused in
                    if isFocused {
                        // Scroll to the breed field when it gets focus
                        // MEMORY OPTIMIZATION: Store work item for cancellation
                        // Note: ScrollViewProxy is a struct, so no weak reference needed
                        let workItem = DispatchWorkItem {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("breedField", anchor: UnitPoint.center)
                            }
                        }
                        dispatchWorkItems.append(workItem)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
                    }
                }
                .onChange(of: isWeightFieldFocused) { _, isFocused in
                    if isFocused {
                        // Scroll to the weight field when it gets focus
                        // MEMORY OPTIMIZATION: Store work item for cancellation
                        // Note: ScrollViewProxy is a struct, so no weak reference needed
                        let workItem = DispatchWorkItem {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("weightField", anchor: UnitPoint.center)
                            }
                        }
                        dispatchWorkItems.append(workItem)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
                    }
                }
                .onDisappear {
                    // MEMORY OPTIMIZATION: Cancel all tasks and work items to prevent memory leaks
                    animationTasks.forEach { $0.cancel() }
                    animationTasks.removeAll()
                    validationTasks.forEach { $0.cancel() }
                    validationTasks.removeAll()
                    dispatchWorkItems.forEach { $0.cancel() }
                    dispatchWorkItems.removeAll()
                    
                    // Clear pet image from memory when view disappears
                    petImage = nil
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Navigation buttons using modern SwiftUI bottom placement
                HStack(spacing: ModernDesignSystem.Spacing.md) {
                    // Back button - 1/3 width (only show if not on first step)
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                currentStep = getPreviousStep(from: currentStep)
                            }
                        }
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .stroke(ModernDesignSystem.Colors.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Skip button (only show on paywall step) - 1/3 width
                    if currentStep == (8 + stepOffset) && !shouldSkipPaywall {
                        // Skip paywall button (only show if not premium user and app is not free)
                        // iOS 18 compatible: Button action properly isolated
                        Button("Skip for now") {
                            // MEMORY OPTIMIZATION: Store task for cancellation
                            let skipTask = Task { @MainActor in
                                guard !Task.isCancelled else { return }
                                createPet(shouldDismissOnboarding: true)
                            }
                            validationTasks.append(skipTask)
                        }
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                                .stroke(ModernDesignSystem.Colors.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                        .disabled(isCreatingPet)
                    }
                    
                    // Next/Complete/Subscribe button - 2/3 width
                    // iOS 18 compatible: Button action properly isolated to MainActor
                    Button(action: {
                        // MEMORY OPTIMIZATION: Store task for cancellation
                        // Note: OnboardingView is a struct, so no weak reference needed
                        let buttonTask = Task { @MainActor in
                            guard !Task.isCancelled else { return }
                            // Check if we're on the final step (paywall or completion)
                            // The final step tag is (8 + stepOffset)
                            let isFinalStep = currentStep == (8 + stepOffset) || currentStep == totalSteps - 1
                            if isFinalStep {
                                // On paywall step (or completion step for premium users)
                                if shouldSkipPaywall {
                                    // Premium user - just create pet and complete onboarding
                                    // iOS 18.6.2 Fix: Must dismiss onboarding after pet creation
                                    createPet(shouldDismissOnboarding: true)
                                } else {
                                    // Regular user - try to subscribe then create pet
                                    handlePaywallAction()
                                }
                            } else {
                                // Validate before moving forward
                                if canProceed {
                                    // Haptic feedback for successful navigation
                                    HapticFeedback.selection()
                                    
                                    // Save profile when moving from profile setup step
                                    if needsProfileSetup && currentStep == 5 {
                                        await saveUserProfile()
                                        // Note: profileSetupWasShown is already set in onAppear
                                        // This ensures the profile setup step remains in the TabView
                                        // so users can go back to it if needed
                                        // After saving profile, needsProfileSetup becomes false
                                        // This changes the TabView structure (removes profile setup step)
                                        // We need to navigate to basic pet info step (tag = 5 + stepOffset)
                                        // After saving, stepOffset = 5, so tag = 10
                                        // Wait for SwiftUI to update the view structure first
                                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                                        await MainActor.run {
                                            // Now stepOffset should be 5 (needsProfileSetup is false)
                                            // Basic pet info tag is 5 + stepOffset = 5 + 5 = 10
                                            withAnimation {
                                                currentStep = 5 + stepOffset
                                                showNameValidationError = false
                                                showProfileNameError = false
                                                nameFieldShimmy = false
                                                profileNameFieldShimmy = false
                                            }
                                        }
                                    } else {
                                        withAnimation {
                                            currentStep += 1
                                            showNameValidationError = false
                                            showProfileNameError = false
                                            nameFieldShimmy = false
                                            profileNameFieldShimmy = false
                                        }
                                    }
                                } else if needsProfileSetup && currentStep == 5 {
                                    // Show validation error for profile first name
                                    HapticFeedback.error()
                                    withAnimation {
                                        showProfileNameError = true
                                        profileNameFieldShimmy = true
                                    }
                                    
                                    // Trigger shimmy animation sequence
                                    // MEMORY OPTIMIZATION: Store task for cancellation
                                    let animationTask = Task { @MainActor in
                                        guard !Task.isCancelled else { return }
                                        // First shake right
                                        profileNameFieldShimmy = true
                                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                        guard !Task.isCancelled else { return }
                                        // Then shake left
                                        profileNameFieldShimmy = false
                                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                        guard !Task.isCancelled else { return }
                                        // Shake right again
                                        profileNameFieldShimmy = true
                                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                        guard !Task.isCancelled else { return }
                                        // Return to center
                                        profileNameFieldShimmy = false
                                    }
                                    animationTasks.append(animationTask)
                                    
                                    // Auto-hide after 2 seconds
                                    // MEMORY OPTIMIZATION: Store task for cancellation
                                    let hideTask = Task { @MainActor in
                                        guard !Task.isCancelled else { return }
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        guard !Task.isCancelled else { return }
                                        withAnimation {
                                            showProfileNameError = false
                                        }
                                    }
                                    animationTasks.append(hideTask)
                                } else if currentStep == (5 + stepOffset) {
                                    // Show validation error for pet name
                                    HapticFeedback.error()
                                    withAnimation {
                                        showNameValidationError = true
                                        isNameFieldFocused = true
                                        nameFieldShimmy = true
                                    }
                                    
                                    // Trigger shimmy animation sequence
                                    // MEMORY OPTIMIZATION: Store task for cancellation
                                    let animationTask = Task { @MainActor in
                                        guard !Task.isCancelled else { return }
                                        // First shake right
                                        nameFieldShimmy = true
                                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                        guard !Task.isCancelled else { return }
                                        // Then shake left
                                        nameFieldShimmy = false
                                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                        guard !Task.isCancelled else { return }
                                        // Shake right again
                                        nameFieldShimmy = true
                                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                                        guard !Task.isCancelled else { return }
                                        // Return to center
                                        nameFieldShimmy = false
                                    }
                                    animationTasks.append(animationTask)
                                    
                                    // Auto-hide after 2 seconds
                                    // MEMORY OPTIMIZATION: Store task for cancellation
                                    let hideTask = Task { @MainActor in
                                        guard !Task.isCancelled else { return }
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        guard !Task.isCancelled else { return }
                                        withAnimation {
                                            showNameValidationError = false
                                        }
                                    }
                                    animationTasks.append(hideTask)
                                }
                            }
                        }
                        validationTasks.append(buttonTask)
                    }) {
                        ZStack {
                            Text(buttonText)
                                .opacity(isCreatingPet || isSavingProfile ? 0 : 1)
                            
                            if isCreatingPet {
                                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(ModernDesignSystem.Colors.textOnPrimary)
                                    Text("Creating...")
                                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                                }
                            } else if isSavingProfile {
                                HStack(spacing: ModernDesignSystem.Spacing.sm) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(ModernDesignSystem.Colors.textOnPrimary)
                                    Text("Saving...")
                                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                                        .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                                }
                            }
                        }
                    }
                    .font(ModernDesignSystem.Typography.bodyEmphasized)
                    .foregroundColor(ModernDesignSystem.Colors.textOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                            .fill(ModernDesignSystem.Colors.primary)
                    )
                    .disabled((!canProceed && currentStep != (4 + stepOffset)) || isCreatingPet || isSavingProfile)
                    .opacity(((!canProceed && currentStep != (4 + stepOffset)) || isCreatingPet || isSavingProfile) ? 0.5 : 1.0)
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                .padding(.vertical, ModernDesignSystem.Spacing.md)
                .background(
                    ModernDesignSystem.Colors.softCream
                        .shadow(
                            color: ModernDesignSystem.Shadows.medium.color,
                            radius: ModernDesignSystem.Shadows.medium.radius,
                            x: ModernDesignSystem.Shadows.medium.x,
                            y: ModernDesignSystem.Shadows.medium.y
                        )
                )
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(petService.errorMessage ?? "An error occurred")
            }
            .onChange(of: petService.errorMessage) { _, errorMessage in
                if errorMessage != nil {
                    showingAlert = true
                }
            }
        }
    }
    
    // MARK: - Step Views
    
    /// Feature Tour Screen 1: Ingredient Scanning
    private var featureTourScreen1: some View {
        FeatureScreenView(
            icon: "camera.viewfinder",
            title: "Scan Any Pet Food",
            description: "Point your camera at ingredients lists. We'll instantly identify what's safe and what's not for your pet.",
            highlights: [
                "Barcode and OCR scanning",
                "Instant ingredient analysis",
                "Database of 10,000+ ingredients"
            ]
        )
    }
    
    /// Feature Tour Screen 2: Health Tracking
    private var featureTourScreen2: some View {
        FeatureScreenView(
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Health Over Time",
            description: "Log feedings, weight, and health events. Build a complete picture of your pet's wellness journey.",
            highlights: [
                "Daily feeding logs",
                "Weight trends & goals",
                "Health event timeline"
            ]
        )
    }
    
    /// Feature Tour Screen 3: Vet Visit Ready
    private var featureTourScreen3: some View {
        FeatureScreenView(
            icon: "stethoscope",
            title: "Vet Visit Ready",
            description: "Generate one-tap summaries with food history, weight trends, and medications. Give your vet clarity, not confusion.",
            highlights: [
                "30/60/90 day summaries",
                "Food change history",
                "Medication tracking"
            ]
        )
    }
    
    /// Feature Tour Screen 4: Safety Explanations
    private var featureTourScreen4: some View {
        FeatureScreenView(
            icon: "exclamationmark.shield",
            title: "Clear Safety Explanations",
            description: "Every flagged ingredient explains WHY it's flagged, for WHICH species, and at WHAT confidence level.",
            highlights: [
                "Calm, not alarming",
                "Species-specific info",
                "Actionable guidance"
            ]
        )
    }
    
    /// Feature Tour Screen 5: Timeline Clarity
    private var featureTourScreen5: some View {
        FeatureScreenView(
            icon: "clock.arrow.circlepath",
            title: "Your Pet's Timeline",
            description: "Owners forget timelines. Vets distrust memory. SniffTest remembers everything so you don't have to.",
            highlights: [
                "Complete food history",
                "Health event records",
                "Never lose data"
            ]
        )
    }
    
    /// Profile setup step for collecting user's name (shown when Apple Sign-In didn't provide it)
    private var profileSetupStep: some View {
        ProfileSetupView(
            firstName: $userFirstName,
            lastName: $userLastName,
            username: $userUsername,
            showFirstNameError: $showProfileNameError,
            firstNameShimmy: $profileNameFieldShimmy
        )
        .onChange(of: userFirstName) { _, _ in
            showProfileNameError = false
            profileNameFieldShimmy = false
        }
        .overlay {
            if isSavingProfile {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: ModernDesignSystem.Spacing.md) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                            Text("Saving profile...")
                                .font(ModernDesignSystem.Typography.body)
                                .foregroundColor(.white)
                        }
                        .padding(ModernDesignSystem.Spacing.xl)
                        .background(ModernDesignSystem.Colors.primary.opacity(0.9))
                        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                    }
            }
        }
    }
    
    private var basicInfoStep: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Text("Tell us about your pet")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("We'll use this information to provide personalized safety recommendations.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, ModernDesignSystem.Spacing.xxl)
            
            VStack(spacing: ModernDesignSystem.Spacing.lg) {

                // Pet Photo (optional)
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Pet Photo (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack {
                        Spacer()
                        PetImagePickerView(
                            selectedImage: $petImage,
                            species: species
                        )
                        Spacer()
                    }
                    .onChange(of: petImage) { oldValue, newValue in
                        // MEMORY OPTIMIZATION: Immediately optimize image when selected to reduce memory usage
                        if let newImage = newValue {
                            // Optimize image to max 2MB to prevent memory issues
                            let optimizedImage = newImage.optimizeForMemory(maxMemoryUsage: 2_097_152)
                            if optimizedImage !== newImage {
                                // Only update if optimization changed the image
                                petImage = optimizedImage
                            }
                        }
                    }
                }

                // Pet name
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Pet Name *")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Enter your pet's name", text: $name)
                        .focused($isNameFieldFocused)
                        .modernInputField()
                        .background(
                            showNameValidationError ? 
                                Color.red.opacity(0.1) : // Light red background for validation error
                                Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                                .stroke(
                                    showNameValidationError ? 
                                        Color.red : // Red border for validation error
                                        Color.clear, 
                                    lineWidth: showNameValidationError ? 2 : 0
                                )
                        )
                        .offset(x: nameFieldShimmy ? 10 : -10)
                        .animation(.spring(response: 0.08, dampingFraction: 0.4), value: nameFieldShimmy)
                        .onAppear {
                            nameFieldShimmy = false
                        }
                        .animation(.easeInOut(duration: 0.3), value: showNameValidationError)
                        .onChange(of: name) { _, _ in
                            validateForm()
                            showNameValidationError = false
                            nameFieldShimmy = false
                        }
                        .id("nameField")
                    
                    if showNameValidationError {
                        HStack(spacing: ModernDesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Pet name is required and must be at least 2 characters")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(.red)
                        }
                    } else if validationErrors.contains(where: { $0.contains("name") }) {
                        Text(validationErrors.first(where: { $0.contains("name") }) ?? "")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                }
                
                // Species
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Species *")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Picker("Species", selection: $species) {
                        Text("Dog").tag(PetSpecies.dog)
                        Text("Cat").tag(PetSpecies.cat)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: species) { _, _ in
                        validateForm()
                    }
                }
                
                // Breed (optional)
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Breed (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("e.g., Golden Retriever", text: $breed)
                        .focused($isBreedFieldFocused)
                        .modernInputField()
                        .id("breedField")
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            Spacer()
        }
    }
    
    private var physicalInfoStep: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Text("Physical Information")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)

                Image("Illustrations/running")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 250, maxHeight: 250)
                
                Text("Help us track your pet's health and activity for personalized nutrition recommendations.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, ModernDesignSystem.Spacing.xxl)
            
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Birthday
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Birthday (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack(spacing: ModernDesignSystem.Spacing.md) {
                        Picker("Year", selection: $birthYear) {
                            Text("Year").tag(nil as Int?)
                            ForEach(availableYears, id: \.self) { year in
                                Text(String(format: "%d", year)).tag(year as Int?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        
                        Picker("Month", selection: $birthMonth) {
                            Text("Month").tag(nil as Int?)
                            ForEach(availableMonths, id: \.0) { month, name in
                                Text("\(name) - \(String(format: "%02d", month))").tag(month as Int?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: birthYear) { _, _ in validateForm() }
                    .onChange(of: birthMonth) { _, _ in validateForm() }
                    
                    if let birthYear = birthYear, let birthMonth = birthMonth {
                        if let birthday = createBirthday(year: birthYear, month: birthMonth) {
                            let age = calculateAge(from: birthday)
                            Text("Age: \(age)")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                    }
                    
                    if validationErrors.contains(where: { $0.contains("Birthday") }) {
                        Text(validationErrors.first(where: { $0.contains("Birthday") }) ?? "")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                }
                
                // Weight
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Weight (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    // Weight unit selection
                    Picker("Weight Unit", selection: $unitService.selectedUnit) {
                        Text("Kilograms (kg)").tag(WeightUnit.kg)
                        Text("Pounds (lb)").tag(WeightUnit.lb)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.bottom, ModernDesignSystem.Spacing.xs)
                    
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        TextField("Weight (\(unitService.getUnitSymbol()))", value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($isWeightFieldFocused)
                            .modernInputField()
                            .onChange(of: weightKg) { _, _ in
                                validateForm()
                            }
                            .id("weightField")
                        
                        Text(unitService.getUnitSymbol())
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    if validationErrors.contains(where: { $0.contains("Weight") }) {
                        Text(validationErrors.first(where: { $0.contains("Weight") }) ?? "")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                }
                
                // Activity Level
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Activity Level")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Picker("Activity Level", selection: $activityLevel) {
                        Text("Low").tag(PetActivityLevel.low)
                        Text("Moderate").tag(PetActivityLevel.moderate)
                        Text("High").tag(PetActivityLevel.high)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            Spacer()
        }
        .padding(.bottom, ModernDesignSystem.Spacing.lg)
    }
    
    private var allergiesAndVetStep: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Text("Health & Safety")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Share any known allergies or sensitivities to help us keep your pet safe.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, ModernDesignSystem.Spacing.xxl)
            
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Known Sensitivities
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Known Sensitivities (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    if !knownSensitivities.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: ModernDesignSystem.Spacing.sm) {
                            ForEach(knownSensitivities, id: \.self) { sensitivity in
                                HStack {
                                    Text(sensitivity)
                                        .font(ModernDesignSystem.Typography.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                    
                                    Button(action: {
                                        knownSensitivities.removeAll { $0 == sensitivity }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                                    }
                                }
                                .modernCard()
                            }
                        }
                    }
                    
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                    TextField("Add sensitivity", text: $newSensitivity)
                        .modernInputField()
                        
                        Button("Add") {
                            if !newSensitivity.isEmpty {
                                knownSensitivities.append(newSensitivity)
                                newSensitivity = ""
                            }
                        }
                        .modernButton(style: .primary)
                        .disabled(newSensitivity.isEmpty)
                        .opacity(newSensitivity.isEmpty ? 0.5 : 1.0)
                    }
                }
                
                // Vet information
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Veterinary Information (Optional)")
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    TextField("Vet Name", text: $vetName)
                        .modernInputField()
                    
                    TextField("Vet Phone", text: $vetPhone)
                        .keyboardType(.phonePad)
                        .modernInputField()
                }
            }
            .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            
            Spacer()
        }
    }
    
    /// Completion step for premium users (skips paywall)
    private var completionStep: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                // Success illustration
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                
                Text("You're All Set!")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("As a premium member, you have access to all features. Let's create your pet profile!")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, ModernDesignSystem.Spacing.xxl)
            
            Spacer()
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
    
    /// Paywall step for premium subscription
    private var paywallStep: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                // Premium Feature Illustration
                Image("Illustrations/premium-feature")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                
                Text("Unlock Premium Features")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Get unlimited scans, advanced analytics, and premium health tracking for your pet.")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, ModernDesignSystem.Spacing.xxl)
            
            // Features List
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                OnboardingPaywallFeatureRow(icon: "camera.fill", title: "Unlimited Scans", subtitle: "Scan as many products as you need")
                OnboardingPaywallFeatureRow(icon: "checkmark.shield.fill", title: "Advanced Detection", subtitle: "Get detailed sensitivity analysis")
                OnboardingPaywallFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Health Analytics", subtitle: "Track your pet's nutrition trends")
                OnboardingPaywallFeatureRow(icon: "pawprint.fill", title: "Unlimited Pets", subtitle: "Manage unlimited pet profiles")
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .background(ModernDesignSystem.Colors.softCream)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            
            // Pricing Options (if available)
            if !subscriptionViewModel.products.isEmpty {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                    Text("Choose Your Plan")
                        .font(ModernDesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .padding(.horizontal, ModernDesignSystem.Spacing.xs)
                    
                    ForEach(Array(subscriptionViewModel.products.enumerated()), id: \.element.id) { index, product in
                        OnboardingPricingCard(
                            product: product,
                            isSelected: subscriptionViewModel.isSelected(product),
                            savings: subscriptionViewModel.savings(for: product)
                        ) {
                            subscriptionViewModel.selectProduct(product)
                        }
                    }
                }
                .padding(.horizontal, ModernDesignSystem.Spacing.lg)
            } else if subscriptionViewModel.isLoading {
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    ProgressView()
                        .tint(ModernDesignSystem.Colors.primary)
                    Text("Loading subscription options...")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(ModernDesignSystem.Spacing.xl)
            }
            
            Spacer()
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
        .task {
            await subscriptionViewModel.refreshStatus()
        }
    }
    
    // MARK: - Computed Properties
    
    /// Available years for selection (from 1900 to current year)
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array(1900...currentYear).reversed()
    }
    
    /// Available months for selection with display names
    private var availableMonths: [(Int, String)] {
        return [
            (1, "January"), (2, "February"), (3, "March"), (4, "April"),
            (5, "May"), (6, "June"), (7, "July"), (8, "August"),
            (9, "September"), (10, "October"), (11, "November"), (12, "December")
        ]
    }
    
    /// Check if first name is valid for profile setup
    private var isUserFirstNameValid: Bool {
        userFirstName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }
    
    /// Check if username is valid (if provided)
    private var isUserUsernameValid: Bool {
        userUsername.isEmpty || InputValidator.isValidUsername(userUsername)
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0...4:
            // Feature tour screens - always proceed
            return true
        case 5:
            if needsProfileSetup {
                // Profile setup step - first name required
                return isUserFirstNameValid && isUserUsernameValid
            } else {
                // Basic pet info step - pet name required (when profile setup wasn't shown)
                return !name.isEmpty && name.count >= 2
            }
        case 6:
            if needsProfileSetup {
                // Basic pet info step - pet name required
                return !name.isEmpty && name.count >= 2
            } else {
                return true // Physical info step (all optional)
            }
        case 7:
            if needsProfileSetup {
                return true // Physical info step (all optional)
            } else {
                return true // Allergies and vet step (all optional)
            }
        case 8:
            if needsProfileSetup {
                return true // Allergies and vet step (all optional)
            } else {
                return true // Paywall/completion step (always proceed)
            }
        case 9:
            return true // Paywall/completion step (always proceed)
        default:
            // Handle steps that use stepOffset (after profile setup is saved)
            // Basic pet info step tag is (5 + stepOffset)
            if currentStep == (5 + stepOffset) {
                // Basic pet info step - pet name required
                return !name.isEmpty && name.count >= 2
            }
            // Physical info step tag is (6 + stepOffset) - all optional
            if currentStep == (6 + stepOffset) {
                return true
            }
            // Allergies and vet step tag is (7 + stepOffset) - all optional
            if currentStep == (7 + stepOffset) {
                return true
            }
            // Paywall/completion step tag is (8 + stepOffset) - always proceed
            if currentStep == (8 + stepOffset) {
                return true
            }
            return false
        }
    }
    
    /// Check if user can proceed from a specific step (used for swipe validation)
    /// - Parameter step: The step number to validate
    /// - Returns: True if validation passes for that step
    private func canProceedFromStep(_ step: Int) -> Bool {
        switch step {
        case 0...4:
            // Feature tour screens - always proceed
            return true
        case 5:
            if needsProfileSetup {
                // Profile setup step - first name required
                return isUserFirstNameValid && isUserUsernameValid
            } else {
                // Basic pet info step - pet name required (when profile setup wasn't shown)
                return !name.isEmpty && name.count >= 2
            }
        case 6:
            if needsProfileSetup {
                // Basic pet info step - pet name required
                return !name.isEmpty && name.count >= 2
            } else {
                return true // Physical info step (all optional)
            }
        case 7:
            if needsProfileSetup {
                return true // Physical info step (all optional)
            } else {
                return true // Allergies and vet step (all optional)
            }
        case 8:
            if needsProfileSetup {
                return true // Allergies and vet step (all optional)
            } else {
                return true // Paywall step (always proceed)
            }
        case 9:
            return true // Paywall step (always proceed)
        default:
            // Handle steps that use stepOffset (after profile setup is saved)
            // Basic pet info step tag is (5 + stepOffset)
            if step == (5 + stepOffset) {
                // Basic pet info step - pet name required
                return !name.isEmpty && name.count >= 2
            }
            // Physical info step tag is (6 + stepOffset) - all optional
            if step == (6 + stepOffset) {
                return true
            }
            // Allergies and vet step tag is (7 + stepOffset) - all optional
            if step == (7 + stepOffset) {
                return true
            }
            // Paywall/completion step tag is (8 + stepOffset) - always proceed
            if step == (8 + stepOffset) {
                return true
            }
            return false
        }
    }
    
    /// Button text based on current step
    private var buttonText: String {
        if currentStep == totalSteps - 1 {
            return subscriptionViewModel.selectedProductID != nil ? "Subscribe & Continue" : "Continue"
        } else {
            return "Next"
        }
    }
    
    // MARK: - Methods
    
    /// Get the previous step number, accounting for dynamic step structure
    /// Handles the case where profile setup step is removed after saving
    /// - Parameter currentStep: The current step number
    /// - Returns: The previous step number
    private func getPreviousStep(from currentStep: Int) -> Int {
        // Feature tour steps (0-4): just decrement
        if currentStep <= 4 {
            return max(0, currentStep - 1)
        }
        
        // If we're on basic pet info step (5 + stepOffset)
        // After profile setup is saved, needsProfileSetup becomes false
        // So stepOffset changes from 6 to 5, and basic pet info tag is 10
        // Going back from basic pet info:
        // - If profile setup was shown initially, go back to profile setup (step 5)
        // - If profile setup was never shown, go to last feature tour (step 4)
        if currentStep == (5 + stepOffset) {
            if profileSetupWasShown {
                // Go back to profile setup step (step 5)
                return 5
            } else {
                // Go back to last feature tour screen (step 4)
                return 4
            }
        }
        
        // If we're on profile setup step (step 5) and it still exists
        if currentStep == 5 && needsProfileSetup {
            // Go back to last feature tour screen (step 4)
            return 4
        }
        
        // For all other steps, just decrement
        // But we need to handle the case where we might skip over removed steps
        let previousStep = currentStep - 1
        
        // If previous step would be 5 and profile setup doesn't exist, skip to 4
        if previousStep == 5 && !needsProfileSetup {
            return 4
        }
        
        return previousStep
    }
    
    /// Handle paywall action - subscribe if product selected, otherwise just create pet
    private func handlePaywallAction() {
        if subscriptionViewModel.selectedProductID != nil {
            // User selected a subscription plan - try to purchase
            // MEMORY OPTIMIZATION: Store task for cancellation
            let paywallTask = Task { @MainActor in
                guard !Task.isCancelled else { return }
                await subscriptionViewModel.purchaseSubscription()
                guard !Task.isCancelled else { return }
                // After purchase attempt (success or failure), create the pet
                // The pet creation should happen regardless of subscription status
                createPet(shouldDismissOnboarding: false)
            }
            validationTasks.append(paywallTask)
        } else {
            // No subscription selected - just create pet
            createPet(shouldDismissOnboarding: false)
        }
    }
    
    /// Save user profile with first name, last name, and optional username
    /// Called when transitioning from profile setup step
    /// Uses silent profile update (showLoadingState: false) to prevent UI reset during onboarding
    private func saveUserProfile() async {
        isSavingProfile = true
        
        defer {
            Task { @MainActor in
                isSavingProfile = false
            }
        }
        
        let trimmedFirstName = userFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = userLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = userUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate that first name is provided (required)
        guard !trimmedFirstName.isEmpty else {
            print("❌ User profile save failed: First name is required")
            await MainActor.run {
                showProfileNameError = true
            }
            return
        }
        
        // Use showLoadingState: false to prevent authState from changing to .loading
        // This prevents ContentView from resetting the OnboardingView and losing the current step
        await authService.updateProfile(
            username: trimmedUsername.isEmpty ? nil : trimmedUsername,
            firstName: trimmedFirstName,
            lastName: trimmedLastName.isEmpty ? nil : trimmedLastName,
            showLoadingState: false
        )
        
        // Check for errors first
        if let errorMessage = authService.errorMessage {
            print("❌ User profile save failed: \(errorMessage)")
            await MainActor.run {
                showProfileNameError = true
            }
            return
        }
        
        // Refresh user profile to get the updated user from the server
        // This ensures we have the latest data including the saved profile
        // CRITICAL: This updates authState, but we're about to navigate away anyway
        await authService.refreshUserProfile(forceRefresh: true)
        
        // Verify the profile was saved
        if let updatedUser = authService.currentUser,
           updatedUser.firstName == trimmedFirstName {
            print("✅ User profile saved successfully: firstName=\(updatedUser.firstName ?? "nil"), lastName=\(updatedUser.lastName ?? "nil"), username=\(updatedUser.username ?? "nil")")
        } else {
            print("⚠️ User profile save may have failed - firstName mismatch")
            await MainActor.run {
                showProfileNameError = true
            }
        }
    }
    
    private func validateForm() {
        // Convert weight to kg for validation (backend expects kg)
        let weightInKg = weightKg != nil ? unitService.convertToKg(weightKg!) : nil
        
        let petCreate = PetCreate(
            name: name,
            species: species,
            breed: breed.isEmpty ? nil : breed,
            birthday: createBirthday(year: birthYear, month: birthMonth),
            weightKg: weightInKg,
            activityLevel: activityLevel,
            imageUrl: nil,
            knownSensitivities: knownSensitivities,
            vetName: vetName.isEmpty ? nil : vetName,
            vetPhone: vetPhone.isEmpty ? nil : vetPhone
        )
        validationErrors = petCreate.validationErrors
    }
    
    /// Create pet and mark onboarding as complete
    /// - Parameter shouldDismissOnboarding: If true, calls onSkip() after successful pet creation to dismiss onboarding
    private func createPet(shouldDismissOnboarding: Bool = false) {
        let onboardingStartTime = Date() // Track onboarding completion time
        isCreatingPet = true
        
        // Convert weight to kg for storage (backend expects kg)
        let weightInKg = weightKg != nil ? unitService.convertToKg(weightKg!) : nil
        
        // Create the pet with image upload
        // MEMORY OPTIMIZATION: Store task for cancellation
        let createPetTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            var imageUrl: String? = nil
            
            // Upload pet image if provided
            if let petImage = petImage,
               let userId = authService.currentUser?.id {
                do {
                    // Generate a temporary pet ID for image upload
                    let tempPetId = UUID().uuidString
                    imageUrl = try await StorageService.shared.uploadPetImage(
                        image: petImage,
                        userId: userId,
                        petId: tempPetId
                    )
                    print("📸 Pet image uploaded successfully: \(imageUrl ?? "nil")")
                } catch {
                    print("⚠️ Failed to upload pet image: \(error)")
                    // Continue with pet creation even if image upload fails
                }
            }
            
            let petCreate = PetCreate(
                name: name,
                species: species,
                breed: breed.isEmpty ? nil : breed,
                birthday: createBirthday(year: birthYear, month: birthMonth),
                weightKg: weightInKg,
                activityLevel: activityLevel,
                imageUrl: imageUrl,
                knownSensitivities: knownSensitivities,
                vetName: vetName.isEmpty ? nil : vetName,
                vetPhone: vetPhone.isEmpty ? nil : vetPhone
            )
            
            // Use the pet service's createPet method
            petService.createPet(petCreate)
            
            // Wait for the pet creation to complete by monitoring the service state
            // Add timeout to prevent infinite loop
            var waitCount = 0
            let maxWaitCount = 100 // 10 seconds max wait (100 * 0.1s)
            while petService.isLoading && waitCount < maxWaitCount {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                waitCount += 1
                guard !Task.isCancelled else { return }
            }
            
            if petService.errorMessage == nil && !petService.isLoading {
                // Pet created successfully - verify it's in the pets array
                let createdPet = petService.pets.first(where: { $0.name == name })
                if createdPet != nil {
                    print("✅ Pet created successfully: \(name) (ID: \(createdPet!.id))")
                } else {
                    print("⚠️ Pet creation reported success but pet not found in array")
                }
                
                // Track onboarding completed
                let timeToComplete = Date().timeIntervalSince(onboardingStartTime)
                PostHogAnalytics.trackOnboardingCompleted(
                    timeToCompleteSec: timeToComplete,
                    petsCount: petService.pets.count
                )
                
                // Mark onboarding as complete FIRST (updates user.onboarded in database)
                // This ensures the user is marked as onboarded before dismissing
                await petService.completeOnboarding()
                
                    // Additional refresh to ensure state is fully synchronized
                    // This is critical for Apple ID users to ensure the state updates properly
                    await authService.refreshUserProfile(forceRefresh: true)
                    
                    // Wait to ensure state has propagated through SwiftUI's view updates
                    // This prevents race conditions where ContentView checks before state is updated
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    
                    // One final refresh and check to ensure state is truly updated
                    // Sometimes SwiftUI needs the state change to happen multiple times
                    var userIsOnboarded = false
                    for attempt in 1...3 {
                        await authService.refreshUserProfile(forceRefresh: true)
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                        
                        if let user = await MainActor.run(body: { authService.currentUser }), user.onboarded {
                            userIsOnboarded = true
                            print("✅ User confirmed onboarded on attempt \(attempt)")
                            break
                        } else {
                            print("⚠️ Attempt \(attempt): User still not marked as onboarded")
                        }
                    }
                    
                    // Dismiss onboarding regardless - pet was created successfully
                    await MainActor.run {
                        if userIsOnboarded {
                            print("✅ Onboarding flow complete - user onboarded and pet created")
                        } else {
                            print("⚠️ Warning: Could not verify user onboarded status after 3 attempts, but pet was created - dismissing anyway")
                        }
                        
                        if shouldDismissOnboarding {
                            onSkip()
                        }
                        isCreatingPet = false
                    }
            } else {
                await MainActor.run {
                    let errorMsg = petService.errorMessage ?? "Unknown error"
                    print("❌ Pet creation failed: \(errorMsg)")
                    if petService.isLoading {
                        print("⚠️ Pet creation still loading after timeout")
                    }
                    isCreatingPet = false
                }
            }
        }
        validationTasks.append(createPetTask)
    }
    
    // MARK: - Helper Functions
    
    /// Create a Date from year and month inputs
    private func createBirthday(year: Int?, month: Int?) -> Date? {
        guard let year = year, let month = month else { return nil }
        
        // Validate year and month
        let currentYear = Calendar.current.component(.year, from: Date())
        guard year >= 1900 && year <= currentYear else { return nil }
        guard month >= 1 && month <= 12 else { return nil }
        
        // Create date with first day of the month at midnight UTC
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        
        return Calendar.current.date(from: components)
    }
    
    /// Calculate age description from birthday
    private func calculateAge(from birthday: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: birthday, to: now)
        
        guard let years = components.year, let months = components.month else { return "Unknown" }
        
        if years == 0 {
            return "\(months) month\(months == 1 ? "" : "s") old"
        } else if months == 0 {
            return "\(years) year\(years == 1 ? "" : "s") old"
        } else {
            return "\(years) year\(years == 1 ? "" : "s"), \(months) month\(months == 1 ? "" : "s") old"
        }
    }
    
    /// Get month name for display
    private func monthName(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let date = Calendar.current.date(from: DateComponents(year: 2024, month: month, day: 1))!
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

/// Feature row component displaying an icon, title, and description
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(ModernDesignSystem.Typography.title2)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(title)
                    .font(ModernDesignSystem.Typography.bodyEmphasized)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(description)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
    }
}

/// Feature row component for onboarding paywall
struct OnboardingPaywallFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                Text(title)
                    .font(ModernDesignSystem.Typography.bodyEmphasized)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text(subtitle)
                    .font(ModernDesignSystem.Typography.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.primary)
        }
        .padding(.vertical, ModernDesignSystem.Spacing.xs)
    }
}

/// Pricing card component for onboarding paywall
struct OnboardingPricingCard: View {
    let product: SubscriptionProduct
    let isSelected: Bool
    let savings: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(product.planLabel)
                        .font(ModernDesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    HStack(spacing: ModernDesignSystem.Spacing.xs) {
                        Text(product.price)
                            .font(ModernDesignSystem.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        Text(product.duration)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    if let savings = savings {
                        Text(savings)
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                            .fontWeight(.semibold)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(ModernDesignSystem.Typography.title2)
                    .foregroundColor(isSelected ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.textSecondary)
            }
            .padding(ModernDesignSystem.Spacing.md)
        }
        .background(
            isSelected ?
            ModernDesignSystem.Colors.primary.opacity(0.1) :
            ModernDesignSystem.Colors.softCream
        )
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(
                    isSelected ? ModernDesignSystem.Colors.primary : ModernDesignSystem.Colors.borderPrimary,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
    }
}

// MARK: - Feature Screen View Component

/// Individual feature screen display for onboarding flow
private struct FeatureScreenView: View {
    let icon: String
    let title: String
    let description: String
    let highlights: [String]
    
    @State private var hasAppeared = false
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.xl) {
            Spacer()
            
            // Icon with animated background
            ZStack {
                // Background circle
                Circle()
                    .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .scaleEffect(hasAppeared ? 1.0 : 0.8)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .scaleEffect(hasAppeared ? 1.0 : 0.6)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: hasAppeared)
            
            // Title
            Text(title)
                .font(ModernDesignSystem.Typography.largeTitle)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(hasAppeared ? 1.0 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: hasAppeared)
            
            // Description
            Text(description)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, ModernDesignSystem.Spacing.xl)
                .opacity(hasAppeared ? 1.0 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.2), value: hasAppeared)
            
            // Highlights
            VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                ForEach(Array(highlights.enumerated()), id: \.offset) { index, highlight in
                    HStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        Text(highlight)
                            .font(ModernDesignSystem.Typography.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    }
                    .opacity(hasAppeared ? 1.0 : 0)
                    .offset(x: hasAppeared ? 0 : -20)
                    .animation(.easeOut(duration: 0.4).delay(0.3 + Double(index) * 0.1), value: hasAppeared)
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .fill(ModernDesignSystem.Colors.softCream)
                    .shadow(color: ModernDesignSystem.Shadows.small.color,
                            radius: ModernDesignSystem.Shadows.small.radius,
                            x: ModernDesignSystem.Shadows.small.x,
                            y: ModernDesignSystem.Shadows.small.y)
            )
            .padding(.horizontal, ModernDesignSystem.Spacing.xl)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            hasAppeared = true
        }
        .onDisappear {
            hasAppeared = false
        }
    }
}

#Preview {
    OnboardingView(onSkip: {
        print("Skipped onboarding")
    })
}