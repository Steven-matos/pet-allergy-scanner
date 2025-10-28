//
//  ContentView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct ContentView: View {
    // MEMORY OPTIMIZATION: Use shared service instances instead of @StateObject
    @EnvironmentObject var authService: AuthService
    @State private var petService = CachedPetService.shared
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var hydrationService = CacheHydrationService.shared
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
                            
                            // Refresh token if needed and validate session
                            Task {
                                // Check if token needs refresh and refresh if necessary
                                await APIService.shared.ensureValidToken()
                                
                                // Refresh user data to ensure session is valid
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
        .dismissKeyboardOnTap()
        .environmentObject(authService)
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
        .overlay {
            // Show cache hydration progress if hydrating
            if hydrationService.isHydrating {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        CacheHydrationProgressView()
                            .frame(maxWidth: 300)
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
