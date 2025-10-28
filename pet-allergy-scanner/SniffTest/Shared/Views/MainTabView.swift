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
    @State private var selectedTab = 2 {
        didSet {
            print("🔍 MainTabView: selectedTab changed from \(oldValue) to \(selectedTab)")
            // Add stack trace to see what's causing the change
            print("🔍 MainTabView: Stack trace: \(Thread.callStackSymbols.prefix(5))")
        }
    }
    
    var body: some View {
        let _ = print("🔍 MainTabView: body called with selectedTab = \(selectedTab)")
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
        .onAppear {
            petService.loadPets()
        }
        .onChange(of: notificationManager.navigateToScan) { oldValue, newValue in
            print("🔍 MainTabView: navigateToScan changed from \(oldValue) to \(newValue)")
            if newValue && !oldValue {
                print("🔍 MainTabView: Navigating to scan tab (selectedTab = 2)")
                selectedTab = 2 // Navigate to scan tab (now in middle position)
            }
        }
        .accentColor(ModernDesignSystem.Colors.tabBarActive)
        .background(ModernDesignSystem.Colors.tabBarBackground)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
}
