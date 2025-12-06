//
//  SubscriptionView.swift
//  SniffTest
//
//  View for managing user subscription - displays custom paywall
//

import SwiftUI

/// View for managing user subscription - uses custom PaywallView
struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        PaywallView()
            .onAppear {
                // Track analytics (non-blocking)
                Task.detached(priority: .utility) { @MainActor in
                PostHogAnalytics.trackSubscriptionViewOpened()
                }
            }
    }
}

// MARK: - Preview

#Preview {
    SubscriptionView()
        .environmentObject(AuthService.shared)
}
