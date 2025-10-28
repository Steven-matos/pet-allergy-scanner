//
//  SafeTextField.swift
//  SniffTest
//
//  Created by Code Assistant, 2025.
//

import SwiftUI

/**
 * Safe Text Field
 *
 * Text field wrapper that prevents keyboard session errors
 * Ensures proper keyboard lifecycle management
 *
 * Follows SOLID principles:
 * - Single Responsibility: Only handles text input with proper keyboard management
 * - DRY: Reusable text field component
 * - KISS: Simple API matching standard TextField
 */
struct SafeTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .done
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrectionDisabled: Bool = false
    var onSubmit: (() -> Void)? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil
    
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextField(placeholder, text: $text, onEditingChanged: { editing in
            isEditing = editing
            onEditingChanged?(editing)
        })
        .keyboardType(keyboardType)
        .submitLabel(submitLabel)
        .textInputAutocapitalization(autocapitalization)
        .autocorrectionDisabled(autocorrectionDisabled)
        .focused($isFocused)
        .onSubmit {
            // Safely handle submission
            if let onSubmit = onSubmit {
                onSubmit()
            }
            // Clear focus after submission
            isFocused = false
        }
        .onChange(of: isEditing) { _, newValue in
            // Ensure keyboard session is properly managed
            if !newValue && isFocused {
                isFocused = false
            }
        }
    }
}

/**
 * Safe Secure Field
 *
 * Secure field wrapper that prevents keyboard session errors
 * Ensures proper keyboard lifecycle management for password inputs
 *
 * Follows SOLID principles:
 * - Single Responsibility: Only handles secure text input with proper keyboard management
 * - DRY: Reusable secure field component
 * - KISS: Simple API matching standard SecureField
 */
struct SafeSecureField: View {
    let placeholder: String
    @Binding var text: String
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil
    var onEditingChanged: ((Bool) -> Void)? = nil
    
    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        SecureField(placeholder, text: $text, onCommit: {
            // Safely handle submission
            if let onSubmit = onSubmit {
                onSubmit()
            }
            // Clear focus after submission
            isFocused = false
        })
        .submitLabel(submitLabel)
        .focused($isFocused)
        .onChange(of: isEditing) { _, newValue in
            // Ensure keyboard session is properly managed
            if !newValue && isFocused {
                isFocused = false
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply modern input field styling with safe keyboard handling
    /// - Returns: Styled text field with proper keyboard session management
    func safeInputFieldStyle() -> some View {
        self
            .padding(ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.surface)
            .cornerRadius(ModernDesignSystem.CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.small)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
            .onTapGesture {
                // Prevent keyboard dismissal when tapping the field itself
            }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SafeTextField(
            placeholder: "Enter text",
            text: .constant(""),
            keyboardType: .default
        )
        .modernInputField()
        
        SafeSecureField(
            placeholder: "Enter password",
            text: .constant("")
        )
        .modernInputField()
    }
    .padding()
}

