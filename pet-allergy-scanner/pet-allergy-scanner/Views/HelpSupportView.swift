//
//  HelpSupportView.swift
//  pet-allergy-scanner
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI

/// View for help and support resources
struct HelpSupportView: View {
    @State private var searchText = ""
    @State private var selectedCategory: SupportCategory?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                        
                        Text("How can we help?")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Find answers to common questions and get support")
                            .font(.subheadline)
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal)
                    
                    // Quick Actions
                    VStack(spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        SupportActionButton(
                            icon: "envelope.fill",
                            title: "Contact Support",
                            description: "Get help from our support team"
                        ) {
                            if let url = URL(string: "mailto:support@petallergycheck.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                        
                        SupportActionButton(
                            icon: "star.fill",
                            title: "Rate Our App",
                            description: "Share your experience with others"
                        ) {
                            // TODO: Implement app rating
                            HapticFeedback.medium()
                        }
                        
                        SupportActionButton(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Send Feedback",
                            description: "Help us improve the app"
                        ) {
                            if let url = URL(string: "mailto:feedback@petallergycheck.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // FAQ Categories
                    VStack(spacing: 12) {
                        Text("Frequently Asked Questions")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        FAQCategoryRow(
                            icon: "camera.fill",
                            title: "Scanning & OCR",
                            questionCount: 8
                        ) {
                            selectedCategory = .scanning
                        }
                        
                        FAQCategoryRow(
                            icon: "pawprint.fill",
                            title: "Pet Management",
                            questionCount: 6
                        ) {
                            selectedCategory = .petManagement
                        }
                        
                        FAQCategoryRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "Allergies & Safety",
                            questionCount: 10
                        ) {
                            selectedCategory = .allergies
                        }
                        
                        FAQCategoryRow(
                            icon: "creditcard.fill",
                            title: "Subscription & Billing",
                            questionCount: 5
                        ) {
                            selectedCategory = .subscription
                        }
                        
                        FAQCategoryRow(
                            icon: "lock.fill",
                            title: "Privacy & Security",
                            questionCount: 7
                        ) {
                            selectedCategory = .privacy
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // App Information
                    VStack(spacing: 12) {
                        Text("App Information")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        InfoRow(title: "Version", value: Bundle.main.appVersion)
                        InfoRow(title: "Build", value: Bundle.main.buildNumber)
                        
                        Button(action: {
                            if let url = URL(string: "https://petallergycheck.com/privacy") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Text("Privacy Policy")
                                    .font(.body)
                                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                            }
                            .padding()
                            .background(ModernDesignSystem.Colors.surfaceVariant)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        Button(action: {
                            if let url = URL(string: "https://petallergycheck.com/terms") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Text("Terms of Service")
                                    .font(.body)
                                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                            }
                            .padding()
                            .background(ModernDesignSystem.Colors.surfaceVariant)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedCategory) { category in
                FAQDetailView(category: category)
            }
        }
    }
}

/// Support category enum
enum SupportCategory: Identifiable {
    case scanning
    case petManagement
    case allergies
    case subscription
    case privacy
    
    var id: String {
        switch self {
        case .scanning: return "scanning"
        case .petManagement: return "petManagement"
        case .allergies: return "allergies"
        case .subscription: return "subscription"
        case .privacy: return "privacy"
        }
    }
    
    var title: String {
        switch self {
        case .scanning: return "Scanning & OCR"
        case .petManagement: return "Pet Management"
        case .allergies: return "Allergies & Safety"
        case .subscription: return "Subscription & Billing"
        case .privacy: return "Privacy & Security"
        }
    }
}

/// Support action button component
struct SupportActionButton: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding()
            .background(ModernDesignSystem.Colors.surfaceVariant)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

/// FAQ category row component
struct FAQCategoryRow: View {
    let icon: String
    let title: String
    let questionCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(ModernDesignSystem.Colors.deepForestGreen)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    
                    Text("\(questionCount) questions")
                        .font(.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding()
            .background(ModernDesignSystem.Colors.surfaceVariant)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
}

/// Info row component
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
        }
        .padding()
        .background(ModernDesignSystem.Colors.surfaceVariant)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

/// FAQ detail view
struct FAQDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let category: SupportCategory
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Coming soon: FAQ articles for \(category.title)")
                        .font(.body)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Bundle extension for app version info
extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    HelpSupportView()
}

