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
        // iOS 18.6.2 Fix: Use tint instead of accentColor for better compatibility
        .tint(ModernDesignSystem.Colors.tabBarActive)
        .onChange(of: selectedTab) { oldValue, newValue in
            navigationCoordinator.recordTabChange(fromTab: oldValue, toTab: newValue)
        }
        .task {
            // iOS 18.6.2 Fix: Use task instead of onAppear for async operations
            // This prevents blocking the main thread during tab initialization
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            await MainActor.run {
                CachedPetService.shared.loadPets()
            }
        }
        .onChange(of: notificationManager.navigateToScan) { oldValue, newValue in
            if newValue && !oldValue {
                selectedTab = 2 // Navigate to scan tab (now in middle position)
            }
        }
    }
}

