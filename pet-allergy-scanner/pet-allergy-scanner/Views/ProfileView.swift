//
//  ProfileView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var petService: PetService
    @State private var showingLogoutAlert = false
    @State private var showingEditProfile = false
    @State private var showingSubscription = false
    @State private var showingHelpSupport = false
    @State private var showingMFASetup = false
    @State private var showingGDPR = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // User Profile Header
                    VStack(spacing: 16) {
                        // Profile Picture or Default Icon
                        RemoteImageView(userImageUrl: authService.currentUser?.imageUrl)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(ModernDesignSystem.Colors.deepForestGreen, lineWidth: 3))
                            .onAppear {
                                print("🔍 ProfileView: User data - imageUrl: \(authService.currentUser?.imageUrl ?? "nil")")
                                print("🔍 ProfileView: Full user data: \(authService.currentUser?.description ?? "nil")")
                            }
                        
                        if let user = authService.currentUser {
                            Text("\(user.firstName ?? "") \(user.lastName ?? "")")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            
                            Text(user.role.displayName)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(user.role == .premium ? ModernDesignSystem.Colors.goldenYellow : ModernDesignSystem.Colors.lightGray)
                                .foregroundColor(user.role == .premium ? ModernDesignSystem.Colors.textOnAccent : ModernDesignSystem.Colors.textPrimary)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.top, 40)
                
                // Profile Options
                VStack(spacing: 16) {
                    ProfileOptionRow(
                        icon: "person.circle",
                        title: LocalizationKeys.editProfile.localized,
                        action: { 
                            HapticFeedback.light()
                            showingEditProfile = true
                        }
                    )
                    
                    ProfileOptionRow(
                        icon: "creditcard",
                        title: LocalizationKeys.subscription.localized,
                        action: { 
                            HapticFeedback.light()
                            showingSubscription = true
                        }
                    )
                    
                    ProfileOptionRow(
                        icon: "questionmark.circle",
                        title: LocalizationKeys.helpSupport.localized,
                        action: { 
                            HapticFeedback.light()
                            showingHelpSupport = true
                        }
                    )
                    
                    ProfileOptionRow(
                        icon: "shield.checkered",
                        title: "Security & MFA",
                        action: { 
                            HapticFeedback.light()
                            showingMFASetup = true
                        }
                    )
                    
                    ProfileOptionRow(
                        icon: "hand.raised.fill",
                        title: "Privacy & Data",
                        action: { 
                            HapticFeedback.light()
                            showingGDPR = true
                        }
                    )
                    
                    ProfileOptionRow(
                        icon: "gear",
                        title: LocalizationKeys.settings.localized,
                        action: { 
                            HapticFeedback.light()
                            showingSettings = true
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Logout Button
                Button(action: {
                    showingLogoutAlert = true
                }) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(LocalizationKeys.signOut.localized)
                            .font(.headline)
                            .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ModernDesignSystem.Colors.warmCoral.opacity(0.1))
                    .cornerRadius(10)
                }
                .disabled(authService.isLoading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Debug Section (only in development)
                #if DEBUG
                VStack(spacing: 12) {
                    Text("Debug Options")
                        .font(.headline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    
                    Button("Reset Onboarding") {
                        petService.resetOnboarding()
                    }
                    .font(.caption)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ModernDesignSystem.Colors.lightGray.opacity(0.3))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
                #endif
                }
            }
            .navigationTitle(LocalizationKeys.profile.localized)
            .alert(LocalizationKeys.signOut.localized, isPresented: $showingLogoutAlert) {
                Button(LocalizationKeys.cancel.localized, role: .cancel) { }
                Button(LocalizationKeys.signOut.localized, role: .destructive) {
                    authService.logout()
                }
            } message: {
                Text(LocalizationKeys.signOutConfirmation.localized)
            }
            .alert(LocalizationKeys.error.localized, isPresented: .constant(authService.errorMessage != nil)) {
                Button(LocalizationKeys.ok.localized) {
                    authService.clearError()
                }
            } message: {
                Text(authService.errorMessage ?? LocalizationKeys.error.localized)
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
                    .environmentObject(authService)
            }
            .sheet(isPresented: $showingHelpSupport) {
                HelpSupportView()
            }
            .sheet(isPresented: $showingMFASetup) {
                MFASetupView()
                    .environmentObject(MFAService.shared)
            }
            .sheet(isPresented: $showingGDPR) {
                GDPRView()
                    .environmentObject(GDPRService.shared)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
    
}

struct ProfileOptionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                    .frame(width: 24)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding()
            .background(ModernDesignSystem.Colors.surfaceVariant)
            .cornerRadius(10)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthService.shared)
}

#Preview("With Mock Data") {
    let mockAuthService = AuthService.shared
    // Note: In a real preview, you would set up mock data differently
    // This is just for demonstration - the actual setup would be done
    // in the preview's setup code or through a different mechanism
    
    ProfileView()
        .environmentObject(mockAuthService)
}
