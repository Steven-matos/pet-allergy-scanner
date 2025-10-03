//
//  MainTabView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var petService = PetService.shared
    
    var body: some View {
        TabView {
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
            
            // Favorites Tab
            FavoritesView()
                .environmentObject(authService)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Favorites")
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
        .accentColor(ModernDesignSystem.Colors.tabBarActive)
        .background(ModernDesignSystem.Colors.tabBarBackground)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
}
