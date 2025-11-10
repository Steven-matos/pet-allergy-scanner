import type { Metadata } from 'next'
import Navigation from '@/components/navigation'
import Footer from '@/components/footer'
import BackToTop from '@/components/back-to-top'
import StructuredData from '@/components/structured-data'
import { getAbsoluteUrl } from '@/lib/metadata'

/**
 * Privacy Policy page metadata
 * Enhanced SEO for legal documentation
 */
export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: 'SniffTest Privacy Policy - Learn how we collect, use, and protect your personal information and your pet\'s data in our pet health tracking application.',
  keywords: [
    'snifftest privacy policy',
    'pet health app privacy',
    'pet data protection',
    'pet health tracking privacy',
  ],
  openGraph: {
    title: 'Privacy Policy - SniffTest',
    description: 'Learn how SniffTest protects your privacy and your pet\'s data.',
    url: '/privacy',
    type: 'article',
    images: [
      {
        url: getAbsoluteUrl('/main-logo-transparent.png'),
        width: 1024,
        height: 1024,
        alt: 'SniffTest Privacy Policy',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Privacy Policy - SniffTest',
    description: 'Learn how SniffTest protects your privacy and your pet\'s data.',
    images: [getAbsoluteUrl('/main-logo-transparent.png')],
  },
  alternates: {
    canonical: '/privacy',
  },
}

/**
 * Creates URL-friendly anchor ID from section title
 */
function createAnchorId(title: string): string {
  return title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

/**
 * Privacy Policy page
 * Displays the complete privacy policy content matching the app version
 * Follows legal document best practices: table of contents, clear typography, anchor links
 */
export default function PrivacyPage() {
  const sections = [
    {
      title: 'Introduction',
      icon: '🛡️',
      content: 'At SniffTest, we are committed to protecting your privacy and the privacy of your pets. This Privacy Policy explains how we collect, use, and safeguard your personal information when you use our app.',
    },
    {
      title: 'Information We Collect',
      icon: '📄',
      content: 'We collect the following categories of information:',
      points: [
        'Account information (name, email address, password)',
        'Pet information (name, species, breed, weight, age, known sensitivities, health conditions)',
        'Scan data (food label images, OCR-extracted text, ingredient analysis results, nutritional calculations)',
        'Usage data (app interactions, feature usage, preferences, scan history, search queries)',
        'Device information (device type, operating system, app version, device identifiers, IP address)',
        'Image metadata (timestamp, geolocation if enabled, image properties)',
      ],
      additionalContent: 'We collect this information to provide our services, improve accuracy, and enhance user experience. Image processing and OCR analysis may occur on your device or through secure third-party services.',
    },
    {
      title: 'How We Use Information',
      icon: '⚙️',
      content: 'We use your information to:',
      points: [
        'Provide and improve our services',
        'Analyze pet food ingredients and provide nutritional information',
        'Personalize your experience',
        'Communicate with you about updates and features',
        'Ensure security and prevent fraud',
        'Comply with legal obligations',
      ],
      additionalContent: 'We do not sell your personal information to third parties.',
    },
    {
      title: 'Data Sharing and Disclosure',
      icon: '👥',
      content: 'We may share your information with:',
      points: [
        'Service providers (cloud hosting, analytics, customer support, email delivery)',
        'Third-party OCR and image processing services to analyze food labels',
        'Third-party ingredient and nutritional databases for analysis',
        'Legal authorities when required by law, court order, or to protect rights and safety',
        'Business partners with your explicit consent, subject to strict data protection agreements',
        'Successors in the event of a merger, acquisition, or sale of assets (with notice to users)',
      ],
      additionalContent: 'We require all third parties to maintain the confidentiality and security of your information through contractual agreements. We do not sell your personal information to third parties for marketing purposes.',
    },
    {
      title: 'Data Security',
      icon: '🔒',
      content: 'We implement industry-standard security measures to protect your data, including encryption in transit and at rest, secure authentication, regular security audits, and access controls. However, no system is 100% secure, and we cannot guarantee absolute security. You are responsible for maintaining the security of your account credentials.',
    },
    {
      title: 'Data Retention',
      icon: '⏰',
      content: 'We retain your data for as long as your account is active or as needed to provide services. After account deletion:',
      points: [
        'Personal information (account details, pet profiles) is deleted within 30 days',
        'Scan images and analysis results are permanently deleted from our servers',
        'Anonymized usage data may be retained for analytics and service improvement',
        'We may retain certain information longer if required by law or for legal proceedings',
        'Backup copies may persist for up to 90 days before permanent deletion',
      ],
      additionalContent: 'Third-party services may have their own retention policies for data processed on their platforms. Contact us at privacy@snifftestapp.com for specific information about data deletion.',
    },
    {
      title: 'Image and Biometric Data',
      icon: '📷',
      content: 'When you scan food labels, we process images that may contain text and visual information. Important information about image data:',
      points: [
        'Images are processed to extract ingredient text using OCR technology',
        'Images may be temporarily stored on our servers during processing',
        'We do not use images for facial recognition or biometric identification',
        'Images may be shared with third-party OCR services as necessary for processing',
        'You can delete individual scans or all scan history at any time through the app',
        'Deleted images are permanently removed from our servers within 30 days',
      ],
      additionalContent: 'By using the scanning feature, you consent to the processing and temporary storage of food label images for analysis purposes.',
    },
    {
      title: 'Data Breach Notification',
      icon: '🚨',
      content: 'In the event of a data breach that may affect your personal information, we will:',
      points: [
        'Notify affected users within 72 hours of discovering the breach (where required by law)',
        'Provide clear information about what data was affected',
        'Explain the steps we are taking to address the breach',
        'Offer guidance on steps you can take to protect your information',
        'Report breaches to relevant authorities as required by applicable laws (GDPR, CCPA, etc.)',
      ],
      additionalContent: 'Notifications will be sent via email to the address associated with your account, or through the app if email is unavailable.',
    },
    {
      title: 'Your Rights',
      icon: '✋',
      content: 'You have the right to:',
      points: [
        'Access your personal data',
        'Correct inaccurate information',
        'Delete your account and data',
        'Export your data',
        'Opt-out of marketing communications',
        'Withdraw consent for data processing',
      ],
      additionalContent: 'To exercise these rights, contact us at privacy@snifftestapp.com or use the in-app settings.',
    },
    {
      title: "Children's Privacy",
      icon: '👨‍👩‍👧',
      content: "Our app is not intended for children under 13. We do not knowingly collect personal information from children. If we discover that we have collected information from a child under 13, we will delete it immediately. Parents or guardians who believe their child has provided information should contact us at privacy@snifftestapp.com.",
    },
    {
      title: 'Cookies and Tracking',
      icon: '📡',
      content: 'We use analytics tools and tracking technologies to understand how you use our app, improve functionality, and provide personalized experiences. You can manage your preferences in the app settings. We use third-party analytics services that may collect data about your usage patterns.',
    },
    {
      title: 'Third-Party Links',
      icon: '🔗',
      content: 'Our app may contain links to third-party websites or services. We are not responsible for the privacy practices of these third parties. We encourage you to review their privacy policies before providing any personal information. This Privacy Policy applies only to our app and services.',
    },
    {
      title: 'International Data Transfers',
      icon: '🌎',
      content: 'Your information may be transferred to and processed in countries other than your country of residence. We ensure appropriate safeguards are in place for international transfers, including standard contractual clauses and adequacy decisions. By using our app, you consent to these transfers.',
    },
    {
      title: 'GDPR Compliance',
      icon: '🌍',
      content: 'For users in the European Union, we comply with the General Data Protection Regulation (GDPR). We process your personal data based on legitimate interests, contract performance, and consent where required. You have enhanced rights under GDPR, including the right to data portability and the right to be forgotten. Our Data Protection Officer can be contacted at dpo@snifftestapp.com.',
    },
    {
      title: 'CCPA Compliance',
      icon: '🏢',
      content: 'For California residents, we comply with the California Consumer Privacy Act (CCPA). You have the right to know what personal information we collect, the right to delete personal information, the right to opt-out of the sale of personal information (we do not sell personal information), and the right to non-discrimination. To exercise these rights, contact us at privacy@snifftestapp.com.',
    },
    {
      title: 'Changes to Privacy Policy',
      icon: '🔄',
      content: 'We may update this Privacy Policy from time to time. We will notify you of significant changes through the app or email. Your continued use of the app after changes constitutes acceptance of the updated policy.',
    },
    {
      title: 'Contact Information',
      icon: '✉️',
      content: 'For privacy-related questions or to exercise your rights, contact us at privacy@snifftestapp.com or through our support channels within the app. We will respond to your request within 30 days as required by applicable law.',
    },
  ]

  return (
    <main>
      <StructuredData type="privacy" />
      <Navigation />
      <div className="min-h-screen bg-white pt-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 lg:py-12">
          {/* Header Section */}
          <div className="border-b-2 border-border-primary pb-6 mb-8">
            <div className="flex items-center gap-4 mb-4">
              <span className="text-4xl" aria-hidden="true">🛡️</span>
              <div>
                <h1 className="text-4xl font-bold text-text-primary mb-2">Privacy Policy</h1>
                <p className="text-base text-text-secondary">Last updated: October, 2025</p>
              </div>
            </div>
            <p className="text-lg text-text-primary leading-relaxed max-w-3xl">
              This Privacy Policy explains how SniffTest collects, uses, and protects your personal information
              and your pet's data when you use our application.
            </p>
          </div>

          {/* Table of Contents */}
          <div className="bg-soft-cream border border-border-primary rounded-lg p-4 mb-8 shadow-sm print:hidden">
            <h2 className="text-lg font-semibold text-text-primary mb-3">Table of Contents</h2>
            <nav aria-label="Privacy Policy Table of Contents">
              <ul className="grid grid-cols-1 sm:grid-cols-2 gap-1.5 text-xs max-h-64 overflow-y-auto pr-2">
                {sections.map((section) => {
                  const anchorId = createAnchorId(section.title)
                  return (
                    <li key={anchorId}>
                      <a
                        href={`#${anchorId}`}
                        className="text-text-primary/80 hover:text-primary transition-colors underline-offset-2 hover:underline block py-1"
                      >
                        {section.title}
                      </a>
                    </li>
                  )
                })}
              </ul>
            </nav>
          </div>

          {/* Legal Content Sections */}
          <article className="prose prose-lg max-w-none">
            <div className="space-y-8">
              {sections.map((section) => {
                const anchorId = createAnchorId(section.title)
                return (
                  <section
                    key={anchorId}
                    id={anchorId}
                    className="scroll-mt-8 border-b border-border-primary/50 pb-8 last:border-b-0"
                  >
                    <div className="flex items-start gap-4 mb-4">
                      <span className="text-3xl flex-shrink-0" aria-hidden="true">
                        {section.icon}
                      </span>
                      <h2 className="text-2xl font-bold text-text-primary mt-1 leading-tight">
                        {section.title}
                      </h2>
                    </div>
                    <div className="ml-14">
                      <p className="text-base text-text-primary leading-relaxed mb-4">
                        {section.content}
                      </p>
                      {section.points && (
                        <ul className="list-disc list-inside space-y-2 text-base text-text-primary leading-relaxed mb-4 ml-4">
                          {section.points.map((point, index) => (
                            <li key={index} className="ml-2">{point}</li>
                          ))}
                        </ul>
                      )}
                      {section.additionalContent && (
                        <p className="text-base text-text-primary leading-relaxed">
                          {section.additionalContent}
                        </p>
                      )}
                    </div>
                  </section>
                )
              })}
            </div>
          </article>

          {/* Back to Top Link */}
          <BackToTop />
        </div>
      </div>
      <Footer />
    </main>
  )
}
