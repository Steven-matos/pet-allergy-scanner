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
    @StateObject private var petService = PetService.shared
    @State private var selectedTab = 0 {
        didSet {
            print("🔍 MainTabView: selectedTab changed from \(oldValue) to \(selectedTab)")
            // Add stack trace to see what's causing the change
            print("🔍 MainTabView: Stack trace: \(Thread.callStackSymbols.prefix(5))")
        }
    }
    
    var body: some View {
        let _ = print("🔍 MainTabView: body called with selectedTab = \(selectedTab)")
        TabView(selection: $selectedTab) {
            // Home/Scan Tab
            ScanView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Scan")
                }
            
            // Pets Tab
            PetsView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: "pawprint")
                    Text("Pets")
                }
            
            // History Tab
            HistoryView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
            
            // Nutrition Tab
                        AdvancedNutritionView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: "leaf.fill")
                    Text("Nutrition")
                }
            
            // Profile & Settings Tab
            ProfileSettingsView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
        }
        .environmentObject(petService)
        .onAppear {
            petService.loadPets()
        }
        // Temporarily disabled to test navigation issue
        // .onChange(of: notificationManager.navigateToScan) { oldValue, newValue in
        //     print("🔍 MainTabView: navigateToScan changed from \(oldValue) to \(newValue)")
        //     if newValue && !oldValue {
        //         print("🔍 MainTabView: Navigating to scan tab (selectedTab = 0)")
        //         selectedTab = 0 // Navigate to scan tab
        //     }
        // }
        .accentColor(ModernDesignSystem.Colors.tabBarActive)
        .background(ModernDesignSystem.Colors.tabBarBackground)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
}
