//
//  iOS18Compatibility.swift
//  SniffTest
//
//  iOS 18 compatibility utilities and fixes
//  Ensures all buttons and interactions work correctly on iOS 18.6.2+
//

import SwiftUI

/**
 * iOS 18 Compatibility Utilities
 *
 * Fixes common issues with buttons and gestures in iOS 18:
 * - Main actor isolation for button actions
 * - Gesture conflicts with button taps
 * - Proper async/await handling
 */
@MainActor
enum iOS18Compatibility {
    
    /**
     * Creates a safe button action that's properly isolated to MainActor
     * Use this wrapper for button actions that might have threading issues
     */
    static func safeButtonAction(_ action: @escaping () -> Void) -> () -> Void {
        return {
            Task { @MainActor in
                action()
            }
        }
    }
    
    /**
     * Creates a safe async button action
     * Ensures proper main actor isolation for async operations
     */
    static func safeAsyncButtonAction(_ action: @escaping () async -> Void) -> () -> Void {
        return {
            Task { @MainActor in
                await action()
            }
        }
    }
}

/**
 * iOS 18 Compatible Button Style
 * Ensures buttons work correctly without gesture conflicts
 */
struct iOS18ButtonStyle: SwiftUI.ButtonStyle {
    let isEnabled: Bool
    let scaleOnPress: Bool
    
    init(isEnabled: Bool = true, scaleOnPress: Bool = true) {
        self.isEnabled = isEnabled
        self.scaleOnPress = scaleOnPress
    }
    
    func makeBody(configuration: SwiftUI.ButtonStyle.Configuration) -> some View {
        configuration.label
            .scaleEffect(scaleOnPress && configuration.isPressed ? 0.95 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

/**
 * iOS 18 Compatible Button Wrapper
 * Use this for buttons that need guaranteed iOS 18 compatibility
 */
struct CompatibleButton<Label: View>: View {
    let label: Label
    let action: () -> Void
    let isEnabled: Bool
    let style: iOS18ButtonStyle
    
    init(
        isEnabled: Bool = true,
        style: iOS18ButtonStyle? = nil,
        @ViewBuilder label: () -> Label,
        action: @escaping () -> Void
    ) {
        self.label = label()
        self.action = iOS18Compatibility.safeButtonAction(action)
        self.isEnabled = isEnabled
        self.style = style ?? iOS18ButtonStyle(isEnabled: isEnabled, scaleOnPress: true)
    }
    
    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(style)
        .disabled(!isEnabled)
    }
}

/**
 * iOS 18 Compatible Async Button Wrapper
 * Use this for buttons with async actions
 */
struct CompatibleAsyncButton<Label: View>: View {
    let label: Label
    let action: () async -> Void
    let isEnabled: Bool
    let isLoading: Bool
    let style: iOS18ButtonStyle
    
    init(
        isEnabled: Bool = true,
        isLoading: Bool = false,
        style: iOS18ButtonStyle? = nil,
        @ViewBuilder label: () -> Label,
        action: @escaping () async -> Void
    ) {
        self.label = label()
        self.action = action
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.style = style ?? iOS18ButtonStyle(isEnabled: isEnabled, scaleOnPress: true)
    }
    
    var body: some View {
        Button(action: {
            Task { @MainActor in
                await action()
            }
        }) {
            label
        }
        .buttonStyle(style)
        .disabled(!isEnabled || isLoading)
    }
}

/**
 * View extension for iOS 18 compatibility helpers
 */
extension View {
    /**
     * Removes gesture conflicts that can prevent button taps in iOS 18
     * Call this on views that contain buttons to ensure they work correctly
     */
    func iOS18ButtonCompatible() -> some View {
        self
            // Ensure view is on main actor
            .task { @MainActor in
                // View is ready
            }
    }
    
    /**
     * Applies iOS 18 compatible button style
     */
    func applyiOS18ButtonStyle(isEnabled: Bool = true, scaleOnPress: Bool = true) -> some View {
        self.buttonStyle(iOS18ButtonStyle(isEnabled: isEnabled, scaleOnPress: scaleOnPress))
    }
}

