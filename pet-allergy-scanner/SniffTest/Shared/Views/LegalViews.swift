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
                    content: "You are responsible for:",
                    points: [
                        "Providing accurate pet information",
                        "Using the app in accordance with applicable laws",
                        "Not sharing false or misleading information",
                        "Respecting intellectual property rights",
                        "Maintaining the security of your account and device",
                        "Ensuring your device meets the minimum requirements for app functionality",
                        "Obtaining proper authorization before scanning food labels that you do not own"
                    ]
                )
                
                // Prohibited Uses
                LegalSectionCard(
                    title: "Prohibited Uses",
                    icon: "exclamationmark.triangle.fill",
                    content: "You may not:",
                    points: [
                        "Use the app for illegal purposes",
                        "Attempt to reverse engineer or hack the app",
                        "Share false information about pet health",
                        "Use the app to harm animals",
                        "Violate any applicable laws or regulations"
                    ]
                )
                
                // Intellectual Property
                LegalSectionCard(
                    title: "Intellectual Property",
                    icon: "copyright.fill",
                    content: "All content, features, and functionality of SniffTest are owned by us and are protected by copyright, trademark, and other intellectual property laws. You may not copy, modify, or distribute our content without permission."
                )
                
                // User-Generated Content
                LegalSectionCard(
                    title: "User-Generated Content",
                    icon: "camera.fill",
                    content: "When you scan food labels and upload images to the app, you retain ownership of your content. However, by using the app, you grant us a non-exclusive, worldwide, royalty-free license to use, process, store, and analyze your scans solely for the purpose of providing our services. You represent and warrant that:",
                    points: [
                        "You own or have the right to upload and process the content you submit",
                        "Your content does not violate any third-party rights, including copyrights, trademarks, or privacy rights",
                        "Your content does not contain illegal, harmful, or offensive material",
                        "You will not upload content that contains malware, viruses, or other harmful code"
                    ],
                    additionalContent: "We reserve the right to remove any content that violates these terms or is deemed inappropriate."
                )
                
                // OCR and Image Processing
                LegalSectionCard(
                    title: "OCR and Image Processing",
                    icon: "magnifyingglass.circle.fill",
                    content: "SniffTest uses optical character recognition (OCR) and image processing technology to analyze food labels. You acknowledge that:",
                    points: [
                        "OCR technology may not always be 100% accurate due to image quality, lighting conditions, or label formatting",
                        "Analysis results are based on recognized text and may contain errors or omissions",
                        "We are not responsible for incorrect analysis due to poor image quality or unreadable labels",
                        "You should verify critical information independently, especially for pets with severe allergies"
                    ]
                )
                
                // Third-Party Services
                LegalSectionCard(
                    title: "Third-Party Services",
                    icon: "link.circle.fill",
                    content: "SniffTest may integrate with third-party services, APIs, and databases for functionality such as OCR processing, ingredient analysis, and nutritional data. You acknowledge that:",
                    points: [
                        "These third-party services have their own terms of service and privacy policies",
                        "We are not responsible for the availability, accuracy, or practices of third-party services",
                        "Your use of third-party services is subject to their respective terms",
                        "We may share necessary data with third-party services to provide app functionality"
                    ],
                    additionalContent: "For information about how third-party services handle your data, please review their respective privacy policies."
                )
                
                // Indemnification
                LegalSectionCard(
                    title: "Indemnification",
                    icon: "shield.fill",
                    content: "You agree to indemnify, defend, and hold harmless SniffTest, its officers, directors, employees, agents, and affiliates from and against any claims, liabilities, damages, losses, costs, or expenses (including reasonable attorney's fees) arising out of or relating to:",
                    points: [
                        "Your use or misuse of the app",
                        "Your violation of these Terms of Service",
                        "Your violation of any third-party rights, including intellectual property or privacy rights",
                        "Any content you submit, upload, or transmit through the app",
                        "Your violation of any applicable laws or regulations"
                    ]
                )
                
                // Electronic Communications
                LegalSectionCard(
                    title: "Electronic Communications",
                    icon: "envelope.fill",
                    content: "By using the app, you consent to receive electronic communications from us, including notices, updates, and promotional materials. You agree that all agreements, notices, disclosures, and other communications that we provide to you electronically satisfy any legal requirement that such communications be in writing. You may opt-out of promotional communications at any time through the app settings or by contacting us."
                )
                
                // Disclaimers
                LegalSectionCard(
                    title: "Disclaimers",
                    icon: "info.circle.fill",
                    content: "SniffTest is provided \"as is\" without warranties of any kind, express or implied. We do not guarantee the accuracy, completeness, or reliability of any nutritional information, allergy assessments, or recommendations. The app is for informational and educational purposes only and should never replace professional veterinary advice, diagnosis, or treatment.",
                    points: [
                        "This app does NOT replace veterinary consultation",
                        "Always consult with a licensed veterinarian before making any changes to your pet's diet",
                        "Seek immediate veterinary care if your pet shows signs of illness or allergic reactions",
                        "Never use this app as a substitute for professional veterinary assessment or medical advice",
                        "All nutritional information and recommendations are general in nature and may not apply to your specific pet"
                    ]
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
                    content: "These terms are governed by the laws of [Your Jurisdiction]. Any disputes arising from these terms or your use of the app shall be resolved through binding arbitration administered by [Arbitration Organization]. You waive your right to participate in class action lawsuits or class-wide arbitration. You may opt out of this arbitration clause within 30 days of first using the app by contacting us at legal@snifftestapp.com."
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
                    content: "If you have questions about these Terms of Service, please contact us at legal@snifftestapp.com or through our support channels within the app."
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
                    content: "We collect the following categories of information:",
                    points: [
                        "Account information (name, email address, password)",
                        "Pet information (name, species, breed, weight, age, known sensitivities, health conditions)",
                        "Scan data (food label images, OCR-extracted text, ingredient analysis results, nutritional calculations)",
                        "Usage data (app interactions, feature usage, preferences, scan history, search queries)",
                        "Device information (device type, operating system, app version, device identifiers, IP address)",
                        "Image metadata (timestamp, geolocation if enabled, image properties)"
                    ],
                    additionalContent: "We collect this information to provide our services, improve accuracy, and enhance user experience. Image processing and OCR analysis may occur on your device or through secure third-party services."
                )
                
                // How We Use Information
                LegalSectionCard(
                    title: "How We Use Information",
                    icon: "gear.circle.fill",
                    content: "We use your information to:",
                    points: [
                        "Provide and improve our services",
                        "Analyze pet food ingredients and provide nutritional information",
                        "Personalize your experience",
                        "Communicate with you about updates and features",
                        "Ensure security and prevent fraud",
                        "Comply with legal obligations"
                    ],
                    additionalContent: "We do not sell your personal information to third parties."
                )
                
                // Data Sharing and Disclosure
                LegalSectionCard(
                    title: "Data Sharing and Disclosure",
                    icon: "person.2.fill",
                    content: "We may share your information with:",
                    points: [
                        "Service providers (cloud hosting, analytics, customer support, email delivery)",
                        "Third-party OCR and image processing services to analyze food labels",
                        "Third-party ingredient and nutritional databases for analysis",
                        "Legal authorities when required by law, court order, or to protect rights and safety",
                        "Business partners with your explicit consent, subject to strict data protection agreements",
                        "Successors in the event of a merger, acquisition, or sale of assets (with notice to users)"
                    ],
                    additionalContent: "We require all third parties to maintain the confidentiality and security of your information through contractual agreements. We do not sell your personal information to third parties for marketing purposes."
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
                    content: "We retain your data for as long as your account is active or as needed to provide services. After account deletion:",
                    points: [
                        "Personal information (account details, pet profiles) is deleted within 30 days",
                        "Scan images and analysis results are permanently deleted from our servers",
                        "Anonymized usage data may be retained for analytics and service improvement",
                        "We may retain certain information longer if required by law or for legal proceedings",
                        "Backup copies may persist for up to 90 days before permanent deletion"
                    ],
                    additionalContent: "Third-party services may have their own retention policies for data processed on their platforms. Contact us at privacy@snifftestapp.com for specific information about data deletion."
                )
                
                // Image and Biometric Data
                LegalSectionCard(
                    title: "Image and Biometric Data",
                    icon: "camera.fill",
                    content: "When you scan food labels, we process images that may contain text and visual information. Important information about image data:",
                    points: [
                        "Images are processed to extract ingredient text using OCR technology",
                        "Images may be temporarily stored on our servers during processing",
                        "We do not use images for facial recognition or biometric identification",
                        "Images may be shared with third-party OCR services as necessary for processing",
                        "You can delete individual scans or all scan history at any time through the app",
                        "Deleted images are permanently removed from our servers within 30 days"
                    ],
                    additionalContent: "By using the scanning feature, you consent to the processing and temporary storage of food label images for analysis purposes."
                )
                
                // Data Breach Notification
                LegalSectionCard(
                    title: "Data Breach Notification",
                    icon: "exclamationmark.triangle.fill",
                    content: "In the event of a data breach that may affect your personal information, we will:",
                    points: [
                        "Notify affected users within 72 hours of discovering the breach (where required by law)",
                        "Provide clear information about what data was affected",
                        "Explain the steps we are taking to address the breach",
                        "Offer guidance on steps you can take to protect your information",
                        "Report breaches to relevant authorities as required by applicable laws (GDPR, CCPA, etc.)"
                    ],
                    additionalContent: "Notifications will be sent via email to the address associated with your account, or through the app if email is unavailable."
                )
                
                // Your Rights
                LegalSectionCard(
                    title: "Your Rights",
                    icon: "hand.raised.fill",
                    content: "You have the right to:",
                    points: [
                        "Access your personal data",
                        "Correct inaccurate information",
                        "Delete your account and data",
                        "Export your data",
                        "Opt-out of marketing communications",
                        "Withdraw consent for data processing"
                    ],
                    additionalContent: "To exercise these rights, contact us at privacy@snifftestapp.com or use the in-app settings."
                )
                
                // Children's Privacy
                LegalSectionCard(
                    title: "Children's Privacy",
                    icon: "figure.and.child.holdinghands",
                    content: "Our app is not intended for children under 13. We do not knowingly collect personal information from children. If we discover that we have collected information from a child under 13, we will delete it immediately. Parents or guardians who believe their child has provided information should contact us at privacy@snifftestapp.com."
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
                    content: "For users in the European Union, we comply with the General Data Protection Regulation (GDPR). We process your personal data based on legitimate interests, contract performance, and consent where required. You have enhanced rights under GDPR, including the right to data portability and the right to be forgotten. Our Data Protection Officer can be contacted at dpo@snifftestapp.com."
                )
                
                // CCPA Compliance
                LegalSectionCard(
                    title: "CCPA Compliance",
                    icon: "building.2.fill",
                    content: "For California residents, we comply with the California Consumer Privacy Act (CCPA). You have the right to know what personal information we collect, the right to delete personal information, the right to opt-out of the sale of personal information (we do not sell personal information), and the right to non-discrimination. To exercise these rights, contact us at privacy@snifftestapp.com."
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
                    content: "For privacy-related questions or to exercise your rights, contact us at privacy@snifftestapp.com or through our support channels within the app. We will respond to your request within 30 days as required by applicable law."
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
/// Supports optional bullet points and additional content
struct LegalSectionCard: View {
    let title: String
    let icon: String
    let content: String
    let points: [String]?
    let additionalContent: String?
    
    /// Initializer for simple content without bullet points
    init(title: String, icon: String, content: String) {
        self.title = title
        self.icon = icon
        self.content = content
        self.points = nil
        self.additionalContent = nil
    }
    
    /// Initializer for content with optional bullet points and additional content
    init(title: String, icon: String, content: String, points: [String]?, additionalContent: String? = nil) {
        self.title = title
        self.icon = icon
        self.content = content
        self.points = points
        self.additionalContent = additionalContent
    }
    
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
            
            if let points = points {
                VStack(alignment: .leading, spacing: ModernDesignSystem.Spacing.xs) {
                    ForEach(points, id: \.self) { point in
                        HStack(alignment: .top, spacing: ModernDesignSystem.Spacing.sm) {
                            Text("•")
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                            Text(point)
                                .font(ModernDesignSystem.Typography.body)
                                .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(.top, ModernDesignSystem.Spacing.xs)
            }
            
            if let additionalContent = additionalContent {
                Text(additionalContent)
                    .font(ModernDesignSystem.Typography.body)
                    .foregroundColor(ModernDesignSystem.Colors.textPrimary)
                    .lineSpacing(4)
                    .padding(.top, points != nil ? ModernDesignSystem.Spacing.sm : 0)
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

