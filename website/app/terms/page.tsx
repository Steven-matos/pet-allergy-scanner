import type { Metadata } from 'next'
import Navigation from '@/components/navigation'
import Footer from '@/components/footer'
import BackToTop from '@/components/back-to-top'
import StructuredData from '@/components/structured-data'
import { getAbsoluteUrl } from '@/app/utils/metadata'

/**
 * Terms of Service page metadata
 * Enhanced SEO for legal documentation
 */
export const metadata: Metadata = {
  title: 'Terms of Service',
  description: 'SniffTest Terms of Service - Read our terms and conditions for using the SniffTest pet health tracking app and services.',
  keywords: [
    'snifftest terms of service',
    'pet health app terms',
    'pet tracking app terms',
    'mobile app terms and conditions',
  ],
  openGraph: {
    title: 'Terms of Service - SniffTest',
    description: 'Terms and conditions for using the SniffTest pet health tracking application.',
    url: '/terms',
    type: 'article',
    images: [
      {
        url: getAbsoluteUrl('/main-logo-transparent.png'),
        width: 1024,
        height: 1024,
        alt: 'SniffTest Terms of Service',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Terms of Service - SniffTest',
    description: 'Terms and conditions for using the SniffTest pet health tracking application.',
    images: [getAbsoluteUrl('/main-logo-transparent.png')],
  },
  alternates: {
    canonical: '/terms',
  },
}

/**
 * Creates URL-friendly anchor ID from section title
 */
function createAnchorId(title: string): string {
  return title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

/**
 * Terms of Service page
 * Displays the complete terms of service content matching the app version
 * Follows legal document best practices: table of contents, clear typography, anchor links
 */
export default function TermsPage() {
  const sections = [
    {
      title: 'Introduction',
      icon: '✋',
      content: 'Welcome to SniffTest, your trusted companion for pet nutrition and allergy scanning. By using our app, you agree to be bound by these Terms of Service. Please read them carefully.',
    },
    {
      title: 'Acceptance of Terms',
      icon: '✅',
      content: 'By downloading, installing, or using the SniffTest app, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and our Privacy Policy. If you do not agree to these terms, please do not use our app.',
    },
    {
      title: 'Service Description',
      icon: '🐾',
      content: 'SniffTest provides informational pet nutrition analysis and ingredient scanning services for educational purposes only. Our app uses OCR technology to analyze pet food ingredients and provide general information. This service is NOT a substitute for professional veterinary advice, diagnosis, or treatment. Always consult your veterinarian for medical decisions regarding your pet\'s health.',
    },
    {
      title: 'User Responsibilities',
      icon: '👤',
      content: 'You are responsible for:',
      points: [
        'Providing accurate pet information',
        'Using the app in accordance with applicable laws',
        'Not sharing false or misleading information',
        'Respecting intellectual property rights',
        'Maintaining the security of your account and device',
        'Ensuring your device meets the minimum requirements for app functionality',
        'Obtaining proper authorization before scanning food labels that you do not own',
      ],
    },
    {
      title: 'Prohibited Uses',
      icon: '⚠️',
      content: 'You may not:',
      points: [
        'Use the app for illegal purposes',
        'Attempt to reverse engineer or hack the app',
        'Share false information about pet health',
        'Use the app to harm animals',
        'Violate any applicable laws or regulations',
      ],
    },
    {
      title: 'Intellectual Property',
      icon: '©️',
      content: 'All content, features, and functionality of SniffTest are owned by us and are protected by copyright, trademark, and other intellectual property laws. You may not copy, modify, or distribute our content without permission.',
    },
    {
      title: 'User-Generated Content',
      icon: '📸',
      content: 'When you scan food labels and upload images to the app, you retain ownership of your content. However, by using the app, you grant us a non-exclusive, worldwide, royalty-free license to use, process, store, and analyze your scans solely for the purpose of providing our services. You represent and warrant that:',
      points: [
        'You own or have the right to upload and process the content you submit',
        'Your content does not violate any third-party rights, including copyrights, trademarks, or privacy rights',
        'Your content does not contain illegal, harmful, or offensive material',
        'You will not upload content that contains malware, viruses, or other harmful code',
      ],
      additionalContent: 'We reserve the right to remove any content that violates these terms or is deemed inappropriate.',
    },
    {
      title: 'OCR and Image Processing',
      icon: '🔍',
      content: 'SniffTest uses optical character recognition (OCR) and image processing technology to analyze food labels. You acknowledge that:',
      points: [
        'OCR technology may not always be 100% accurate due to image quality, lighting conditions, or label formatting',
        'Analysis results are based on recognized text and may contain errors or omissions',
        'We are not responsible for incorrect analysis due to poor image quality or unreadable labels',
        'You should verify critical information independently, especially for pets with severe allergies',
      ],
    },
    {
      title: 'Third-Party Services',
      icon: '🔗',
      content: 'SniffTest may integrate with third-party services, APIs, and databases for functionality such as OCR processing, ingredient analysis, and nutritional data. You acknowledge that:',
      points: [
        'These third-party services have their own terms of service and privacy policies',
        'We are not responsible for the availability, accuracy, or practices of third-party services',
        'Your use of third-party services is subject to their respective terms',
        'We may share necessary data with third-party services to provide app functionality',
      ],
      additionalContent: 'For information about how third-party services handle your data, please review their respective privacy policies.',
    },
    {
      title: 'Indemnification',
      icon: '🛡️',
      content: 'You agree to indemnify, defend, and hold harmless SniffTest, its officers, directors, employees, agents, and affiliates from and against any claims, liabilities, damages, losses, costs, or expenses (including reasonable attorney\'s fees) arising out of or relating to:',
      points: [
        'Your use or misuse of the app',
        'Your violation of these Terms of Service',
        'Your violation of any third-party rights, including intellectual property or privacy rights',
        'Any content you submit, upload, or transmit through the app',
        'Your violation of any applicable laws or regulations',
      ],
    },
    {
      title: 'Electronic Communications',
      icon: '📧',
      content: 'By using the app, you consent to receive electronic communications from us, including notices, updates, and promotional materials. You agree that all agreements, notices, disclosures, and other communications that we provide to you electronically satisfy any legal requirement that such communications be in writing. You may opt-out of promotional communications at any time through the app settings or by contacting us.',
    },
    {
      title: 'Disclaimers',
      icon: 'ℹ️',
      content: 'SniffTest is provided "as is" without warranties of any kind, express or implied. We do not guarantee the accuracy, completeness, or reliability of any nutritional information, allergy assessments, or recommendations. The app is for informational and educational purposes only and should never replace professional veterinary advice, diagnosis, or treatment.',
      points: [
        'This app does NOT replace veterinary consultation',
        'Always consult with a licensed veterinarian before making any changes to your pet\'s diet',
        'Seek immediate veterinary care if your pet shows signs of illness or allergic reactions',
        'Never use this app as a substitute for professional veterinary assessment or medical advice',
        'All nutritional information and recommendations are general in nature and may not apply to your specific pet',
      ],
    },
    {
      title: 'Limitation of Liability',
      icon: '🛡️',
      content: 'To the maximum extent permitted by applicable law, our total liability to you for any claims arising from or related to the app shall not exceed the amount you paid for the app in the 12 months preceding the claim. We shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to pet health issues, financial losses, or data loss. Some jurisdictions do not allow limitation of liability, so these limitations may not apply to you.',
    },
    {
      title: 'Termination',
      icon: '🛑',
      content: 'We may terminate or suspend your access to the app at any time, with or without notice, for any reason, including violation of these terms. You may stop using the app at any time.',
    },
    {
      title: 'Changes to Terms',
      icon: '🔄',
      content: 'We reserve the right to modify these terms at any time. We will notify users of significant changes through the app or email. Continued use of the app after changes constitutes acceptance of the new terms.',
    },
    {
      title: 'Governing Law and Dispute Resolution',
      icon: '⚖️',
      content: 'These terms are governed by the laws of [Your Jurisdiction]. Any disputes arising from these terms or your use of the app shall be resolved through binding arbitration administered by [Arbitration Organization]. You waive your right to participate in class action lawsuits or class-wide arbitration. You may opt out of this arbitration clause within 30 days of first using the app by contacting us at legal@snifftestapp.com.',
    },
    {
      title: 'Force Majeure',
      icon: '⚠️',
      content: 'We shall not be liable for any failure or delay in performance due to circumstances beyond our reasonable control, including but not limited to acts of God, natural disasters, war, terrorism, government actions, internet outages, or other force majeure events.',
    },
    {
      title: 'Severability',
      icon: '📄',
      content: 'If any provision of these terms is found to be unenforceable or invalid, the remaining provisions shall remain in full force and effect. We will replace any invalid provision with a valid provision that most closely reflects the original intent.',
    },
    {
      title: 'Contact Information',
      icon: '✉️',
      content: 'If you have questions about these Terms of Service, please contact us at legal@snifftestapp.com or through our support channels within the app.',
    },
  ]

  return (
    <main>
      <StructuredData type="terms" />
      <Navigation />
      <div className="min-h-screen bg-white pt-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 lg:py-12">
          {/* Header Section */}
          <div className="border-b-2 border-border-primary pb-6 mb-8">
            <div className="flex items-center gap-4 mb-4">
              <span className="text-4xl" aria-hidden="true">📄</span>
              <div>
                <h1 className="text-4xl font-bold text-text-primary mb-2">Terms of Service</h1>
                <p className="text-base text-text-secondary">Last updated: October, 2025</p>
              </div>
            </div>
            <p className="text-lg text-text-primary leading-relaxed max-w-3xl">
              These Terms of Service govern your use of the SniffTest application. Please read them carefully
              before using our service.
            </p>
          </div>

          {/* Table of Contents */}
          <div className="bg-soft-cream border border-border-primary rounded-lg p-4 mb-8 shadow-sm print:hidden">
            <h2 className="text-lg font-semibold text-text-primary mb-3">Table of Contents</h2>
            <nav aria-label="Terms of Service Table of Contents">
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
                        <ul className="list-disc list-inside space-y-2 text-base text-text-primary leading-relaxed ml-4">
                          {section.points.map((point, index) => (
                            <li key={index} className="ml-2">{point}</li>
                          ))}
                        </ul>
                      )}
                      {section.additionalContent && (
                        <p className="text-base text-text-primary leading-relaxed mt-4">
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
