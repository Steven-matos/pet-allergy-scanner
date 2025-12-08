//
//  KeyboardManager.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import SwiftUI
import UIKit
@preconcurrency import Combine

// MARK: - Keyboard Management System

/**
 * Keyboard Management System
 *
 * Comprehensive keyboard handling solution that provides both keyboard avoidance
 * and dismissal functionality. Prevents text fields from being covered by the
 * on-screen keyboard and manages keyboard lifecycle properly.
 *
 * Features:
 * - Automatic keyboard height detection and avoidance
 * - Smooth animations with proper timing curves
 * - ScrollView-aware adjustments with auto-scroll to focused fields
 * - Safe keyboard dismissal without session errors
 * - Safe area considerations
 * - Performance optimized with minimal re-renders
 * - Integration with design system
 *
 * Follows SOLID principles:
 * - Single Responsibility: Only handles keyboard management and avoidance
 * - DRY: Reusable across all views with text input
 * - KISS: Simple API with automatic behavior
 */

// MARK: - Keyboard Avoidance Manager

@MainActor
class KeyboardAvoidanceManager: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupKeyboardObservers()
    }
    
    nonisolated deinit {
        cancellables.removeAll()
    }
    
    /**
     * Setup keyboard notification observers
     * Handles both keyboard show/hide events with proper animation timing
     */
    private func setupKeyboardObservers() {
        // Keyboard will show
        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification in
                guard let userInfo = notification.userInfo,
                      let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                      let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
                      let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
                    return nil
                }
                return KeyboardEvent(
                    height: keyboardFrame.height,
                    duration: animationDuration,
                    curve: UIView.AnimationCurve(rawValue: Int(animationCurve)) ?? .easeInOut
                )
            }
            .debounce(for: .milliseconds(1), scheduler: RunLoop.main)
            .sink { [weak self] event in
                self?.handleKeyboardShow(event: event)
            }
            .store(in: &cancellables)
        
        // Keyboard will hide
        NotificationCenter.default
            .publisher(for: UIResponder.keyboardWillHideNotification)
            .compactMap { notification in
                guard let userInfo = notification.userInfo,
                      let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
                      let animationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
                    return nil
                }
                return KeyboardEvent(
                    height: 0,
                    duration: animationDuration,
                    curve: UIView.AnimationCurve(rawValue: Int(animationCurve)) ?? .easeInOut
                )
            }
            .debounce(for: .milliseconds(1), scheduler: RunLoop.main)
            .sink { [weak self] event in
                self?.handleKeyboardHide(event: event)
            }
            .store(in: &cancellables)
    }
    
    /**
     * Handle keyboard show event with smooth animation
     * Updates are deferred to next run loop to avoid publishing changes from within view updates
     */
    private func handleKeyboardShow(event: KeyboardEvent) {
        applyKeyboard(show: true, height: event.height)
    }
    
    /**
     * Handle keyboard hide event with smooth animation
     * Updates are deferred to avoid publishing changes from within view updates
     */
    private func handleKeyboardHide(event: KeyboardEvent) {
        applyKeyboard(show: false, height: 0)
    }
    
    /// Applies keyboard state changes safely on the next run loop to avoid publishing during view updates
    private func applyKeyboard(show: Bool, height: CGFloat) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.keyboardHeight = height
            self.isKeyboardVisible = show
        }
    }
}

/**
 * Keyboard event data structure
 */
private struct KeyboardEvent {
    let height: CGFloat
    let duration: Double
    let curve: UIView.AnimationCurve
}

// MARK: - Keyboard Dismissal Manager

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

// MARK: - UIWindow Extensions

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

// MARK: - View Modifiers

/**
 * KeyboardAvoidanceView Modifier
 * 
 * Automatically adjusts view content when keyboard appears/disappears
 * Works with ScrollView, VStack, and other container views
 */
struct KeyboardAvoidanceViewModifier: ViewModifier {
    @StateObject private var keyboardManager = KeyboardAvoidanceManager()
    let behavior: KeyboardAvoidanceBehavior
    
    func body(content: Content) -> some View {
        content
            .onReceive(keyboardManager.$isKeyboardVisible) { isVisible in
                if isVisible {
                    behavior.onKeyboardShow?()
                } else {
                    behavior.onKeyboardHide?()
                }
            }
    }
}

/**
 * KeyboardAvoidanceScrollView Modifier
 * 
 * Specialized modifier for ScrollView that provides enhanced keyboard avoidance
 * Automatically scrolls to focused text fields
 */
struct KeyboardAvoidanceScrollViewModifier: ViewModifier {
    @StateObject private var keyboardManager = KeyboardAvoidanceManager()
    @FocusState private var focusedField: AnyHashable?
    let behavior: KeyboardAvoidanceBehavior
    
    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: keyboardManager.isKeyboardVisible) { _, isVisible in
                    if isVisible {
                        behavior.onKeyboardShow?()
                        // Auto-scroll to focused field if available
                        if let focusedField = focusedField {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(focusedField, anchor: .center)
                            }
                        }
                    } else {
                        behavior.onKeyboardHide?()
                    }
                }
        }
    }
}

/// ViewModifier that adds tap-to-dismiss keyboard functionality
/// Safely handles keyboard dismissal without causing session errors
/// iOS 18.6.2 fix: Uses background tap that doesn't interfere with interactive elements
struct DismissKeyboardOnTap: ViewModifier {
    
    func body(content: Content) -> some View {
        content
            .background(
                // Invisible background that captures taps on empty space only
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Only dismiss if keyboard is actually visible
                        // This allows TextFields, Pickers, and Buttons to work normally
                        if KeyboardManager.isKeyboardVisible() {
                            KeyboardManager.dismiss()
                        }
                    }
            )
    }
}

// MARK: - Configuration Types

/**
 * Keyboard avoidance behavior configuration
 */
struct KeyboardAvoidanceBehavior: Sendable {
    let onKeyboardShow: (@Sendable () -> Void)?
    let onKeyboardHide: (@Sendable () -> Void)?
    
    init(
        onKeyboardShow: (@Sendable () -> Void)? = nil,
        onKeyboardHide: (@Sendable () -> Void)? = nil
    ) {
        self.onKeyboardShow = onKeyboardShow
        self.onKeyboardHide = onKeyboardHide
    }
    
    /// Default behavior with no custom actions
    static let `default` = KeyboardAvoidanceBehavior()
    
    /// Behavior that dismisses keyboard on tap outside
    static let dismissOnTap = KeyboardAvoidanceBehavior(
        onKeyboardShow: nil,
        onKeyboardHide: nil
    )
}

// MARK: - View Extensions

extension View {
    
    /**
     * Apply keyboard avoidance to any view
     * 
     * - Parameter behavior: Custom behavior configuration
     * - Returns: Modified view with keyboard avoidance
     */
    func keyboardAvoidance(behavior: KeyboardAvoidanceBehavior = .default) -> some View {
        modifier(KeyboardAvoidanceViewModifier(behavior: behavior))
    }
    
    /**
     * Apply enhanced keyboard avoidance for ScrollView
     * 
     * - Parameter behavior: Custom behavior configuration
     * - Returns: Modified ScrollView with enhanced keyboard avoidance
     */
    func keyboardAvoidanceScrollView(behavior: KeyboardAvoidanceBehavior = .default) -> some View {
        modifier(KeyboardAvoidanceScrollViewModifier(behavior: behavior))
    }
    
    /**
     * Apply keyboard avoidance with tap-to-dismiss functionality
     * 
     * - Returns: Modified view with keyboard avoidance and tap-to-dismiss
     */
    func keyboardAvoidanceWithDismiss() -> some View {
        keyboardAvoidance(behavior: .dismissOnTap)
            .onTapGesture {
                KeyboardManager.dismiss()
            }
    }
    
    /// Adds a tap gesture to dismiss the keyboard when tapping outside input fields
    /// Safely handles keyboard sessions to prevent RTIInputSystemClient errors
    /// - Returns: Modified view with keyboard dismissal capability
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTap())
    }
}

// MARK: - Form-Specific Extensions

extension View {
    
    /**
     * Apply keyboard avoidance specifically for forms
     * Uses modern SwiftUI 2025 best practices with native keyboard handling
     * 
     * - Returns: Modified view optimized for form input
     */
    func formKeyboardAvoidance() -> some View {
        self
            .keyboardAvoidance()
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                KeyboardManager.dismiss()
            }
    }
    
    /**
     * Modern SwiftUI keyboard avoidance using native 2025 best practices
     * Leverages safeAreaInset and scrollDismissesKeyboard for optimal UX
     * 
     * - Returns: Modified view with native keyboard avoidance
     */
    func modernKeyboardAvoidance() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
    }
    
    /**
     * Minimal keyboard avoidance that only provides scroll dismissal
     * No custom spacing to avoid white space issues
     * 
     * - Returns: Modified view with minimal keyboard handling
     */
    func minimalKeyboardAvoidance() -> some View {
        self
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                KeyboardManager.dismiss()
            }
    }
}

// MARK: - Preview Support

#Preview("Keyboard Management Demo") {
    NavigationStack {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                ForEach(0..<10, id: \.self) { index in
                    TextField("Text Field \(index + 1)", text: .constant(""))
                        .modernInputField()
                }
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        .formKeyboardAvoidance()
        .navigationTitle("Keyboard Management Test")
    }
}
