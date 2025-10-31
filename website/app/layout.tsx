import type { Metadata, Viewport } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'
import { WaitlistProvider } from '@/contexts/waitlist-context'
import WaitlistModalWrapper from '@/components/waitlist-modal-wrapper'

const inter = Inter({ subsets: ['latin'] })

/**
 * Root layout component for Next.js App Router
 * Sets up metadata, fonts, and global styles
 */
export const metadata: Metadata = {
  title: 'SniffTest - Pet Food Ingredient Analysis',
  description: 'Instantly scan and analyze pet food ingredients using advanced on-device processing. Identify allergens and safety concerns to keep your dogs and cats healthy with science-backed insights.',
  keywords: ['pet food', 'ingredient scanner', 'allergen detection', 'pet health', 'dog food', 'cat food'],
  authors: [{ name: 'SniffTest' }],
  openGraph: {
    title: 'SniffTest - Pet Food Ingredient Analysis',
    description: 'Instantly scan and analyze pet food ingredients using advanced on-device processing.',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'SniffTest - Pet Food Ingredient Analysis',
    description: 'Instantly scan and analyze pet food ingredients using advanced on-device processing.',
  },
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
        <WaitlistProvider>
          {children}
          <WaitlistModalWrapper />
        </WaitlistProvider>
      </body>
    </html>
  )
}

