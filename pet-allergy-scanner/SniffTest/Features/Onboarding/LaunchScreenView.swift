import SwiftUI

/// Launch screen with Trust & Nature design system
/// Displays app branding with smooth animation during app startup
struct LaunchScreenView: View {
    @State private var isAnimating = false
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background - Soft Cream
            ModernDesignSystem.Colors.softCream
                .ignoresSafeArea()
            
            VStack(spacing: ModernDesignSystem.Spacing.xl) {
                Spacer()
                
                // App Icon with animation
                ZStack {
                    // Subtle background circle
                    Circle()
                        .fill(ModernDesignSystem.Colors.primary.opacity(0.1))
                        .frame(width: 180, height: 180)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    // App Icon
                    Image("Branding/app-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .cornerRadius(ModernDesignSystem.CornerRadius.extraLarge)
                        .shadow(
                            color: ModernDesignSystem.Shadows.medium.color,
                            radius: ModernDesignSystem.Shadows.medium.radius,
                            x: ModernDesignSystem.Shadows.medium.x,
                            y: ModernDesignSystem.Shadows.medium.y
                        )
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(opacity)
                }
                
                // App Name
                VStack(spacing: ModernDesignSystem.Spacing.sm) {
                    Text("SniffTest")
                        .font(ModernDesignSystem.Typography.largeTitle)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .opacity(opacity)
                    
                    Text("Sniff Out What's Safe")
                        .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .opacity(opacity)
                }
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: ModernDesignSystem.Spacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ModernDesignSystem.Colors.primary))
                        .scaleEffect(1.2)
                        .opacity(opacity)
                    
                    Text("Loading your pets...")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .opacity(opacity)
                }
                .padding(.bottom, ModernDesignSystem.Spacing.xxl)
            }
        }
        .onAppear {
            // Start animations
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1.0
            }
            
            withAnimation(.easeInOut(duration: 0.8).delay(0.2)) {
                isAnimating = true
            }
        }
    }
}

/// Static launch screen for Info.plist configuration
/// Displayed immediately when app launches before SwiftUI loads
struct StaticLaunchScreen: View {
    var body: some View {
        ZStack {
            // Background - Soft Cream
            Color(hex: "#F8F6F0")
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // App Icon
                Image("Branding/app-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .cornerRadius(24)
                
                // App Name
                VStack(spacing: 8) {
                    Text("SniffTest")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundColor(Color(hex: "#2C3E50"))
                    
                    Text("Sniff Out What's Safe")
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundColor(Color(hex: "#BDC3C7"))
                }
            }
        }
    }
}

#Preview {
    LaunchScreenView()
}

#Preview("Static Launch Screen") {
    StaticLaunchScreen()
}

