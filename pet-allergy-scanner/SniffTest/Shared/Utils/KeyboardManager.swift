import SwiftUI
import UIKit

// MARK: - Keyboard Dismissal Utilities

/**
 * Keyboard Manager
 *
 * Manages keyboard dismissal and session handling across the app
 * Resolves RTIInputSystemClient session errors by properly managing keyboard lifecycle
 *
 * Follows SOLID principles:
 * - Single Responsibility: Only handles keyboard management
 * - DRY: Centralizes keyboard dismissal logic
 * - KISS: Simple API with safe dismissal handling
 */
enum KeyboardManager {
    
    /// Dismisses the keyboard by resigning first responder
    /// Safely handles invalid keyboard sessions
    /// Must be called from the main actor context
    @MainActor
    static func dismiss() {
        // Check if there's an active text input session before dismissing
        guard let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              keyWindow.firstResponder != nil else {
            return // No active input session, skip dismissal
        }
        
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    /// Checks if keyboard is currently visible
    /// - Returns: True if keyboard is active, false otherwise
    @MainActor
    static func isKeyboardVisible() -> Bool {
        guard let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            return false
        }
        return keyWindow.firstResponder != nil
    }
}

// MARK: - UIWindow Extension

extension UIWindow {
    /// Finds the first responder in the window hierarchy
    var firstResponder: UIResponder? {
        guard !isFirstResponder else { return self }
        
        for view in subviews {
            if let responder = view.findFirstResponder() {
                return responder
            }
        }
        return nil
    }
}

extension UIView {
    /// Recursively finds the first responder in view hierarchy
    func findFirstResponder() -> UIResponder? {
        guard !isFirstResponder else { return self }
        
        for subview in subviews {
            if let responder = subview.findFirstResponder() {
                return responder
            }
        }
        return nil
    }
}

// MARK: - View Modifier

/// ViewModifier that adds tap-to-dismiss keyboard functionality
/// Safely handles keyboard dismissal without causing session errors
struct DismissKeyboardOnTap: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                // Only dismiss if keyboard is actually visible
                if KeyboardManager.isKeyboardVisible() {
                    KeyboardManager.dismiss()
                }
            }
    }
}

// MARK: - View Extension

extension View {
    
    /// Adds a tap gesture to dismiss the keyboard when tapping outside input fields
    /// Safely handles keyboard sessions to prevent RTIInputSystemClient errors
    /// - Returns: Modified view with keyboard dismissal capability
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
}

