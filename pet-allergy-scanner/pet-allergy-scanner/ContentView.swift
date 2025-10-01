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
    @State private var hasSkippedOnboarding = false // Track if user skipped onboarding this session
    
    var body: some View {
        Group {
            switch authService.authState {
            case .initializing, .loading:
                // Show loading state while initializing or loading user data
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .authenticated(let user):
                // User is authenticated with complete data
                if user.onboarded || hasSkippedOnboarding {
                    MainTabView()
                        .onAppear {
                            // Load pets when entering main view
                            petService.loadPets()
                        }
                } else {
                    OnboardingView(onSkip: {
                        // Allow user to skip onboarding temporarily for this session
                        hasSkippedOnboarding = true
                    })
                }
                
            case .unauthenticated:
                // User is not authenticated
                AuthenticationView()
            }
        }
        .environmentObject(authService)
        .environmentObject(petService)
        .onChange(of: authService.authState) { _, newState in
            // Reset skip state when user logs out
            if case .unauthenticated = newState {
                hasSkippedOnboarding = false
            }
        }
    }
}

#Preview {
    ContentView()
}
