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
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Scan")
                }
            
            // Pets Tab
            PetsView()
                .tabItem {
                    Image(systemName: "pawprint")
                    Text("Pets")
                }
            
            // History Tab
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
            
            // Favorites Tab
            FavoritesView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Favorites")
                }
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
        }
        .environmentObject(petService)
        .onAppear {
            petService.loadPets()
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
}
