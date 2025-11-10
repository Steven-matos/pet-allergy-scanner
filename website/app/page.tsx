import type { Metadata } from 'next'
import Navigation from '@/components/navigation'
import Hero from '@/components/hero'
import Stats from '@/components/stats'
import Features from '@/components/features'
import HowItWorks from '@/components/how-it-works'
import CTA from '@/components/cta'
import Footer from '@/components/footer'
import ScrollHandler from '@/components/scroll-handler'
import { getAbsoluteUrl } from '@/app/utils/metadata'

/**
 * SEO metadata for homepage
 * Optimized for Pet Health Tracking applications
 */
export const metadata: Metadata = {
  title: 'Pet Food Scanner & Health Tracker App - SniffTest',
  description: 'Track your pet\'s health with SniffTest. Scan pet food labels to analyze ingredients, detect allergens, and monitor nutrition. The ultimate pet health tracking app for dogs and cats with AI-powered ingredient analysis.',
  keywords: [
    'pet health tracking app',
    'pet food scanner app',
    'pet allergy tracker',
    'dog food ingredient analyzer',
    'cat nutrition tracker',
    'pet health monitoring',
    'pet food label scanner',
    'pet ingredient analysis',
    'pet wellness tracker',
    'mobile pet health app',
  ],
  openGraph: {
    title: 'Pet Food Scanner & Health Tracker App - SniffTest',
    description: 'Track your pet\'s health with SniffTest. Scan pet food labels to analyze ingredients, detect allergens, and monitor nutrition.',
    url: '/',
    siteName: 'SniffTest',
    images: [
      {
        url: getAbsoluteUrl('/main-logo-transparent.png'),
        width: 1024,
        height: 1024,
        alt: 'SniffTest - Pet Health Tracking App',
      },
    ],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Pet Food Scanner & Health Tracker App - SniffTest',
    description: 'Track your pet\'s health with SniffTest. Scan pet food labels to analyze ingredients, detect allergens, and monitor nutrition.',
    images: [getAbsoluteUrl('/main-logo-transparent.png')],
    creator: '@snifftest',
    site: '@snifftest',
  },
  alternates: {
    canonical: '/',
  },
}

/**
 * Main landing page for SniffTest
 * Combines all section components to create the complete landing page
 * Follows DRY principle by importing modular components
 * Optimized for SEO with semantic HTML structure
 */
export default function Home() {
  return (
    <>
      <main itemScope itemType="https://schema.org/SoftwareApplication">
        <ScrollHandler />
        <Navigation />
        <Hero />
        {/* <Stats /> */}
        <Features />
        <HowItWorks />
        <CTA />
        <Footer />
      </main>
    </>
  )
}

