//
//  ProfileSettingsView.swift
//  SniffTest
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI

/**
 * Unified profile and settings view following Trust & Nature Design System
 * 
 * Features:
 * - Warm, trustworthy profile header with soft cream background
 * - Card-based layout with consistent spacing and shadows
 * - Trust & Nature color palette throughout
 * - Accessible typography hierarchy
 * - Professional, nature-inspired design
 * 
 * Design System Compliance:
 * - Uses ModernDesignSystem for all styling
 * - Follows Trust & Nature color palette
 * - Implements consistent spacing scale
 * - Applies proper shadows and corner radius
 * - Maintains accessibility standards
 */
struct ProfileSettingsView: View {
    // MARK: - Settings Manager
    @StateObject private var settingsManager = SettingsManager.shared
    
    // MARK: - State Properties
    @State private var showingClearCacheAlert = false
    @State private var showingResetSettingsAlert = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var cacheSize = "0 MB"
    @State private var showingGDPRView = false
    @State private var showingSubscriptionView = false
    @State private var showingEditProfile = false
    @State private var isRefreshingCache = false
    @State private var refreshProfileTask: Task<Void, Never>?
    @State private var analyticsTask: Task<Void, Never>?
    @State private var cacheSizeTask: Task<Void, Never>?
    @State private var lastAppearTime: Date?
    @State private var lastCacheSizeCalculation: Date?
    
    // MARK: - Service Dependencies
    @EnvironmentObject var authService: AuthService
    @State private var petService = CachedPetService.shared
    // MEMORY FIX: Use @ObservedObject for shared singletons to prevent memory leaks
    // @StateObject creates a new instance, but these are singletons - we should observe, not own
    @ObservedObject private var gdprService = GDPRService.shared
    @ObservedObject private var analyticsManager = AnalyticsManager.shared
    @ObservedObject private var notificationSettingsManager = NotificationSettingsManager.shared
    @ObservedObject private var weightUnitService = WeightUnitPreferenceService.shared
    @ObservedObject private var profileService = CachedProfileService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // MARK: - Profile Header Card
                    profileHeaderCard
                    
                    // MARK: - Settings Cards
                    VStack(spacing: ModernDesignSystem.Spacing.md) {
                        // Account & Subscription
                        accountSubscriptionCard
                        
                        // Pet & Scanning
                        petScanningCard
                        
                        // Preferences & Notifications
                        preferencesNotificationsCard
                        
                        // Privacy & Data
                        privacyDataCard
                        
                        // Support & About
                        supportAboutCard
                        
                        // Account Actions
                        accountActionsCard
                    }
                }
                .padding(ModernDesignSystem.Spacing.md)
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Profile & Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .onAppear {
                // CRITICAL: Check navigation coordinator first - skip all operations if in cooldown
                if TabNavigationCoordinator.shared.shouldBlockOperations() {
                    print("⏭️ ProfileSettingsView: Skipping onAppear - navigation cooldown active")
                    return
                }
                
                // CRITICAL: Debounce rapid tab switches to prevent freezing and memory leaks
                let now = Date()
                if let lastAppear = lastAppearTime, now.timeIntervalSince(lastAppear) < 0.5 {
                    print("⏭️ ProfileSettingsView: Skipping onAppear (too soon after last appear: \(now.timeIntervalSince(lastAppear))s)")
                    return
                }
                lastAppearTime = now
                
                // CRITICAL: Cancel ALL existing tasks FIRST to prevent memory leaks
                cacheSizeTask?.cancel()
                cacheSizeTask = nil
                refreshProfileTask?.cancel()
                refreshProfileTask = nil
                analyticsTask?.cancel()
                analyticsTask = nil
                
                // CRITICAL: Longer delay to ensure previous view is completely gone
                // This is essential for preventing freezes when switching rapidly
                Task(priority: .utility) { @MainActor in
                    // Wait longer to ensure previous view's onDisappear completed
                    try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds (increased)
                    guard !Task.isCancelled else { return }
                    
                    // Double-check coordinator before proceeding
                    if TabNavigationCoordinator.shared.shouldBlockOperations() {
                        print("⏭️ ProfileSettingsView: Aborting operations - cooldown still active")
                        return
                    }
                    
                    // Yield to allow any pending cancellations to complete
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    
                    // Track analytics (non-blocking)
                    analyticsTask = Task(priority: .utility) { @MainActor in
                        guard !Task.isCancelled else { return }
                        PostHogAnalytics.trackSettingsViewOpened()
                    }
                    
                    // Calculate cache size only if not calculated recently (debounce)
                    let shouldCalculateCacheSize: Bool
                    if let lastCalculation = lastCacheSizeCalculation {
                        shouldCalculateCacheSize = Date().timeIntervalSince(lastCalculation) > 3.0 // 3 seconds
                    } else {
                        shouldCalculateCacheSize = true
                    }
                    
                    if shouldCalculateCacheSize {
                        calculateCacheSize()
                    }
                    
                    // Refresh user profile - but only if view is still visible
                    refreshProfileTask = Task(priority: .utility) { @MainActor in
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        await authService.refreshUserProfile(forceRefresh: true)
                    }
                }
            }
            .onDisappear {
                // CRITICAL: Cancel all ongoing tasks to prevent state updates and memory leaks
                // Cancel in reverse order of creation to ensure proper cleanup
                cacheSizeTask?.cancel()
                cacheSizeTask = nil
                refreshProfileTask?.cancel()
                refreshProfileTask = nil
                analyticsTask?.cancel()
                analyticsTask = nil
                
                // Reset state to prevent memory retention
                // Don't reset lastAppearTime or lastCacheSizeCalculation - they're used for debouncing
            }
            .sheet(isPresented: $showingGDPRView) {
                GDPRView()
                    .environmentObject(gdprService)
            }
            .sheet(isPresented: $showingSubscriptionView) {
                SubscriptionView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
                    .environmentObject(authService)
            }
            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear Only", role: .destructive) {
                    clearCache()
                }
                Button("Clear & Refresh", role: .destructive) {
                    clearCacheAndRefresh()
                }
            } message: {
                Text("Clear Only: Removes cached data.\nClear & Refresh: Clears cache and reloads fresh data from server.")
            }
            .alert("Reset Settings", isPresented: $showingResetSettingsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetSettings()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authService.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
        }
        .trackScreen("ProfileSettings")
    }
    
    // MARK: - Profile Header Card
    private var profileHeaderCard: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Profile Picture with Trust & Nature styling
            RemoteImageView(userImageUrl: authService.currentUser?.imageUrl)
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 2)
                )
                .onAppear {
                    print("🔍 ProfileSettingsView: User data - imageUrl: \(authService.currentUser?.imageUrl ?? "nil")")
                    print("🔍 ProfileSettingsView: Full user data: \(authService.currentUser?.description ?? "nil")")
                }
            
            if let user = authService.currentUser {
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    // User Name with Trust & Nature typography
                    Text("\(user.firstName ?? "") \(user.lastName ?? "")")
                        .font(ModernDesignSystem.Typography.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    // Email with secondary text styling
                    Text(user.email)
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    // Role badge with Trust & Nature colors
                    Text(user.role.displayName)
                        .font(ModernDesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, ModernDesignSystem.Spacing.md)
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        .background(
                            user.role == .premium ? 
                            ModernDesignSystem.Colors.goldenYellow : 
                            ModernDesignSystem.Colors.textSecondary
                        )
                        .foregroundColor(
                            user.role == .premium ? 
                            ModernDesignSystem.Colors.textOnAccent : 
                            ModernDesignSystem.Colors.textOnPrimary
                        )
                        .cornerRadius(ModernDesignSystem.CornerRadius.small)
                }
            } else {
                Text("No user data available")
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
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
    
    // MARK: - Account & Subscription Card
    private var accountSubscriptionCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Account & Subscription")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Edit Profile
                Button(action: { showingEditProfile = true }) {
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        Text("Edit Profile")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Subscription
                Button(action: { showingSubscriptionView = true }) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                        Text("Subscription")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                        Text(authService.currentUser?.role.rawValue.capitalized ?? "Free")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
                .buttonStyle(PlainButtonStyle())
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
    
    // MARK: - Pet & Scanning Card
    private var petScanningCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "pawprint.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Pet & Scanning")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Pet Count
                HStack {
                    Text("Total Pets")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    Spacer()
                    Text("\(petService.pets.count)")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Default Pet Selection
                if !petService.pets.isEmpty {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Default Pet for Scans")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Picker("Default Pet for Scans", selection: Binding(
                            get: {
                                // Validate selection exists in current pets
                                let petIds = petService.pets.map { $0.id }
                                if let currentId = settingsManager.defaultPetId,
                                   petIds.contains(currentId) {
                                    return currentId
                                }
                                // Invalid selection - return nil
                                return nil
                            },
                            set: { newValue in
                                settingsManager.defaultPetId = newValue
                            }
                        )) {
                            Text("None").tag(nil as String?)
                            ForEach(petService.pets) { pet in
                                Text(pet.name).tag(pet.id as String?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(ModernDesignSystem.Colors.primary)
                    }
                    
                    Divider()
                        .background(ModernDesignSystem.Colors.borderPrimary)
                } else {
                    HStack {
                        Image(systemName: "pawprint")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Text("No pets added yet")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        Spacer()
                        NavigationLink("Add Pet", destination: AddPetView())
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                    
                    Divider()
                        .background(ModernDesignSystem.Colors.borderPrimary)
                }
                
                // Weight Unit Preference
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Weight Unit")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Picker("Weight Unit", selection: $weightUnitService.selectedUnit) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .accentColor(ModernDesignSystem.Colors.primary)
                    .onChange(of: weightUnitService.selectedUnit) { _, newUnit in
                        weightUnitService.setUnit(newUnit)
                    }
                }
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Scan Preferences Section
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Scan Preferences")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        // Auto-save Scans
                        HStack {
                            Text("Auto-save Scans")
                                .font(ModernDesignSystem.Typography.body)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            Spacer()
                            Toggle("", isOn: $settingsManager.scanAutoSave)
                                .tint(ModernDesignSystem.Colors.primary)
                        }
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        
                        Divider()
                            .background(ModernDesignSystem.Colors.borderPrimary)
                        
                        // Auto-analyze Scans
                        HStack {
                            Text("Auto-analyze Scans")
                                .font(ModernDesignSystem.Typography.body)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            Spacer()
                            Toggle("", isOn: $settingsManager.enableAutoAnalysis)
                                .tint(ModernDesignSystem.Colors.primary)
                        }
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
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
    
    // MARK: - Preferences & Notifications Card
    private var preferencesNotificationsCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Preferences & Notifications")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Notification Permission Status
                HStack {
                    Image(systemName: notificationSettingsManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(notificationSettingsManager.isAuthorized ? ModernDesignSystem.Colors.success : ModernDesignSystem.Colors.warning)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notificationSettingsManager.isAuthorized ? "Notifications Enabled" : "Notifications Required")
                            .font(ModernDesignSystem.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        Text(notificationSettingsManager.isAuthorized ? 
                             "You'll receive reminders and updates" :
                             "Enable notifications to receive important reminders")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    if !notificationSettingsManager.isAuthorized {
                        NavigationLink(destination: NotificationPermissionsView()) {
                            Text("Setup")
                                .font(ModernDesignSystem.Typography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(ModernDesignSystem.Colors.primary)
                        }
                    }
                }
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Notification Permissions Link (similar to Camera Permissions)
                NavigationLink(destination: NotificationPermissionsView()) {
                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        Text("Notification Permissions")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Master Notification Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Notifications")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        if !notificationSettingsManager.isAuthorized {
                            Text("Requires iPhone notification permission")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.warning)
                        }
                    }
                    
                    Spacer()
                    Toggle("", isOn: $notificationSettingsManager.enableNotifications)
                        .tint(ModernDesignSystem.Colors.primary)
                        .disabled(!notificationSettingsManager.isAuthorized)
                        .onChange(of: notificationSettingsManager.enableNotifications) { _, newValue in
                            if newValue && !notificationSettingsManager.isAuthorized {
                                Task { @MainActor in
                                    let granted = await notificationSettingsManager.requestPermission()
                                    if !granted {
                                        // If permission denied, reset toggle
                                        notificationSettingsManager.enableNotifications = false
                                    }
                                }
                            }
                        }
                }
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                
                // Engagement Notifications - only show when notifications are enabled and authorized
                if notificationSettingsManager.enableNotifications && notificationSettingsManager.isAuthorized {
                    Divider()
                        .background(ModernDesignSystem.Colors.borderPrimary)
                    
                    HStack {
                        Text("Engagement Reminders")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                        Toggle("", isOn: $notificationSettingsManager.engagementNotificationsEnabled)
                            .tint(ModernDesignSystem.Colors.primary)
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Haptic Feedback
                HStack {
                    Text("Haptic Feedback")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $settingsManager.enableHapticFeedback)
                        .tint(ModernDesignSystem.Colors.primary)
                }
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
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
        .onAppear {
            Task {
                await notificationSettingsManager.checkAuthorizationStatus()
            }
        }
    }
    
    // MARK: - Privacy & Data Card
    private var privacyDataCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Privacy & Data")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Analytics
                HStack {
                    Text("Analytics & Usage Data")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $settingsManager.enableAnalytics)
                        .tint(ModernDesignSystem.Colors.primary)
                        .onChange(of: settingsManager.enableAnalytics) { _, newValue in
                            analyticsManager.setAnalyticsEnabled(newValue)
                        }
                }
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // GDPR Controls
                Button(action: { showingGDPRView = true }) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        Text("Data & Privacy Controls")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Camera Permissions
                NavigationLink(destination: CameraPermissionsView()) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        Text("Camera Permissions")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Data Management Section
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Data Management")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        // Cache Management
                        Button(action: { showingClearCacheAlert = true }) {
                            HStack {
                                if isRefreshingCache {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(ModernDesignSystem.Colors.primary)
                                } else {
                                    Image(systemName: "externaldrive")
                                        .foregroundColor(ModernDesignSystem.Colors.primary)
                                }
                                Text(isRefreshingCache ? "Refreshing Cache..." : "Clear Cache")
                                    .font(ModernDesignSystem.Typography.body)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                Spacer()
                                if !isRefreshingCache {
                                    Text(cacheSize)
                                        .font(ModernDesignSystem.Typography.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                }
                            }
                            .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isRefreshingCache)
                        
                        Divider()
                            .background(ModernDesignSystem.Colors.borderPrimary)
                        
                        // Reset Settings
                        Button(action: { showingResetSettingsAlert = true }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(ModernDesignSystem.Colors.warning)
                                Text("Reset Settings")
                                    .font(ModernDesignSystem.Typography.body)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                            .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        }
                        .buttonStyle(PlainButtonStyle())
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
    
    // MARK: - Support & About Card
    private var supportAboutCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("Support & About")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                // Help Center
                NavigationLink(destination: HelpCenterView()) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        Text("Help Center")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Contact Support
                NavigationLink(destination: ContactSupportView()) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        Text("Contact Support")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Rate App
                Button(action: rateApp) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(ModernDesignSystem.Colors.goldenYellow)
                        Text("Rate App")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, ModernDesignSystem.Spacing.sm)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // About Section
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("About")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        // App Version
                        HStack {
                            Text("Version")
                                .font(ModernDesignSystem.Typography.body)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            Spacer()
                            Text(Bundle.main.appVersion)
                                .font(ModernDesignSystem.Typography.body)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                        .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        
                        Divider()
                            .background(ModernDesignSystem.Colors.borderPrimary)
                    
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
    
    // MARK: - Account Actions Card
    private var accountActionsCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Sign Out Button
            Button(action: { showingSignOutAlert = true }) {
                HStack {
                    Image(systemName: "arrow.right.square")
                        .foregroundColor(ModernDesignSystem.Colors.error)
                    Text("Sign Out")
                        .font(ModernDesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.error)
                    Spacer()
                }
                .padding(ModernDesignSystem.Spacing.lg)
            }
            .buttonStyle(PlainButtonStyle())
        }
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
    
    // MARK: - Helper Methods
    
    /// Calculate total cache size asynchronously to avoid blocking main thread
    /// CRITICAL: This function can be slow with large caches, so it includes:
    /// - Cancellation support
    /// - Timeout protection
    /// - Depth limiting to prevent excessive recursion
    /// - Yield points to prevent blocking
    private func calculateCacheSize() {
        // Cancel any existing cache size calculation
        cacheSizeTask?.cancel()
        cacheSizeTask = nil
        
        cacheSizeTask = Task.detached(priority: .utility) {
            // Check cancellation immediately
            guard !Task.isCancelled else { return }
            
            let fileManager = FileManager.default
            
            guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return
            }
            
            var totalSize: Int64 = 0
            var fileCount = 0
            let maxFiles = 10000 // Limit to prevent excessive scanning
            let maxDepth = 10 // Limit recursion depth
            
            // Recursively calculate directory size with depth and file count limits
            func calculateDirectorySize(at url: URL, depth: Int = 0) async -> Int64 {
                // Check cancellation and limits
                guard !Task.isCancelled else { return 0 }
                guard depth < maxDepth else { return 0 }
                guard fileCount < maxFiles else { return 0 }
                
                var size: Int64 = 0
                
                do {
                    let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles])
                    
                    // Yield periodically to prevent blocking
                    if fileCount % 100 == 0 {
                        await Task.yield()
                        guard !Task.isCancelled else { return 0 }
                    }
                    
                    for fileURL in contents {
                        guard !Task.isCancelled else { return 0 }
                        guard fileCount < maxFiles else { break }
                        
                        let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                        
                        if let isDirectory = resourceValues?.isDirectory, isDirectory {
                            // Recursively calculate subdirectory size
                            size += await calculateDirectorySize(at: fileURL, depth: depth + 1)
                        } else if let fileSize = resourceValues?.fileSize {
                            size += Int64(fileSize)
                            fileCount += 1
                        }
                    }
                } catch {
                    // Silently fail - don't log every error to prevent log spam
                    if fileCount == 0 {
                        print("⚠️ Failed to read directory \(url.path): \(error.localizedDescription)")
                    }
                }
                
                return size
            }
            
            // Add timeout protection
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second timeout
                if !Task.isCancelled {
                    print("⚠️ Cache size calculation timed out after 5 seconds")
                }
            }
            
            defer {
                timeoutTask.cancel()
            }
            
            // Calculate size with limits
            totalSize = await calculateDirectorySize(at: cachesURL)
            
            // Check cancellation before updating UI
            guard !Task.isCancelled else { return }
            
            let sizeInMB = Double(totalSize) / 1024.0 / 1024.0
            
            await MainActor.run {
                // Double-check cancellation before state update
                guard !Task.isCancelled else { return }
                cacheSize = String(format: "%.2f MB", sizeInMB)
                lastCacheSizeCalculation = Date()
            }
        }
    }
    
    /**
     * Clear all cached data (file system and app cache)
     * Clears UnifiedCacheCoordinator, service in-memory caches, and file system cache
     */
    private func clearCache() {
        Task.detached(priority: .userInitiated) { @MainActor in
            // Clear UnifiedCacheCoordinator cache (memory + disk)
            CacheHydrationService.shared.clearAllCaches()
            
            // Clear file system cache
            let fileManager = FileManager.default
            guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return
            }
            
            do {
                let cacheFiles = try fileManager.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil)
                
                for file in cacheFiles {
                    try fileManager.removeItem(at: file)
                }
                
                HapticFeedback.success()
                calculateCacheSize()
                print("✅ Cache cleared successfully")
            } catch {
                print("Failed to clear file system cache: \(error)")
                HapticFeedback.error()
            }
        }
    }
    
    /**
     * Clear cache and refresh with live data from server
     * This ensures the app has the latest data after clearing cache
     */
    private func clearCacheAndRefresh() {
        Task { @MainActor in
            isRefreshingCache = true
            
            // Clear all caches first
            CacheHydrationService.shared.clearAllCaches()
            
            // Clear file system cache
            let fileManager = FileManager.default
            if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                do {
                    let cacheFiles = try fileManager.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil)
                    for file in cacheFiles {
                        try fileManager.removeItem(at: file)
                    }
                } catch {
                    print("Failed to clear file system cache: \(error)")
                }
            }
            
            // Refresh cache with live data from server (force refresh)
            await CacheHydrationService.shared.hydrateAllCaches(forceRefresh: true)
            
            // Update cache size
            calculateCacheSize()
            
            isRefreshingCache = false
            HapticFeedback.success()
            print("✅ Cache cleared and refreshed with live data")
        }
    }
    
    /// Reset all settings to default values
    private func resetSettings() {
        settingsManager.resetToDefaults()
    }
    
    /// Delete user account and all associated data
    private func deleteAccount() async {
        let success = await gdprService.deleteUserData()
        if success {
            // Account deletion handled by GDPRService
            HapticFeedback.success()
        } else {
            HapticFeedback.error()
        }
    }
    
    /// Open App Store rating page
    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/id1234567890") {
            UIApplication.shared.open(url)
        }
    }
    
    /// Share the app with others
    private func shareApp() {
        let activityViewController = UIActivityViewController(
            activityItems: ["Check out Pet Allergy Scanner - keep your pets safe!"],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
}

// MARK: - Supporting Views

/// View for camera permissions management
struct CameraPermissionsView: View {
    @State private var permissionStatus = "Unknown"
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Camera Permissions")
                .font(ModernDesignSystem.Typography.title2)
            
            Text("Camera access is required to scan ingredient labels. You can manage permissions in your device settings.")
                .font(ModernDesignSystem.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            .modernButton(style: .primary)
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .navigationTitle("Camera Permissions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// View for notification permissions management
/// Similar to CameraPermissionsView, guides users to enable notifications
struct NotificationPermissionsView: View {
    // MEMORY FIX: Use @ObservedObject for shared singleton to prevent memory leaks
    @ObservedObject private var notificationSettingsManager = NotificationSettingsManager.shared
    @State private var showingPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                
                Text("Notification Permissions")
                    .font(ModernDesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    Text("Notifications are required for the app to send you important reminders about your pet's health and safety.")
                        .font(ModernDesignSystem.Typography.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    // Permission Status
                    HStack {
                        Image(systemName: notificationSettingsManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(notificationSettingsManager.isAuthorized ? ModernDesignSystem.Colors.success : ModernDesignSystem.Colors.warning)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notificationSettingsManager.isAuthorized ? "Notifications Enabled" : "Notifications Disabled")
                                .font(ModernDesignSystem.Typography.bodyEmphasized)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Text(notificationSettingsManager.isAuthorized ?
                                 "You'll receive birthday reminders, engagement notifications, and meal reminders." :
                                 "Enable notifications in Settings to receive important updates about your pet.")
                                .font(ModernDesignSystem.Typography.subheadline)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(ModernDesignSystem.Spacing.md)
                    .background(ModernDesignSystem.Colors.softCream)
                    .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.sm) {
                        Text("How to Enable Notifications:")
                            .font(ModernDesignSystem.Typography.title3)
                            .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            InstructionStep(number: "1", text: "Tap 'Request Permission' below")
                            InstructionStep(number: "2", text: "Allow notifications when prompted")
                            InstructionStep(number: "3", text: "If permission was denied, go to Settings > Notifications > Pet Allergy Scanner")
                        }
                    }
                    .padding(ModernDesignSystem.Spacing.md)
                    .background(ModernDesignSystem.Colors.softCream)
                    .cornerRadius(ModernDesignSystem.CornerRadius.medium)
                    
                    // Action Buttons
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        if !notificationSettingsManager.isAuthorized {
                            Button(action: {
                                Task {
                                    await requestNotificationPermission()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "bell.badge")
                                    Text("Request Permission")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .modernButton(style: .primary)
                        }
                        
                        Button(action: openAppSettings) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text("Open iPhone Settings")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .modernButton(style: .secondary)
                    }
                }
                .padding(ModernDesignSystem.Spacing.lg)
                
                Spacer()
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        .navigationTitle("Notification Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                openAppSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(permissionAlertMessage)
        }
        .onAppear {
            Task {
                await notificationSettingsManager.checkAuthorizationStatus()
            }
        }
    }
    
    /**
     * Request notification permission from the user
     */
    private func requestNotificationPermission() async {
        let granted = await notificationSettingsManager.requestPermission()
        
        if !granted {
            await MainActor.run {
                permissionAlertMessage = "To receive notifications, please enable them in Settings > Notifications > Pet Allergy Scanner."
                showingPermissionAlert = true
            }
        }
    }
    
    /**
     * Open app settings for notification permission
     */
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

/// Instruction step component for notification permissions view
struct InstructionStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
            Text(number)
                .font(ModernDesignSystem.Typography.bodyEmphasized)
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .frame(width: 24, height: 24)
                .background(ModernDesignSystem.Colors.primary.opacity(0.1))
                .clipShape(Circle())
            
            Text(text)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            
            Spacer()
        }
    }
}


/**
 * Help Center View
 * 
 * Uses the existing HelpSupportView with Trust & Nature Design System
 */
struct HelpCenterView: View {
    var body: some View {
        HelpSupportView()
    }
}


/// View for contact support
struct ContactSupportView: View {
    @State private var message = ""
    @State private var showingEmail = false
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Text("Contact Support")
                .font(ModernDesignSystem.Typography.title2)
            
            Text("Need help? We're here to assist you with any questions or issues.")
                .font(ModernDesignSystem.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            
            VStack(spacing: ModernDesignSystem.Spacing.md) {
                Button("Email Support") {
                    showingEmail = true
                }
                .modernButton(style: .primary)
            }
            
            Spacer()
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .navigationTitle("Contact Support")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEmail) {
            EmailSupportView()
        }
    }
}

/// View for email support
struct EmailSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var message = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Subject") {
                    TextField("Brief description of your issue", text: $subject)
                }
                
                Section("Message") {
                    TextField("Please describe your issue in detail...", text: $message, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Email Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendEmail()
                    }
                    .disabled(subject.isEmpty || message.isEmpty)
                }
            }
        }
    }
    
    private func sendEmail() {
        // Create mailto URL with subject and body
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailtoString = "mailto:support@snifftestapp.com?subject=\(encodedSubject)&body=\(encodedBody)"
        
        if let url = URL(string: mailtoString) {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
}

#Preview {
    ProfileSettingsView()
        .environmentObject(AuthService.shared)
}
