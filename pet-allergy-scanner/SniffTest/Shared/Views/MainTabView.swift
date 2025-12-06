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
    @ObservedObject private var navigationCoordinator = TabNavigationCoordinator.shared
    
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
        .onChange(of: selectedTab) { oldValue, newValue in
            // Record tab change in coordinator for cooldown management
            navigationCoordinator.recordTabChange(fromTab: oldValue, toTab: newValue)
        }
        .onAppear {
            // Load pets asynchronously to prevent blocking tab navigation
            Task { @MainActor in
                // Small delay to prevent blocking
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                CachedPetService.shared.loadPets()
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

