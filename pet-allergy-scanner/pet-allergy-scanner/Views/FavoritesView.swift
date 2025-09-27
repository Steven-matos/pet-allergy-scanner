//
//  FavoritesView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

struct FavoritesView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("Favorites Coming Soon")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Save your approved pet foods for quick access")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Favorites")
        }
    }
}

#Preview {
    FavoritesView()
}
