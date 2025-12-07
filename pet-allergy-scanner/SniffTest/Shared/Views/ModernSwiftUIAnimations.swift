//
//  ModernSwiftUIAnimations.swift
//  SniffTest
//
//  Created by Steven Matos on 1/28/25.
//

import SwiftUI

/**
 * Modern SwiftUI Animations - SwiftUI 5.0 Features
 * 
 * Implements latest SwiftUI 5.0 animation features:
 * - PhaseAnimator for complex multi-phase animations
 * - KeyframeAnimator for precise keyframe control
 * - Modern animation modifiers and transitions
 * - Performance-optimized animation patterns
 * 
 * Follows SOLID principles with single responsibility for animations
 * Implements DRY by providing reusable animation components
 * Follows KISS by keeping animations simple and performant
 */

// MARK: - Modern Loading Animation

/**
 * Modern loading animation using PhaseAnimator (SwiftUI 5.0)
 * Provides smooth, multi-phase loading animations with multiple animated dots
 * Clearly indicates the app is actively loading and not frozen
 */
struct ModernLoadingAnimation: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.sm) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(ModernDesignSystem.Colors.primary)
                    .frame(width: 12, height: 12)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Modern Card Animation

/**
 * Modern card animation using KeyframeAnimator (SwiftUI 5.0)
 * Provides precise control over card appearance animations
 */
struct ModernCardAnimation: ViewModifier {
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: CardAnimationState(), trigger: isVisible) { content, value in
                content
                    .scaleEffect(value.scale)
                    .opacity(value.opacity)
                    .offset(y: value.offsetY)
                    .rotationEffect(.degrees(value.rotation))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    LinearKeyframe(0.8, duration: 0.1)
                    SpringKeyframe(1.0, duration: 0.3)
                }
                
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.0, duration: 0.1)
                    LinearKeyframe(1.0, duration: 0.2)
                }
                
                KeyframeTrack(\.offsetY) {
                    LinearKeyframe(50, duration: 0.1)
                    SpringKeyframe(0, duration: 0.3)
                }
                
                KeyframeTrack(\.rotation) {
                    LinearKeyframe(5, duration: 0.1)
                    SpringKeyframe(0, duration: 0.3)
                }
            }
            .onAppear {
                isVisible = true
            }
    }
}

// MARK: - Animation State Models

private struct CardAnimationState {
    var scale: Double = 0.8
    var opacity: Double = 0.0
    var offsetY: Double = 50
    var rotation: Double = 5
}

// MARK: - Modern Transition Animations

/**
 * Modern transition animations using SwiftUI 5.0 features
 * Provides smooth, performant transitions between views
 */
struct ModernTransitionModifier: ViewModifier {
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8)
                    .combined(with: .opacity)
                    .combined(with: .offset(y: 20)),
                removal: .scale(scale: 0.8)
                    .combined(with: .opacity)
                    .combined(with: .offset(y: -20))
            ))
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
    }
}

// MARK: - Modern Scroll Animations

/**
 * Modern scroll animations using SwiftUI 5.0 scrollPosition
 * Provides smooth, performant scrolling with animations
 */
@available(iOS 18.0, *)
struct ModernScrollView<Content: View>: View {
    let content: Content
    @State private var scrollPosition: ScrollPosition = ScrollPosition()
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ScrollView {
            content
        }
        .scrollPosition($scrollPosition)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .animation(.smooth, value: scrollPosition)
    }
}

// MARK: - Modern Button Animations

/**
 * Modern button animations using SwiftUI 5.0 features
 * Provides tactile, responsive button interactions
 */
struct ModernButtonAnimation: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

// MARK: - View Extensions

extension View {
    /// Apply modern card animation
    func modernCardAnimation() -> some View {
        self.modifier(ModernCardAnimation())
    }
    
    /// Apply modern transition animation
    func modernTransition(isVisible: Bool) -> some View {
        self.modifier(ModernTransitionModifier(isVisible: isVisible))
    }
    
    /// Apply modern button animation
    func modernButtonAnimation() -> some View {
        self.modifier(ModernButtonAnimation())
    }
}

// MARK: - Modern Loading View

/**
 * Modern loading view using latest SwiftUI 5.0 features
 * Provides smooth, animated loading states with clear visual feedback
 * Includes animated dots and pulsing text to indicate active loading
 */
struct ModernLoadingView: View {
    let message: String
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            // Animated loading indicator with multiple dots
            ModernLoadingAnimation()
                .padding(.bottom, ModernDesignSystem.Spacing.md)
            
            // Pulsing message text
            Text(message)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .opacity(isAnimating ? 1.0 : 0.0)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                    value: pulseScale
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ModernDesignSystem.Colors.background)
        .onAppear {
            isAnimating = true
            pulseScale = 1.05
        }
    }
}

// MARK: - Modern Progress View

/**
 * Modern progress view using SwiftUI 5.0 features
 * Provides smooth, animated progress indicators
 */
struct ModernProgressView: View {
    let progress: Double
    let message: String
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .tint(ModernDesignSystem.Colors.primary)
                .scaleEffect(y: 2.0)
            
            Text(message)
                .font(ModernDesignSystem.Typography.caption)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.surface)
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(color: ModernDesignSystem.Colors.textSecondary.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Modern Animation Loading View

/**
 * Modern animation loading view to avoid conflicts
 * Provides smooth, animated loading states for animation operations
 */
struct ModernAnimationLoadingView: View {
    let message: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: ModernDesignSystem.Spacing.lg) {
            ModernLoadingAnimation()
            
            Text(message)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.5).delay(0.2), value: isAnimating)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ModernDesignSystem.Colors.background)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview("Modern Loading Animation") {
    ModernLoadingAnimation()
        .frame(width: 100, height: 100)
        .background(Color.gray.opacity(0.1))
}

#Preview("Modern Animation Loading View") {
    ModernAnimationLoadingView(message: "Loading pets...")
}

#Preview("Modern Progress View") {
    ModernProgressView(progress: 0.7, message: "Syncing data...")
}

#Preview("Modern Card Animation") {
    VStack {
        Text("Hello World")
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .modernCardAnimation()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.1))
}
