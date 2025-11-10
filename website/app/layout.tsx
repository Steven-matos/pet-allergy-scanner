import type { Metadata, Viewport } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'
import { WaitlistProvider } from '@/contexts/waitlist-context'
import WaitlistModalWrapper from '@/components/waitlist-modal-wrapper'
import StructuredData from '@/components/structured-data'
import { getAbsoluteUrl, getBaseUrl } from '@/lib/metadata'

const inter = Inter({ subsets: ['latin'] })

/**
 * Root layout component for Next.js App Router
 * Sets up metadata, fonts, and global styles
 * Enhanced with comprehensive SEO for Pet Health Tracking applications
 */

export const metadata: Metadata = {
  metadataBase: new URL(getBaseUrl()),
  title: {
    default: 'SniffTest - Pet Food Ingredient Scanner & Health Tracker',
    template: '%s | SniffTest',
  },
  description: 'Scan pet food labels instantly to track ingredients, allergens, and nutrition. The ultimate pet health tracking app for dogs and cats. Monitor allergies, analyze nutrition, and keep your pets healthy with AI-powered ingredient analysis.',
  keywords: [
    'pet health tracking',
    'pet food scanner',
    'pet allergy tracker',
    'dog food ingredient analyzer',
    'cat food scanner',
    'pet nutrition tracker',
    'pet health app',
    'allergen detection for pets',
    'pet food safety',
    'pet ingredient scanner',
    'dog health tracking',
    'cat health monitoring',
    'pet nutrition analysis',
    'pet food label scanner',
    'pet wellness tracker',
  ],
  authors: [{ name: 'SniffTest', url: getBaseUrl() }],
  creator: 'SniffTest',
  publisher: 'SniffTest',
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  openGraph: {
    type: 'website',
    locale: 'en_US',
    url: '/',
    siteName: 'SniffTest',
    title: 'SniffTest - Pet Food Ingredient Scanner & Health Tracker',
    description: 'Scan pet food labels instantly to track ingredients, allergens, and nutrition. The ultimate pet health tracking app for dogs and cats.',
    images: [
      {
        url: getAbsoluteUrl('/main-logo-transparent.png'),
        width: 1024,
        height: 1024,
        alt: 'SniffTest - Pet Food Ingredient Scanner',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'SniffTest - Pet Food Ingredient Scanner & Health Tracker',
    description: 'Scan pet food labels instantly to track ingredients, allergens, and nutrition. Keep your pets healthy with AI-powered analysis.',
    images: [getAbsoluteUrl('/main-logo-transparent.png')],
    creator: '@snifftest',
    site: '@snifftest',
  },
  alternates: {
    canonical: '/',
  },
  category: 'Pet Health',
  classification: 'Mobile Application',
  // Add verification meta tags here when available
  // verification: {
  //   google: 'your-google-verification-code',
  //   yandex: 'your-yandex-verification-code',
  //   yahoo: 'your-yahoo-verification-code',
  // },
  icons: {
    icon: [
      { url: '/favicon.ico', sizes: 'any' },
      { url: '/favicon-16x16.png', sizes: '16x16', type: 'image/png' },
      { url: '/favicon-32x32.png', sizes: '32x32', type: 'image/png' },
    ],
    apple: [
      { url: '/apple-touch-icon.png', sizes: '180x180', type: 'image/png' },
    ],
  },
  manifest: '/manifest.json',
}

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className="scroll-smooth">
      <body className={`${inter.className} bg-white text-text-primary antialiased`}>
        <StructuredData type="homepage" />
        <WaitlistProvider>
          {children}
          <WaitlistModalWrapper />
        </WaitlistProvider>
      </body>
    </html>
  )
}

