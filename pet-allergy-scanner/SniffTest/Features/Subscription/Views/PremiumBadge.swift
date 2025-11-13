//
//  PremiumBadge.swift
//  SniffTest
//
//  Reusable badge component to indicate premium features
//

import SwiftUI

/// Badge to indicate premium-only features
struct PremiumBadge: View {
    var size: BadgeSize = .medium
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(size.iconFont)
            Text("PREMIUM")
                .font(size.textFont)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            LinearGradient(
                colors: [
                    ModernDesignSystem.Colors.goldenYellow,
                    ModernDesignSystem.Colors.goldenYellow.opacity(0.8)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(size.cornerRadius)
    }
    
    enum BadgeSize {
        case small
        case medium
        case large
        
        var iconFont: Font {
            switch self {
            case .small:
                return .caption2
            case .medium:
                return .caption
            case .large:
                return .subheadline
            }
        }
        
        var textFont: Font {
            switch self {
            case .small:
                return .caption2
            case .medium:
                return .caption
            case .large:
                return .subheadline
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small:
                return 6
            case .medium:
                return 8
            case .large:
                return 10
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .small:
                return 2
            case .medium:
                return 4
            case .large:
                return 6
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .small:
                return 4
            case .medium:
                return 6
            case .large:
                return 8
            }
        }
    }
}

/// View modifier to add premium badge overlay
struct PremiumBadgeModifier: ViewModifier {
    let alignment: Alignment
    let size: PremiumBadge.BadgeSize
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: alignment) {
                PremiumBadge(size: size)
                    .padding(8)
            }
    }
}

extension View {
    /// Add premium badge overlay to a view
    /// - Parameters:
    ///   - alignment: Where to position the badge
    ///   - size: Size of the badge
    /// - Returns: View with premium badge overlay
    func premiumBadge(alignment: Alignment = .topTrailing, size: PremiumBadge.BadgeSize = .medium) -> some View {
        modifier(PremiumBadgeModifier(alignment: alignment, size: size))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PremiumBadge(size: .small)
        PremiumBadge(size: .medium)
        PremiumBadge(size: .large)
        
        // Example usage with card
        VStack {
            Text("Health Tracking")
                .font(.title2)
            Text("Track your pet's weight and health metrics over time")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .premiumBadge()
        .padding()
    }
}

