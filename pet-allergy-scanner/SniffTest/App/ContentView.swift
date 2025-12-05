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
    @StateObject private var orientationManager = OrientationManager()
    @Environment(\.scenePhase) private var scenePhase
    
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
                            // Track analytics (safe - onAppear is on MainActor)
                            Task { @MainActor in
                                PostHogAnalytics.trackScreenViewed(screenName: "main_tab_view")
                            }
                            
                            // CRITICAL: Load all critical cached data synchronously on app launch
                            // This ensures no data flashing - data appears instantly if cached
                            loadCriticalCachedDataSynchronously()
                            
                            // Initialize notifications
                            notificationManager.initializeNotifications()
                            
                            // Initialize push notifications (non-blocking)
                            Task {
                                await PushNotificationService.shared.requestPushNotificationPermission()
                            }
                            
                            // Background cache sync to refresh stale data (non-blocking)
                            Task.detached(priority: .background) {
                                await CacheServerSyncService.shared.syncOnAppLaunch()
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
        .environmentObject(orientationManager)
          .onChange(of: scenePhase) { _, newPhase in
              SessionLifecycleManager.shared.handleScenePhase(newPhase)
              
              // Track app lifecycle events (safe - onChange is on MainActor)
              Task { @MainActor in
                  switch newPhase {
                  case .active:
                      PostHogAnalytics.trackScreenViewed(screenName: "app_became_active")
                  case .background:
                      PostHogAnalytics.trackScreenViewed(screenName: "app_entered_background")
                  case .inactive:
                      PostHogAnalytics.trackScreenViewed(screenName: "app_became_inactive")
                  @unknown default:
                      break
                  }
              }
              
              if newPhase == .active {
                  notificationManager.handleAppBecameActive()
                  // Load critical cached data synchronously when app becomes active
                  loadCriticalCachedDataSynchronously()
              }
          }
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
                            .frame(maxWidth: orientationManager.isLandscape ? 400 : 300)
                    }
            }
        }
    }
    
    // MARK: - Cache Loading Methods
    
    /**
     * Load all critical cached data synchronously on app launch
     * This ensures no data flashing - data appears instantly if cached
     * 
     * Critical data includes:
     * - User profile
     * - Pets (foundation for all other data)
     * - First pet's weight, nutrition, and trends data (if available)
     * 
     * Follows cache-first pattern:
     * 1. Loads from cache synchronously (immediate UI)
     * 2. Triggers background refresh for stale data (non-blocking)
     */
    private func loadCriticalCachedDataSynchronously() {
        guard authService.currentUser != nil else { return }
        
        // 1. Load pets synchronously from cache (foundation for all other data)
        petService.loadPets(forceRefresh: false)
        
        // 2. Load user profile synchronously from cache
        Task { @MainActor in
            _ = try? await CachedProfileService.shared.getCurrentUser()
            _ = try? await CachedProfileService.shared.getUserProfile()
        }
        
        // 3. If we have pets, load critical data for the first pet synchronously
        if let firstPet = petService.pets.first {
            // Load cached data synchronously (checks cache, doesn't block)
            let weightService = CachedWeightTrackingService.shared
            let nutritionService = CachedNutritionService.shared
            let trendsService = CachedNutritionalTrendsService.shared
            
            // These calls check cache synchronously and return immediately if cached
            _ = weightService.hasCachedWeightData(for: firstPet.id)
            _ = nutritionService.hasCachedNutritionData(for: firstPet.id)
            _ = trendsService.hasCachedTrendsData(for: firstPet.id)
            
            // Trigger background warming for all pets (non-blocking)
            Task.detached(priority: .background) {
                await CacheHydrationService.shared.warmCachesInBackground()
            }
        }
    }
}

#Preview {
    ContentView()
}
