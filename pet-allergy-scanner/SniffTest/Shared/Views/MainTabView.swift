//
//  MainTabView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var petService = CachedPetService.shared
    @State private var selectedTab = 2
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Pets Tab
            PetsView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: "pawprint")
                    Text("Pets")
                }
                .tag(0)
            
            // Trackers Tab (Replaces History)
            TrackersView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Trackers")
                }
                .tag(1)
            
            // Scan Tab (Middle position)
            ScanView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Scan")
                }
                .tag(2)
            
            // Nutrition Tab
            AdvancedNutritionView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: "leaf.fill")
                    Text("Nutrition")
                }
                .tag(3)
            
            // Profile & Settings Tab
            ProfileSettingsView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(4)
        }
        .onChange(of: selectedTab) { _, newValue in
            // Track navigation performance between tabs
            let tabNames = ["Pets", "Trackers", "Scan", "Nutrition", "Profile"]
            let fromTab = selectedTab < tabNames.count ? tabNames[selectedTab] : "Unknown"
            let toTab = newValue < tabNames.count ? tabNames[newValue] : "Unknown"
            
            let navigationStart = Date()
            Task(priority: .utility) { @MainActor in
                // Wait a moment to see if navigation completes
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                let duration = Date().timeIntervalSince(navigationStart)
                
                // Track navigation - flag slow navigations (>1s) or between Profile/Nutrition
                let isSlowNavigation = duration > 1.0
                let isProblematicNavigation = (fromTab == "Profile" && toTab == "Nutrition") || 
                                             (fromTab == "Nutrition" && toTab == "Profile")
                
                if isSlowNavigation || isProblematicNavigation {
                    PostHogAnalytics.trackNavigation(
                        fromView: fromTab,
                        toView: toTab,
                        duration: duration,
                        success: duration < 5.0 // Consider >5s as failure
                    )
                }
            }
        }
        .onAppear {
            // Load pets asynchronously to prevent blocking tab navigation
            Task.detached(priority: .utility) { @MainActor in
                petService.loadPets()
            }
        }
        .onChange(of: notificationManager.navigateToScan) { oldValue, newValue in
            if newValue && !oldValue {
                selectedTab = 2 // Navigate to scan tab (now in middle position)
            }
        }
        .accentColor(ModernDesignSystem.Colors.tabBarActive)
        .background(ModernDesignSystem.Colors.tabBarBackground)
    }
}

