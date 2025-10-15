//
//  ContentView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var petService = PetService.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var hasSkippedOnboarding = false // Track if user skipped onboarding this session
    
    var body: some View {
        Group {
            switch authService.authState {
            case .initializing, .loading:
                // Show custom launch screen while initializing or loading user data
                LaunchScreenView()
                
            case .authenticated(let user):
                // User is authenticated with complete data
                if user.onboarded || hasSkippedOnboarding {
                    MainTabView()
                        .onAppear {
                            // Load pets when entering main view
                            petService.loadPets()
                            // Initialize notifications
                            notificationManager.initializeNotifications()
                            // Initialize push notifications
                            Task {
                                await PushNotificationService.shared.requestPushNotificationPermission()
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            // Handle app becoming active
                            notificationManager.handleAppBecameActive()
                            
                            // Refresh user session to ensure token is valid
                            Task {
                                await authService.refreshCurrentUser()
                            }
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
        .environmentObject(notificationManager)
        .onChange(of: authService.authState) { _, newState in
            // Reset skip state when user logs out
            if case .unauthenticated = newState {
                hasSkippedOnboarding = false
            }
        }
        .sheet(isPresented: $notificationManager.showBirthdayCelebration) {
            if let pet = notificationManager.birthdayPet {
                BirthdayCelebrationView(pet: pet, isPresented: $notificationManager.showBirthdayCelebration)
            }
        }
    }
}

#Preview {
    ContentView()
}
