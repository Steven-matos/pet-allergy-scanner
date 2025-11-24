import type { Metadata } from 'next'
import { getAbsoluteUrl } from '@/lib/metadata'

/**
 * Support page metadata
 * Enhanced SEO for help and support documentation
 */
export const metadata: Metadata = {
  title: 'Help & Support',
  description: 'Get help with SniffTest. Find answers to frequently asked questions about scanning pet food labels, managing pets, allergies, subscriptions, health tracking, and more.',
  keywords: [
    'snifftest help',
    'snifftest support',
    'pet food scanner help',
    'pet health app support',
    'pet allergy scanner faq',
    'pet food scanner questions',
  ],
  openGraph: {
    title: 'Help & Support - SniffTest',
    description: 'Get help with SniffTest. Find answers to frequently asked questions and contact our support team.',
    url: '/support',
    type: 'website',
    images: [
      {
        url: getAbsoluteUrl('/main-logo-transparent.png'),
        width: 1024,
        height: 1024,
        alt: 'SniffTest Help & Support',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Help & Support - SniffTest',
    description: 'Get help with SniffTest. Find answers to frequently asked questions and contact our support team.',
    images: [getAbsoluteUrl('/main-logo-transparent.png')],
  },
  alternates: {
    canonical: '/support',
  },
}

export default function SupportLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return children
}

