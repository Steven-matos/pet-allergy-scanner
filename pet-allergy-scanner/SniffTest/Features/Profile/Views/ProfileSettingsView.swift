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
    
    // MARK: - Service Dependencies
    @EnvironmentObject var authService: AuthService
    @State private var petService = CachedPetService.shared
    @StateObject private var gdprService = GDPRService.shared
    @StateObject private var analyticsManager = AnalyticsManager.shared
    @StateObject private var notificationSettingsManager = NotificationSettingsManager.shared
    @StateObject private var weightUnitService = WeightUnitPreferenceService.shared
    @StateObject private var profileService = CachedProfileService.shared
    
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
                        
                        // App Settings
                        appSettingsCard
                        
                        // Support & About
                        supportAboutCard
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
                calculateCacheSize()
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
                Button("Clear", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("This will clear all cached data including images and temporary files.")
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
                
                Divider()
                    .background(ModernDesignSystem.Colors.borderPrimary)
                
                // Sign Out
                Button(action: { showingSignOutAlert = true }) {
                    HStack {
                        Image(systemName: "arrow.right.square")
                            .foregroundColor(ModernDesignSystem.Colors.error)
                        Text("Sign Out")
                            .font(ModernDesignSystem.Typography.body)
                            .foregroundColor(ModernDesignSystem.Colors.error)
                        Spacer()
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
                // Default Pet Selection
                if !petService.pets.isEmpty {
                    VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                        Text("Default Pet for Scans")
                            .font(ModernDesignSystem.Typography.caption)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        
                        Picker("Default Pet for Scans", selection: $settingsManager.defaultPetId) {
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
                
                // Scan Preferences Section
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text("Scan Preferences")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        // Camera Quality
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Image Quality")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            
                            Picker("Image Quality", selection: $settingsManager.cameraResolution) {
                                Text("Low (Faster)").tag("low")
                                Text("Medium (Balanced)").tag("medium")
                                Text("High (Best)").tag("high")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .accentColor(ModernDesignSystem.Colors.primary)
                        }
                        
                        Divider()
                            .background(ModernDesignSystem.Colors.borderPrimary)
                        
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
                // Master Notification Toggle
                HStack {
                    Text("Push Notifications")
                        .font(ModernDesignSystem.Typography.body)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $notificationSettingsManager.enableNotifications)
                        .tint(ModernDesignSystem.Colors.primary)
                        .onChange(of: notificationSettingsManager.enableNotifications) { _, newValue in
                            if newValue {
                                Task {
                                    await notificationSettingsManager.requestPermission()
                                }
                            }
                        }
                }
                .padding(.vertical, ModernDesignSystem.Spacing.sm)
                
                // Engagement Notifications - only show when notifications are enabled
                if notificationSettingsManager.enableNotifications {
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
                                Image(systemName: "externaldrive")
                                    .foregroundColor(ModernDesignSystem.Colors.primary)
                                Text("Clear Cache")
                                    .font(ModernDesignSystem.Typography.body)
                                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                Spacer()
                                Text(cacheSize)
                                    .font(ModernDesignSystem.Typography.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            }
                            .padding(.vertical, ModernDesignSystem.Spacing.sm)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
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
    
    // MARK: - App Settings Card
    private var appSettingsCard: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            // Card Header
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .font(ModernDesignSystem.Typography.title3)
                
                Text("App Settings")
                    .font(ModernDesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
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
                        
                        // Build Number
                        HStack {
                            Text("Build")
                                .font(ModernDesignSystem.Typography.body)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            Spacer()
                            Text(Bundle.main.buildNumber)
                                .font(ModernDesignSystem.Typography.body)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
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
    
    // MARK: - Helper Methods
    
    /// Calculate total cache size asynchronously to avoid blocking main thread
    private func calculateCacheSize() {
        Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            
            guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return
            }
            
            var totalSize: Int64 = 0
            
            // Recursively calculate directory size to include subdirectories
            func calculateDirectorySize(at url: URL) -> Int64 {
                var size: Int64 = 0
                
                do {
                    let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles])
                    
                    for fileURL in contents {
                        let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                        
                        if let isDirectory = resourceValues?.isDirectory, isDirectory {
                            // Recursively calculate subdirectory size
                            size += calculateDirectorySize(at: fileURL)
                        } else if let fileSize = resourceValues?.fileSize {
                            size += Int64(fileSize)
                        }
                    }
                } catch {
                    print("Failed to read directory \(url.path): \(error)")
                }
                
                return size
            }
            
            totalSize = calculateDirectorySize(at: cachesURL)
            let sizeInMB = Double(totalSize) / 1024.0 / 1024.0
            
            await MainActor.run {
                cacheSize = String(format: "%.2f MB", sizeInMB)
            }
        }
    }
    
    /// Clear all cached data asynchronously to avoid blocking main thread
    private func clearCache() {
        Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            
            guard let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                return
            }
            
            do {
                let cacheFiles = try fileManager.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil)
                
                for file in cacheFiles {
                    try fileManager.removeItem(at: file)
                }
                
                await MainActor.run {
                    HapticFeedback.success()
                    calculateCacheSize()
                }
            } catch {
                print("Failed to clear cache: \(error)")
                await MainActor.run {
                    HapticFeedback.error()
                }
            }
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
