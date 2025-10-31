'use client'

import { Menu, X } from 'lucide-react'
import { useState, useEffect, Suspense } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { usePathname, useSearchParams } from 'next/navigation'
import { useWaitlist } from '@/contexts/waitlist-context'

/**
 * Inner navigation component that uses searchParams
 * Wrapped in Suspense to support static generation
 */
function NavigationContent() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const isHomePage = pathname === '/'
  const { openModal } = useWaitlist()

  /**
   * Creates the proper link href based on current page
   * If on home page, use anchor link; otherwise link to home with anchor
   */
  const getNavLink = (anchor: string) => {
    return isHomePage ? anchor : `/${anchor}`
  }

  /**
   * Handles smooth scrolling to section after navigation
   */
  useEffect(() => {
    if (isHomePage && typeof window !== 'undefined') {
      const hash = window.location.hash
      if (hash) {
        // Small delay to ensure page is fully loaded
        setTimeout(() => {
          const element = document.querySelector(hash)
          if (element) {
            element.scrollIntoView({ behavior: 'smooth', block: 'start' })
          }
        }, 100)
      }
    }
  }, [isHomePage, searchParams])

  /**
   * Handles click for navigation links with smooth scroll
   */
  const handleNavClick = (e: React.MouseEvent<HTMLAnchorElement>, href: string) => {
    if (isHomePage && href.startsWith('#')) {
      e.preventDefault()
      const element = document.querySelector(href)
      if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }
      setMobileMenuOpen(false)
    }
  }

  return (
    <nav className="fixed top-0 w-full bg-white/80 backdrop-blur-md border-b border-border-primary z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <Link href="/" className="flex items-center space-x-2 hover:opacity-80 transition-opacity">
            <Image
              src="/main-logo-transparent.png"
              alt="SniffTest Logo"
              width={32}
              height={32}
              className="w-8 h-8 object-contain"
              priority
            />
            <span className="text-lg font-semibold tracking-tight text-text-primary">SniffTest</span>
          </Link>
          <div className="hidden md:flex items-center space-x-8">
            <Link
              href={getNavLink('#features')}
              onClick={(e) => handleNavClick(e, '#features')}
              className="text-sm font-medium text-text-primary/70 hover:text-text-primary transition-colors"
            >
              Features
            </Link>
            <Link
              href={getNavLink('#how-it-works')}
              onClick={(e) => handleNavClick(e, '#how-it-works')}
              className="text-sm font-medium text-text-primary/70 hover:text-text-primary transition-colors"
            >
              How It Works
            </Link>
            <button
              onClick={(e) => {
                e.preventDefault()
                openModal()
              }}
              className="px-4 py-2 text-sm font-medium text-white bg-primary hover:bg-primary/90 rounded-lg transition-colors"
            >
              Join Waitlist
            </button>
          </div>
          <button
            className="md:hidden"
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            aria-label="Toggle menu"
            aria-expanded={mobileMenuOpen}
          >
            {mobileMenuOpen ? (
              <X className="w-6 h-6 text-text-primary" />
            ) : (
              <Menu className="w-6 h-6 text-text-primary" />
            )}
          </button>
        </div>
        {/* Mobile Menu */}
        {mobileMenuOpen && (
          <div className="md:hidden border-t border-border-primary py-4">
            <div className="flex flex-col space-y-4">
              <Link
                href={getNavLink('#features')}
                onClick={(e) => {
                  handleNavClick(e, '#features')
                  setMobileMenuOpen(false)
                }}
                className="text-sm font-medium text-text-primary/70 hover:text-text-primary transition-colors"
              >
                Features
              </Link>
              <Link
                href={getNavLink('#how-it-works')}
                onClick={(e) => {
                  handleNavClick(e, '#how-it-works')
                  setMobileMenuOpen(false)
                }}
                className="text-sm font-medium text-text-primary/70 hover:text-text-primary transition-colors"
              >
                How It Works
              </Link>
              <button
                onClick={() => {
                  openModal()
                  setMobileMenuOpen(false)
                }}
                className="px-4 py-2 text-sm font-medium text-white bg-primary hover:bg-primary/90 rounded-lg transition-colors text-center"
              >
                Join Waitlist
              </button>
            </div>
          </div>
        )}
      </div>
    </nav>
  )
}

/**
 * Navigation component wrapper with Suspense boundary
 * Required for useSearchParams() in Next.js static generation
 */
export default function Navigation() {
  return (
    <Suspense fallback={
      <nav className="fixed top-0 w-full bg-white/80 backdrop-blur-md border-b border-border-primary z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <Link href="/" className="flex items-center space-x-2 hover:opacity-80 transition-opacity">
              <Image
                src="/main-logo-transparent.png"
                alt="SniffTest Logo"
                width={32}
                height={32}
                className="w-8 h-8 object-contain"
                priority
              />
              <span className="text-lg font-semibold tracking-tight text-text-primary">SniffTest</span>
            </Link>
          </div>
        </div>
      </nav>
    }>
      <NavigationContent />
    </Suspense>
  )
}
