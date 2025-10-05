//
//  HapticFeedback.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import UIKit
import SwiftUI

/// Haptic feedback utility for providing tactile feedback to users
@MainActor
struct HapticFeedback {
    
    /// Check if haptic feedback is enabled in settings
    private static var isEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "enableHapticFeedback")
    }
    
    /// Success haptic feedback
    static func success() {
        guard isEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    /// Error haptic feedback
    static func error() {
        guard isEnabled else { return }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    /// Warning haptic feedback
    static func warning() {
        guard isEnabled else { return }
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// Light impact feedback
    static func light() {
        guard isEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    /// Medium impact feedback
    static func medium() {
        guard isEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    /// Heavy impact feedback
    static func heavy() {
        guard isEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    /// Selection haptic feedback
    static func selection() {
        guard isEnabled else { return }
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
}

/// View modifier for adding haptic feedback to buttons
struct HapticButton: ViewModifier {
    let hapticType: HapticType
    let action: () -> Void
    
    enum HapticType {
        case success
        case error
        case warning
        case light
        case medium
        case heavy
        case selection
    }
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                switch hapticType {
                case .success:
                    HapticFeedback.success()
                case .error:
                    HapticFeedback.error()
                case .warning:
                    HapticFeedback.warning()
                case .light:
                    HapticFeedback.light()
                case .medium:
                    HapticFeedback.medium()
                case .heavy:
                    HapticFeedback.heavy()
                case .selection:
                    HapticFeedback.selection()
                }
                action()
            }
    }
}

extension View {
    /// Add haptic feedback to any view
    /// - Parameters:
    ///   - type: Type of haptic feedback
    ///   - action: Action to perform
    /// - Returns: Modified view with haptic feedback
    func hapticFeedback(_ type: HapticButton.HapticType, action: @escaping () -> Void) -> some View {
        self.modifier(HapticButton(hapticType: type, action: action))
    }
}
