//
//  ContentView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var petService = PetService.shared
    @State private var hasCompletedOnboarding = false
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            } else {
                AuthenticationView()
            }
        }
        .environmentObject(authService)
        .environmentObject(petService)
        .onAppear {
            checkOnboardingStatus()
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                checkOnboardingStatus()
            } else {
                hasCompletedOnboarding = false
            }
        }
        .onChange(of: authService.currentUser?.onboarded) { _, onboarded in
            if let onboarded = onboarded {
                hasCompletedOnboarding = onboarded
                isLoading = false
            }
        }
    }
    
    /// Check if user has completed onboarding
    private func checkOnboardingStatus() {
        guard authService.isAuthenticated else {
            hasCompletedOnboarding = false
            isLoading = false
            return
        }
        
        // Check user's onboarded status from the server
        if let user = authService.currentUser {
            hasCompletedOnboarding = user.onboarded
            isLoading = false
        } else {
            // If user data is not loaded yet, wait for it
            isLoading = true
        }
    }
}

#Preview {
    ContentView()
}
