//
//  BirthdayCelebrationView.swift
//  SniffTest
//
//  Created by Steven Matos on 9/26/25.
//

import SwiftUI

/// Birthday celebration popup view with pet image and confetti animation
/// Shows when a pet's birthday is detected or notification is tapped
struct BirthdayCelebrationView: View {
    let pet: Pet
    @Binding var isPresented: Bool
    @State private var showConfetti = false
    @State private var confettiOffset: CGFloat = -100
    @State private var petImageScale: CGFloat = 0.8
    @State private var petImageOpacity: Double = 0
    @State private var textOffset: CGFloat = 50
    @State private var textOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissCelebration()
                }
            
            // Main celebration card
            VStack(spacing: 24) {
                // Pet image with celebration frame
                petImageView
                
                // Birthday message
                birthdayMessageView
                
                // Action buttons
                actionButtonsView
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 24)
            .scaleEffect(isPresented ? 1.0 : 0.8)
            .opacity(isPresented ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isPresented)
            
            // Confetti animation
            if showConfetti {
                confettiView
            }
        }
        .onAppear {
            startCelebrationAnimation()
            // Mark this birthday celebration as shown for this year
            NotificationSettingsManager.shared.markBirthdayCelebrationShown(for: pet.id)
        }
    }
    
    // MARK: - Pet Image View
    
    private var petImageView: some View {
        ZStack {
            // Celebration frame
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.yellow, .orange, .pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 160, height: 160)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 4)
                )
                .shadow(color: .yellow.opacity(0.5), radius: 10, x: 0, y: 0)
            
            // Pet image
            AsyncImage(url: URL(string: pet.imageUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                // Default pet icon based on species
                Image(systemName: pet.species.icon)
                    .font(.system(size: 60))
                    .foregroundColor(.white)
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.white, lineWidth: 3)
            )
            .scaleEffect(petImageScale)
            .opacity(petImageOpacity)
        }
    }
    
    // MARK: - Birthday Message View
    
    private var birthdayMessageView: some View {
        VStack(spacing: 12) {
            // Birthday emoji and title
            HStack(spacing: 8) {
                Text("🎉")
                    .font(.system(size: 32))
                    .scaleEffect(showConfetti ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: showConfetti)
                
                Text("Happy Birthday Month!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .offset(y: textOffset)
            .opacity(textOpacity)
            
            // Pet name
            Text(pet.name)
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundColor(.primary)
                .offset(y: textOffset)
                .opacity(textOpacity)
            
            // Age information
            if let ageDescription = pet.ageDescription {
                Text("Today \(pet.name) turns \(ageDescription)!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .offset(y: textOffset)
                    .opacity(textOpacity)
            }
            
            // Celebration message
            Text("🎂 Wishing your furry friend a wonderful day! 🐾")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .offset(y: textOffset)
                .opacity(textOpacity)
        }
    }
    
    // MARK: - Action Buttons View
    
    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            // Share button
            Button(action: shareBirthday) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.blue)
                )
            }
            
            // Close button
            Button(action: dismissCelebration) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                    Text("Close")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.primary.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .offset(y: textOffset)
        .opacity(textOpacity)
    }
    
    // MARK: - Confetti View
    
    private var confettiView: some View {
        ZStack {
            ForEach(0..<50, id: \.self) { index in
                Circle()
                    .fill(confettiColor(for: index))
                    .frame(width: confettiSize(for: index), height: confettiSize(for: index))
                    .offset(
                        x: confettiOffset + CGFloat.random(in: -200...200),
                        y: CGFloat.random(in: -100...100)
                    )
                    .opacity(confettiOpacity(for: index))
                    .animation(
                        .easeOut(duration: Double.random(in: 2...4))
                        .delay(Double.random(in: 0...1)),
                        value: confettiOffset
                    )
            }
        }
    }
    
    // MARK: - Animation Methods
    
    private func startCelebrationAnimation() {
        // Start confetti animation
        withAnimation(.easeOut(duration: 0.5)) {
            showConfetti = true
            confettiOffset = 1000
        }
        
        // Animate pet image
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
            petImageScale = 1.0
            petImageOpacity = 1.0
        }
        
        // Animate text elements
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
            textOffset = 0
            textOpacity = 1.0
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    private func dismissCelebration() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPresented = false
        }
    }
    
    // MARK: - Helper Methods
    
    private func shareBirthday() {
        let shareText = "🎉 Today is \(pet.name)'s birthday! 🐾 Wishing my furry friend a wonderful day! #PetBirthday #PetAllergyScanner"
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
    
    private func confettiColor(for index: Int) -> Color {
        let colors: [Color] = [.yellow, .orange, .pink, .purple, .blue, .green, .red]
        return colors[index % colors.count]
    }
    
    private func confettiSize(for index: Int) -> CGFloat {
        return CGFloat.random(in: 4...12)
    }
    
    private func confettiOpacity(for index: Int) -> Double {
        return Double.random(in: 0.6...1.0)
    }
}

// MARK: - Preview

struct BirthdayCelebrationView_Previews: PreviewProvider {
    static var previews: some View {
        BirthdayCelebrationView(
            pet: Pet(
                id: "1",
                userId: "user1",
                name: "Buddy",
                species: .dog,
                breed: "Golden Retriever",
                birthday: Calendar.current.date(byAdding: .year, value: -2, to: Date()),
                weightKg: 25.0,
                activityLevel: .moderate,
                imageUrl: nil,
                knownSensitivities: [],
                vetName: "Dr. Smith",
                vetPhone: "555-0123",
                createdAt: Date(),
                updatedAt: Date()
            ),
            isPresented: .constant(true)
        )
    }
}
