//
//  ProfileView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationStack {
                    VStack(spacing: 20) {
                // User Profile Header
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                    
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
                
                Spacer()
                
                // Profile Options
                VStack(spacing: 16) {
                    ProfileOptionRow(
                        icon: "person.circle",
                        title: LocalizationKeys.editProfile.localized,
                        action: {
                            // TODO: Implement edit profile
                        }
                    )
                    
                    ProfileOptionRow(
                        icon: "creditcard",
                        title: LocalizationKeys.subscription.localized,
                        action: {
                            // TODO: Implement subscription management
                        }
                    )
                    
                    ProfileOptionRow(
                        icon: "questionmark.circle",
                        title: LocalizationKeys.helpSupport.localized,
                        action: {
                            // TODO: Implement help & support
                        }
                    )
                    
                    ProfileOptionRow(
                        icon: "shield.checkered",
                        title: "Security & MFA",
                        action: {
                            // TODO: Navigate to MFA setup
                        }
                    )
                    
                    ProfileOptionRow(
                        icon: "hand.raised.fill",
                        title: "Privacy & Data",
                        action: {
                            // TODO: Navigate to GDPR view
                        }
                    )
                    
                    ProfileOptionRow(
                        icon: "gear",
                        title: LocalizationKeys.settings.localized,
                        action: {
                            // TODO: Implement settings
                        }
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
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
                .padding(.bottom, 20)
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
    mockAuthService.currentUser = MockData.mockUser
    mockAuthService.isAuthenticated = true

    return ProfileView()
        .environmentObject(mockAuthService)
}
