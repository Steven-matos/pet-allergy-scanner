import SwiftUI

/// View displaying the app's Terms of Service
struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Header Card
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Terms of Service")
                                .font(ModernDesignSystem.Typography.title)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Text("Last updated: October, 2025")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
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
                
                // Introduction Section
                LegalSectionCard(
                    title: "Introduction",
                    icon: "hand.raised.fill",
                    content: "Welcome to SniffTest, your trusted companion for pet nutrition and allergy scanning. By using our app, you agree to be bound by these Terms of Service. Please read them carefully."
                )
                
                // Acceptance of Terms
                LegalSectionCard(
                    title: "Acceptance of Terms",
                    icon: "checkmark.circle.fill",
                    content: "By downloading, installing, or using the SniffTest app, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree to these terms, please do not use our app."
                )
                
                // Service Description
                LegalSectionCard(
                    title: "Service Description",
                    icon: "pawprint.fill",
                    content: "SniffTest provides informational pet nutrition analysis and ingredient scanning services for educational purposes only. Our app uses OCR technology to analyze pet food ingredients and provide general information. This service is NOT a substitute for professional veterinary advice, diagnosis, or treatment. Always consult your veterinarian for medical decisions regarding your pet's health."
                )
                
                // User Responsibilities
                LegalSectionCard(
                    title: "User Responsibilities",
                    icon: "person.fill",
                    content: "You are responsible for: (1) Providing accurate pet information, (2) Using the app in accordance with applicable laws, (3) Not sharing false or misleading information, (4) Respecting intellectual property rights, and (5) Maintaining the security of your account."
                )
                
                // Prohibited Uses
                LegalSectionCard(
                    title: "Prohibited Uses",
                    icon: "exclamationmark.triangle.fill",
                    content: "You may not: (1) Use the app for illegal purposes, (2) Attempt to reverse engineer or hack the app, (3) Share false information about pet health, (4) Use the app to harm animals, (5) Violate any applicable laws or regulations."
                )
                
                // Intellectual Property
                LegalSectionCard(
                    title: "Intellectual Property",
                    icon: "copyright.fill",
                    content: "All content, features, and functionality of SniffTest are owned by us and are protected by copyright, trademark, and other intellectual property laws. You may not copy, modify, or distribute our content without permission."
                )
                
                // Disclaimers
                LegalSectionCard(
                    title: "Disclaimers",
                    icon: "info.circle.fill",
                    content: "SniffTest is provided 'as is' without warranties of any kind, express or implied. We do not guarantee the accuracy, completeness, or reliability of any nutritional information, allergy assessments, or recommendations. The app is for informational and educational purposes only and should never replace professional veterinary advice, diagnosis, or treatment. Always consult with a licensed veterinarian for all pet health decisions."
                )
                
                // Limitation of Liability
                LegalSectionCard(
                    title: "Limitation of Liability",
                    icon: "shield.fill",
                    content: "To the maximum extent permitted by applicable law, our total liability to you for any claims arising from or related to the app shall not exceed the amount you paid for the app in the 12 months preceding the claim. We shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to pet health issues, financial losses, or data loss. Some jurisdictions do not allow limitation of liability, so these limitations may not apply to you."
                )
                
                // Termination
                LegalSectionCard(
                    title: "Termination",
                    icon: "stop.circle.fill",
                    content: "We may terminate or suspend your access to the app at any time, with or without notice, for any reason, including violation of these terms. You may stop using the app at any time."
                )
                
                // Changes to Terms
                LegalSectionCard(
                    title: "Changes to Terms",
                    icon: "arrow.clockwise.circle.fill",
                    content: "We reserve the right to modify these terms at any time. We will notify users of significant changes through the app or email. Continued use of the app after changes constitutes acceptance of the new terms."
                )
                
                // Governing Law and Dispute Resolution
                LegalSectionCard(
                    title: "Governing Law and Dispute Resolution",
                    icon: "scale.3d.fill",
                    content: "These terms are governed by the laws of [Your Jurisdiction]. Any disputes arising from these terms or your use of the app shall be resolved through binding arbitration administered by [Arbitration Organization]. You waive your right to participate in class action lawsuits or class-wide arbitration. You may opt out of this arbitration clause within 30 days of first using the app by contacting us at legal@snifftest.com."
                )
                
                // Force Majeure
                LegalSectionCard(
                    title: "Force Majeure",
                    icon: "exclamationmark.triangle.fill",
                    content: "We shall not be liable for any failure or delay in performance due to circumstances beyond our reasonable control, including but not limited to acts of God, natural disasters, war, terrorism, government actions, internet outages, or other force majeure events."
                )
                
                // Severability
                LegalSectionCard(
                    title: "Severability",
                    icon: "doc.text.fill",
                    content: "If any provision of these terms is found to be unenforceable or invalid, the remaining provisions shall remain in full force and effect. We will replace any invalid provision with a valid provision that most closely reflects the original intent."
                )
                
                // Contact Information
                LegalSectionCard(
                    title: "Contact Information",
                    icon: "envelope.fill",
                    content: "If you have questions about these Terms of Service, please contact us at legal@snifftest.com or through our support channels within the app."
                )
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        .background(ModernDesignSystem.Colors.background)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

/// View displaying the app's Privacy Policy
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: ModernDesignSystem.Spacing.lg) {
                // Header Card
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.title2)
                            .foregroundColor(ModernDesignSystem.Colors.primary)
                        
                        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                            Text("Privacy Policy")
                                .font(ModernDesignSystem.Typography.title)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            
                            Text("Last updated: October, 2025")
                                .font(ModernDesignSystem.Typography.caption)
                                .foregroundColor(ModernDesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                    }
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
                
                // Introduction Section
                LegalSectionCard(
                    title: "Introduction",
                    icon: "shield.fill",
                    content: "At SniffTest, we are committed to protecting your privacy and the privacy of your pets. This Privacy Policy explains how we collect, use, and safeguard your personal information when you use our app."
                )
                
                // Information We Collect
                LegalSectionCard(
                    title: "Information We Collect",
                    icon: "doc.text.fill",
                    content: "We collect the following categories of information: (1) Account information (name, email address), (2) Pet information (name, species, weight, known sensitivities), (3) Scan data (food images, ingredient analysis results), (4) Usage data (app interactions, feature usage, preferences), and (5) Device information (device type, operating system, app version). We collect this information to provide our services and improve user experience."
                )
                
                // How We Use Information
                LegalSectionCard(
                    title: "How We Use Information",
                    icon: "gear.circle.fill",
                    content: "We use your information to: (1) Provide and improve our services, (2) Analyze pet food ingredients and provide nutritional information, (3) Personalize your experience, (4) Communicate with you about updates and features, (5) Ensure security and prevent fraud, and (6) Comply with legal obligations. We do not sell your personal information to third parties."
                )
                
                // Data Sharing and Disclosure
                LegalSectionCard(
                    title: "Data Sharing and Disclosure",
                    icon: "person.2.fill",
                    content: "We may share your information with: (1) Service providers (cloud hosting, analytics, customer support), (2) Third-party APIs for ingredient analysis, (3) Legal authorities when required by law or to protect rights and safety, and (4) Business partners with your explicit consent. We require all third parties to maintain the confidentiality and security of your information."
                )
                
                // Data Security
                LegalSectionCard(
                    title: "Data Security",
                    icon: "lock.shield.fill",
                    content: "We implement industry-standard security measures to protect your data, including encryption in transit and at rest, secure authentication, regular security audits, and access controls. However, no system is 100% secure, and we cannot guarantee absolute security. You are responsible for maintaining the security of your account credentials."
                )
                
                // Data Retention
                LegalSectionCard(
                    title: "Data Retention",
                    icon: "clock.fill",
                    content: "We retain your data for as long as your account is active or as needed to provide services. After account deletion, we will delete or anonymize your personal information within 30 days, except where required by law to retain certain information. Scan history and pet profiles are deleted immediately upon account deletion."
                )
                
                // Your Rights
                LegalSectionCard(
                    title: "Your Rights",
                    icon: "hand.raised.fill",
                    content: "You have the right to: (1) Access your personal data, (2) Correct inaccurate information, (3) Delete your account and data, (4) Export your data, (5) Opt-out of marketing communications, and (6) Withdraw consent for data processing. To exercise these rights, contact us at privacy@snifftest.com or use the in-app settings."
                )
                
                // Children's Privacy
                LegalSectionCard(
                    title: "Children's Privacy",
                    icon: "figure.and.child.holdinghands",
                    content: "Our app is not intended for children under 13. We do not knowingly collect personal information from children. If we discover that we have collected information from a child under 13, we will delete it immediately. Parents or guardians who believe their child has provided information should contact us at privacy@snifftest.com."
                )
                
                // Cookies and Tracking
                LegalSectionCard(
                    title: "Cookies and Tracking",
                    icon: "antenna.radiowaves.left.and.right",
                    content: "We use analytics tools and tracking technologies to understand how you use our app, improve functionality, and provide personalized experiences. You can manage your preferences in the app settings. We use third-party analytics services that may collect data about your usage patterns."
                )
                
                // Third-Party Links
                LegalSectionCard(
                    title: "Third-Party Links",
                    icon: "link.circle.fill",
                    content: "Our app may contain links to third-party websites or services. We are not responsible for the privacy practices of these third parties. We encourage you to review their privacy policies before providing any personal information. This Privacy Policy applies only to our app and services."
                )
                
                // International Data Transfers
                LegalSectionCard(
                    title: "International Data Transfers",
                    icon: "globe.americas.fill",
                    content: "Your information may be transferred to and processed in countries other than your country of residence. We ensure appropriate safeguards are in place for international transfers, including standard contractual clauses and adequacy decisions. By using our app, you consent to these transfers."
                )
                
                // GDPR Compliance
                LegalSectionCard(
                    title: "GDPR Compliance",
                    icon: "globe.europe.africa.fill",
                    content: "For users in the European Union, we comply with the General Data Protection Regulation (GDPR). We process your personal data based on legitimate interests, contract performance, and consent where required. You have enhanced rights under GDPR, including the right to data portability and the right to be forgotten. Our Data Protection Officer can be contacted at dpo@snifftest.com."
                )
                
                // CCPA Compliance
                LegalSectionCard(
                    title: "CCPA Compliance",
                    icon: "building.2.fill",
                    content: "For California residents, we comply with the California Consumer Privacy Act (CCPA). You have the right to know what personal information we collect, the right to delete personal information, the right to opt-out of the sale of personal information (we do not sell personal information), and the right to non-discrimination. To exercise these rights, contact us at privacy@snifftest.com."
                )
                
                // Changes to Privacy Policy
                LegalSectionCard(
                    title: "Changes to Privacy Policy",
                    icon: "arrow.clockwise.circle.fill",
                    content: "We may update this Privacy Policy from time to time. We will notify you of significant changes through the app or email. Your continued use of the app after changes constitutes acceptance of the updated policy."
                )
                
                // Contact Information
                LegalSectionCard(
                    title: "Contact Information",
                    icon: "envelope.fill",
                    content: "For privacy-related questions or to exercise your rights, contact us at privacy@snifftest.com or through our support channels within the app. We will respond to your request within 30 days as required by applicable law."
                )
            }
            .padding(ModernDesignSystem.Spacing.lg)
        }
        .background(ModernDesignSystem.Colors.background)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(ModernDesignSystem.Colors.softCream, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}

/// Reusable legal section card component following Trust & Nature design system
struct LegalSectionCard: View {
    let title: String
    let icon: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.md) {
            HStack(spacing: ModernDesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(ModernDesignSystem.Colors.primary)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(ModernDesignSystem.Typography.title3)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(content)
                .font(ModernDesignSystem.Typography.body)
                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                .lineSpacing(4)
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

#Preview("Terms of Service") {
    NavigationView {
        TermsOfServiceView()
    }
}

#Preview("Privacy Policy") {
    NavigationView {
        PrivacyPolicyView()
    }
}

