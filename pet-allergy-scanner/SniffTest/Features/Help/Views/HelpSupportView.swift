//
//  HelpSupportView.swift
//  SniffTest
//
//  Created by Steven Matos on 10/1/25.
//

import SwiftUI

/**
 * Help & Support Center View
 * 
 * Redesigned following Trust & Nature Design System principles:
 * - Warm & inviting interface with natural tones
 * - Professional typography hierarchy
 * - Consistent spacing and card patterns
 * - Accessible color contrast
 * - Cohesive user experience
 */
struct HelpSupportView: View {
    @State private var searchText = ""
    @State private var selectedCategory: SupportCategory?
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // Header Section
                    headerSection
                    
                    // Search Section
                    searchSection
                    
                    // Quick Actions Section
                    quickActionsSection
                    
                    // FAQ Categories Section
                    faqCategoriesSection
                    
                    // App Information Section
                    appInformationSection
                    
                    Spacer(minLength: ModernDesignSystem.Spacing.xl)
                }
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .sheet(item: $selectedCategory) { category in
                FAQDetailView(category: category)
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 60))
                .foregroundColor(ModernDesignSystem.Colors.primary)
                .accessibilityLabel("Help and support icon")
                        
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                        Text("How can we help?")
                    .font(ModernDesignSystem.Typography.title)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                        
                        Text("Find answers to common questions and get support")
                    .font(ModernDesignSystem.Typography.subheadline)
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, ModernDesignSystem.Spacing.xl)
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                
                TextField("Search help topics...", text: $searchText)
                    .font(ModernDesignSystem.Typography.body)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onTapGesture {
                        isSearching = true
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        isSearching = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                    }
                }
            }
            .padding(ModernDesignSystem.Spacing.md)
            .background(ModernDesignSystem.Colors.softCream)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            sectionHeader(title: "Quick Actions")
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                SupportActionCard(
                            icon: "envelope.fill",
                            title: "Contact Support",
                    description: "Get help from our support team",
                    iconColor: ModernDesignSystem.Colors.primary
                        ) {
                            if let url = URL(string: "mailto:support@petallergycheck.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                        
                SupportActionCard(
                            icon: "star.fill",
                            title: "Rate Our App",
                    description: "Share your experience with others",
                    iconColor: ModernDesignSystem.Colors.goldenYellow
                        ) {
                            // TODO: Implement app rating
                            HapticFeedback.medium()
                        }
                        
                SupportActionCard(
                            icon: "bubble.left.and.bubble.right.fill",
                            title: "Send Feedback",
                    description: "Help us improve the app",
                    iconColor: ModernDesignSystem.Colors.warmCoral
                        ) {
                            if let url = URL(string: "mailto:feedback@petallergycheck.com") {
                                UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
    
    // MARK: - FAQ Categories Section
    
    private var faqCategoriesSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            sectionHeader(title: "Frequently Asked Questions")
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                FAQCategoryCard(
                            icon: "camera.fill",
                            title: "Scanning & OCR",
                    questionCount: 12,
                    iconColor: ModernDesignSystem.Colors.primary
                        ) {
                            selectedCategory = .scanning
                        }
                        
                FAQCategoryCard(
                            icon: "pawprint.fill",
                            title: "Pet Management",
                    questionCount: 8,
                    iconColor: ModernDesignSystem.Colors.goldenYellow
                        ) {
                            selectedCategory = .petManagement
                        }
                        
                FAQCategoryCard(
                            icon: "exclamationmark.triangle.fill",
                            title: "Allergies & Safety",
                    questionCount: 15,
                    iconColor: ModernDesignSystem.Colors.warmCoral
                        ) {
                            selectedCategory = .allergies
                        }
                        
                FAQCategoryCard(
                            icon: "creditcard.fill",
                            title: "Subscription & Billing",
                    questionCount: 6,
                    iconColor: ModernDesignSystem.Colors.primary
                        ) {
                            selectedCategory = .subscription
                        }
                        
                FAQCategoryCard(
                            icon: "lock.fill",
                            title: "Privacy & Security",
                    questionCount: 9,
                    iconColor: ModernDesignSystem.Colors.textSecondary
                        ) {
                            selectedCategory = .privacy
                }
            }
        }
    }
    
    // MARK: - App Information Section
    
    private var appInformationSection: some View {
        VStack(spacing: ModernDesignSystem.Spacing.md) {
            sectionHeader(title: "App Information")
            
            VStack(spacing: ModernDesignSystem.Spacing.sm) {
                InfoCard(title: "Version", value: Bundle.main.appVersion)
                InfoCard(title: "Build", value: Bundle.main.buildNumber)
                        
                        NavigationLink(destination: PrivacyPolicyView()) {
                    LinkCard(
                        icon: "hand.raised.fill",
                        title: "Privacy Policy",
                        iconColor: ModernDesignSystem.Colors.primary
                    )
                }
                        
                        NavigationLink(destination: TermsOfServiceView()) {
                    LinkCard(
                        icon: "doc.text.fill",
                        title: "Terms of Service",
                        iconColor: ModernDesignSystem.Colors.primary
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title)
                .font(ModernDesignSystem.Typography.title3)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
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

/**
 * Support Action Card Component
 * 
 * Modern card design following Trust & Nature principles:
 * - Soft cream background with border primary outline
 * - Consistent spacing and typography
 * - Proper shadows for depth
 * - Accessible color contrast
 */
struct SupportActionCard: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text(description)
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .background(ModernDesignSystem.Colors.softCream)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
}

/**
 * FAQ Category Card Component
 * 
 * Modern card design for FAQ categories:
 * - Trust & Nature color palette
 * - Consistent spacing and typography
 * - Proper card styling with shadows
 * - Accessible design patterns
 */
struct FAQCategoryCard: View {
    let icon: String
    let title: String
    let questionCount: Int
    let iconColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(ModernDesignSystem.Typography.bodyEmphasized)
                        .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                    
                    Text("\(questionCount) questions")
                        .font(ModernDesignSystem.Typography.caption)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            }
            .padding(ModernDesignSystem.Spacing.lg)
            .background(ModernDesignSystem.Colors.softCream)
            .overlay(
                RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                    .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
            )
            .cornerRadius(ModernDesignSystem.CornerRadius.medium)
            .shadow(
                color: ModernDesignSystem.Shadows.small.color,
                radius: ModernDesignSystem.Shadows.small.radius,
                x: ModernDesignSystem.Shadows.small.x,
                y: ModernDesignSystem.Shadows.small.y
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
}

/**
 * Info Card Component
 * 
 * Modern card for displaying app information:
 * - Trust & Nature design patterns
 * - Consistent spacing and typography
 * - Proper card styling
 */
struct InfoCard: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(ModernDesignSystem.Typography.bodyEmphasized)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
}

/**
 * Link Card Component
 * 
 * Modern card for navigation links:
 * - Trust & Nature design patterns
 * - Consistent with other card components
 * - Proper accessibility support
 */
struct LinkCard: View {
    let icon: String
    let title: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: ModernDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            Text(title)
                .font(ModernDesignSystem.Typography.bodyEmphasized)
                .foregroundColor(ModernDesignSystem.Colors.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(ModernDesignSystem.Colors.primary)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
        .padding(.horizontal, ModernDesignSystem.Spacing.lg)
    }
}

/**
 * FAQ Detail View
 * 
 * Modern detail view following Trust & Nature principles:
 * - Consistent with main help view design
 * - Proper typography and spacing
 * - Accessible navigation
 */
struct FAQDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let category: SupportCategory
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ModernDesignSystem.Spacing.lg) {
                    // Header Section
                    VStack(spacing: ModernDesignSystem.Spacing.md) {
                        Image(systemName: categoryIcon)
                            .font(.system(size: 60))
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                            .accessibilityLabel("\(category.title) icon")
                        
                        VStack(spacing: ModernDesignSystem.Spacing.sm) {
                            Text(category.title)
                                .font(ModernDesignSystem.Typography.title)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text("Frequently Asked Questions")
                                .font(ModernDesignSystem.Typography.subheadline)
                        .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, ModernDesignSystem.Spacing.xl)
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    
                    // FAQ Articles
                    VStack(spacing: ModernDesignSystem.Spacing.md) {
                        ForEach(faqArticles, id: \.question) { article in
                            FAQArticleCard(article: article)
                        }
                    }
                    .padding(.horizontal, ModernDesignSystem.Spacing.lg)
                    
                    Spacer(minLength: ModernDesignSystem.Spacing.xl)
                }
            }
            .background(ModernDesignSystem.Colors.background)
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                }
            }
        }
    }
    
    private var categoryIcon: String {
        switch category {
        case .scanning: return "camera.fill"
        case .petManagement: return "pawprint.fill"
        case .allergies: return "exclamationmark.triangle.fill"
        case .subscription: return "creditcard.fill"
        case .privacy: return "lock.fill"
        }
    }
    
    private var faqArticles: [FAQArticle] {
        switch category {
        case .scanning:
            return scanningFAQs
        case .petManagement:
            return petManagementFAQs
        case .allergies:
            return allergiesFAQs
        case .subscription:
            return subscriptionFAQs
        case .privacy:
            return privacyFAQs
        }
    }
}

/**
 * FAQ Article Model
 */
struct FAQArticle {
    let question: String
    let answer: String
    let isImportant: Bool
}

/**
 * FAQ Article Card Component
 */
struct FAQArticleCard: View {
    let article: FAQArticle
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack {
                if article.isImportant {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(ModernDesignSystem.Colors.warmCoral)
                        .font(.system(size: 16))
                }
                
                Text(article.question)
                    .font(ModernDesignSystem.Typography.bodyEmphasized)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            
            Text(article.answer)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .padding(ModernDesignSystem.Spacing.lg)
        .background(ModernDesignSystem.Colors.softCream)
        .overlay(
            RoundedRectangle(cornerRadius: ModernDesignSystem.CornerRadius.medium)
                .stroke(ModernDesignSystem.Colors.borderPrimary, lineWidth: 1)
        )
        .cornerRadius(ModernDesignSystem.CornerRadius.medium)
        .shadow(
            color: ModernDesignSystem.Shadows.small.color,
            radius: ModernDesignSystem.Shadows.small.radius,
            x: ModernDesignSystem.Shadows.small.x,
            y: ModernDesignSystem.Shadows.small.y
        )
    }
}

// MARK: - FAQ Content

private let scanningFAQs: [FAQArticle] = [
    FAQArticle(
        question: "How do I scan a pet food label?",
        answer: "Open the app and tap the camera icon on the main screen. Point your camera at the ingredient list on the pet food label. Make sure the text is clearly visible and well-lit. The app will automatically extract the text and analyze it for your pet's safety.",
        isImportant: false
    ),
    FAQArticle(
        question: "Why is my camera not working?",
        answer: "First, make sure you've granted camera permissions to SniffTest in your device settings. Go to Settings > Privacy & Security > Camera > SniffTest and ensure it's enabled. If the issue persists, try restarting the app or your device.",
        isImportant: true
    ),
    FAQArticle(
        question: "What if the text is blurry or hard to read?",
        answer: "Ensure good lighting and hold your device steady. Try moving closer to the label or adjusting the angle. The app works best with clear, high-contrast text. If the label is damaged or faded, you can manually type the ingredients in the text input option.",
        isImportant: false
    ),
    FAQArticle(
        question: "Can I scan multiple products at once?",
        answer: "No, you can only scan one product at a time. This ensures accurate analysis for each specific product. After scanning one item, you can scan another by tapping the camera button again.",
        isImportant: false
    ),
    FAQArticle(
        question: "Does the app work offline?",
        answer: "Basic scanning and text extraction work offline, but ingredient analysis requires an internet connection. The app will store your scans and process them when you're back online.",
        isImportant: true
    ),
    FAQArticle(
        question: "How accurate is the OCR text recognition?",
        answer: "Our OCR technology works well with clear, well-lit text. Accuracy may vary with poor lighting, damaged labels, or unusual fonts. You can always review and edit the extracted text before analysis. Results are for informational purposes only.",
        isImportant: false
    ),
    FAQArticle(
        question: "What languages are supported for scanning?",
        answer: "Currently, SniffTest supports English text recognition. We're working on adding support for Spanish in future updates.",
        isImportant: false
    ),
    FAQArticle(
        question: "Can I scan handwritten ingredient lists?",
        answer: "The app works best with printed text. Handwritten text may not be recognized accurately. For handwritten lists, we recommend manually typing the ingredients into the text input field.",
        isImportant: false
    ),
    FAQArticle(
        question: "What if the scan fails or shows an error?",
        answer: "Try these steps: 1) Ensure good lighting, 2) Clean your camera lens, 3) Hold the device steady, 4) Make sure the text is clearly visible. If problems persist, try the manual text input option or contact support.",
        isImportant: true
    ),
    FAQArticle(
        question: "How long does it take to analyze a scan?",
        answer: "Most scans are analyzed within 10-30 seconds. Complex products with many ingredients may take up to 2 minutes. You'll see a progress indicator during analysis.",
        isImportant: false
    ),
    FAQArticle(
        question: "Can I save scan results for later?",
        answer: "Yes! All your scans are automatically saved to your scan history. You can also mark products as favorites if they're safe for your pet.",
        isImportant: false
    ),
    FAQArticle(
        question: "What if I disagree with the safety assessment?",
        answer: "Our analysis is for informational purposes only and should not replace professional veterinary advice. Every pet is unique and may have individual health considerations. Always consult your veterinarian for specific dietary concerns and medical decisions. You can provide feedback on our analysis through the app.",
        isImportant: true
    )
]

private let petManagementFAQs: [FAQArticle] = [
    FAQArticle(
        question: "How do I add a new pet to my profile?",
        answer: "Go to the Pets tab and tap the '+' button. Fill in your pet's name, species (dog or cat), breed, birthday, weight, and any known sensitivities. You can also add a photo and vet information.",
        isImportant: false
    ),
    FAQArticle(
        question: "Can I have multiple pets in one account?",
        answer: "Multiple pet profiles are available with a premium subscription. Free users can have one pet profile, while premium subscribers can add unlimited pets. Each pet has their own profile with individual allergy tracking and scan history.",
        isImportant: true
    ),
    FAQArticle(
        question: "How do I update my pet's information?",
        answer: "Go to the Pets tab, select your pet, and tap 'Edit Profile'. You can update weight, add new sensitivities, change vet information, or update their photo at any time.",
        isImportant: false
    ),
    FAQArticle(
        question: "What if I don't know my pet's exact birthday?",
        answer: "You can estimate your pet's age in months or years. The app will calculate their life stage (puppy/kitten, adult, senior) based on their species and estimated age.",
        isImportant: false
    ),
    FAQArticle(
        question: "How do I track my pet's weight changes?",
        answer: "In your pet's profile, tap 'Update Weight' to record new measurements. The app will track weight trends and provide insights about your pet's health.",
        isImportant: false
    ),
    FAQArticle(
        question: "What are known sensitivities and how do I add them?",
        answer: "Known sensitivities are ingredients your pet has reacted to in the past. Add them in your pet's profile so the app can warn you when scanning products that contain these ingredients.",
        isImportant: true
    ),
    FAQArticle(
        question: "Can I delete a pet profile?",
        answer: "Yes, you can delete a pet profile by going to their profile page and selecting 'Delete Pet'. This will remove all associated scan history and data permanently.",
        isImportant: true
    ),
    FAQArticle(
        question: "How do I add vet information?",
        answer: "In your pet's profile, scroll down to 'Veterinary Information' and add your vet's name and phone number. This information is stored locally on your device for quick access.",
        isImportant: false
    )
]

private let allergiesFAQs: [FAQArticle] = [
    FAQArticle(
        question: "What ingredients are most dangerous for dogs?",
        answer: "Common ingredients that may be problematic for dogs include: chocolate, grapes, raisins, onions, garlic, xylitol, macadamia nuts, and certain artificial sweeteners. This information is for educational purposes only. Always consult your veterinarian about your specific pet's dietary needs and health concerns.",
        isImportant: true
    ),
    FAQArticle(
        question: "What ingredients are most dangerous for cats?",
        answer: "Ingredients that may be problematic for cats include: onions, garlic, chocolate, caffeine, alcohol, grapes, raisins, and certain essential oils. Cats are obligate carnivores, so high-carb diets may not be ideal. This information is for educational purposes only. Always consult your veterinarian about your specific pet's dietary needs.",
        isImportant: true
    ),
    FAQArticle(
        question: "How does the app determine if an ingredient is safe?",
        answer: "Our database includes general information about ingredients and their potential effects on pets. The app considers your pet's species, age, and known sensitivities when analyzing ingredients. However, this analysis is for informational purposes only and should not replace professional veterinary advice.",
        isImportant: false
    ),
    FAQArticle(
        question: "What should I do if my pet has an allergic reaction?",
        answer: "If you suspect your pet is having an allergic reaction, contact your veterinarian or emergency veterinary clinic immediately. Common symptoms may include vomiting, diarrhea, itching, swelling, or difficulty breathing. This is a medical emergency that requires professional veterinary care.",
        isImportant: true
    ),
    FAQArticle(
        question: "Can the app detect food allergies vs. food intolerances?",
        answer: "The app identifies potentially problematic ingredients for informational purposes only. It cannot and does not diagnose specific allergies or intolerances. Only a licensed veterinarian can diagnose food allergies through proper medical testing and evaluation.",
        isImportant: true
    ),
    FAQArticle(
        question: "What if my pet has a rare allergy not in the database?",
        answer: "You can add custom sensitivities in your pet's profile. The app will flag any products containing those specific ingredients during scans.",
        isImportant: false
    ),
    FAQArticle(
        question: "Are grain-free diets always better for pets?",
        answer: "Not necessarily. While some pets may benefit from grain-free diets, others may develop health issues from grain-free foods. This is a complex topic that varies by individual pet. Always consult your veterinarian about the best diet for your specific pet's health needs.",
        isImportant: true
    ),
    FAQArticle(
        question: "How often should I check ingredients for my pet?",
        answer: "Check ingredients every time you buy new food or treats, even from the same brand. Manufacturers may change formulations without notice.",
        isImportant: false
    ),
    FAQArticle(
        question: "What about treats and supplements?",
        answer: "Yes, you can scan treats and supplements too. The app analyzes all pet food products, including treats, supplements, and dental chews.",
        isImportant: false
    ),
    FAQArticle(
        question: "Can I trust the safety ratings completely?",
        answer: "Our ratings are for informational purposes only and should not be the sole basis for dietary decisions. Every pet is unique and may have individual health considerations. Always consult your veterinarian for specific dietary recommendations, especially for pets with health conditions or special needs.",
        isImportant: true
    ),
    FAQArticle(
        question: "What if an ingredient is marked as 'caution'?",
        answer: "A 'caution' rating means the ingredient may be problematic for some pets or in large quantities. This is for informational purposes only. Consider your pet's individual health and always consult your veterinarian if you have concerns about specific ingredients.",
        isImportant: false
    ),
    FAQArticle(
        question: "How do I know if my pet is having a food reaction?",
        answer: "Common signs that may indicate a food reaction include vomiting, diarrhea, itching, skin irritation, ear infections, or changes in behavior. If you suspect your pet is having a food reaction, contact your veterinarian immediately for proper evaluation and care.",
        isImportant: true
    ),
    FAQArticle(
        question: "Can the app help with elimination diets?",
        answer: "The app can help identify potential allergens in foods for informational purposes, but elimination diets should always be conducted under direct veterinary supervision and guidance. Never attempt elimination diets without professional veterinary oversight.",
        isImportant: true
    ),
    FAQArticle(
        question: "What about prescription diets?",
        answer: "Prescription diets should only be used under direct veterinary guidance and supervision. The app can analyze their ingredients for informational purposes, but always follow your veterinarian's specific recommendations and never make dietary changes without professional veterinary approval.",
        isImportant: true
    ),
    FAQArticle(
        question: "How do I transition my pet to a new food safely?",
        answer: "Gradually mix the new food with the old food over 7-10 days, increasing the proportion of new food each day. This general guideline may help prevent digestive upset, but always consult your veterinarian for specific transition advice tailored to your pet's individual needs.",
        isImportant: false
    )
]

private let subscriptionFAQs: [FAQArticle] = [
    FAQArticle(
        question: "Is SniffTest free to use?",
        answer: "SniffTest offers a free tier with basic scanning features and one pet profile. Premium subscriptions unlock advanced features like unlimited scans, multiple pet profiles, detailed nutritional analysis, and priority support.",
        isImportant: false
    ),
    FAQArticle(
        question: "What features are included in the premium subscription?",
        answer: "Premium includes: unlimited scans, detailed nutritional breakdowns, weight tracking trends, multiple pet profiles (unlimited), scan history export, and priority customer support. Free users get basic scanning with one pet profile.",
        isImportant: false
    ),
    FAQArticle(
        question: "How do I cancel my subscription?",
        answer: "You can cancel through your iPhone's App Store settings. Go to Settings > [Your Name] > Subscriptions > SniffTest > Cancel Subscription.",
        isImportant: true
    ),
    FAQArticle(
        question: "Will I lose my data if I cancel?",
        answer: "Your scan history and pet profiles are saved for 30 days after cancellation, subject to our terms of service and privacy policy. You can reactivate your subscription to restore full access to your data. Data retention is subject to applicable data protection laws.",
        isImportant: true
    ),
    FAQArticle(
        question: "Can I get a refund for my subscription?",
        answer: "Refund requests are handled through Apple. Contact Apple Support for subscription refunds through the App Store.",
        isImportant: false
    ),
    FAQArticle(
        question: "Do you offer family plans?",
        answer: "Currently, we offer individual subscriptions. Each family member needs their own account and subscription to use the app.",
        isImportant: false
    )
]

private let privacyFAQs: [FAQArticle] = [
    FAQArticle(
        question: "Is my pet's data secure?",
        answer: "We implement industry-standard security measures to protect your data, including encryption and secure storage practices. However, no system is 100% secure. We never share your personal information with third parties without your explicit consent, subject to our privacy policy.",
        isImportant: true
    ),
    FAQArticle(
        question: "What information does the app collect?",
        answer: "We collect: pet profiles, scan results, and usage analytics for app functionality. We do not collect personal information like your name, address, or payment details (handled by Apple). For complete details, please review our privacy policy.",
        isImportant: false
    ),
    FAQArticle(
        question: "Can I export my pet's data?",
        answer: "Yes, you can export your pet profiles and scan history through the app settings. This includes all your data in a readable format.",
        isImportant: false
    ),
    FAQArticle(
        question: "How do I delete my account and data?",
        answer: "Go to Settings > Account > Delete Account. This will permanently remove all your data, including pet profiles and scan history. This action cannot be undone. Data deletion is subject to our privacy policy and applicable data protection laws.",
        isImportant: true
    ),
    FAQArticle(
        question: "Do you share data with veterinarians?",
        answer: "No, we don't automatically share data with veterinarians. You can manually share scan results with your vet through the app's sharing features.",
        isImportant: false
    ),
    FAQArticle(
        question: "Is my scan data used for research?",
        answer: "We may use anonymized, aggregated data to improve our ingredient database, but never your personal pet information or individual scan results. Any data usage is subject to our privacy policy and applicable privacy laws.",
        isImportant: false
    ),
    FAQArticle(
        question: "How long is my data stored?",
        answer: "Your data is stored as long as your account is active. If you delete your account, all data is permanently removed within 30 days, subject to our privacy policy and applicable data protection laws.",
        isImportant: false
    ),
    FAQArticle(
        question: "Can I use the app without creating an account?",
        answer: "Basic scanning features work without an account, but you'll need to create an account to save pet profiles and scan history.",
        isImportant: false
    ),
    FAQArticle(
        question: "What about children's privacy?",
        answer: "SniffTest is not intended for children under 13. We don't knowingly collect information from children under 13 years of age. If you believe we have collected information from a child under 13, please contact us immediately.",
        isImportant: true
    )
]

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