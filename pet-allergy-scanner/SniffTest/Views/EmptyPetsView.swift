//
//  EmptyPetsView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/// View displayed when user has no pets added
struct EmptyPetsView: View {
    let onAddPet: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Empty State Icon
            Image(systemName: "pawprint.circle")
                .font(.system(size: 80))
                .foregroundColor(ModernDesignSystem.Colors.deepForestGreen.opacity(0.4))
            
            // Empty State Text
            VStack(spacing: 12) {
                Text("No Pets Added")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                
                Text("Add your pet's profile to start scanning ingredient labels for allergies and safety.")
                    .font(.body)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Add Pet Button
            Button(action: onAddPet) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Your First Pet")
                }
                .font(.headline)
                .foregroundColor(ModernDesignSystem.Colors.textOnAccent)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(ModernDesignSystem.Colors.goldenYellow)
                .cornerRadius(25)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    EmptyPetsView {
        print("Add pet tapped")
    }
}

#Preview("Dark Mode") {
    EmptyPetsView {
        print("Add pet tapped")
    }
    .preferredColorScheme(.dark)
}
