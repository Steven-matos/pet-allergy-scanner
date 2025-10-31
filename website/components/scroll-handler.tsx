'use client'

import { useEffect } from 'react'
import { usePathname } from 'next/navigation'

/**
 * Handles smooth scrolling to anchor sections when navigating with hash links
 * Works when navigating from other pages to home page sections
 */
export default function ScrollHandler() {
  const pathname = usePathname()

  useEffect(() => {
    // Only handle scrolling on the home page
    if (pathname !== '/') return

    const handleScroll = () => {
      const hash = window.location.hash
      if (hash) {
        // Small delay to ensure page is fully rendered
        setTimeout(() => {
          const element = document.querySelector(hash)
          if (element) {
            element.scrollIntoView({ behavior: 'smooth', block: 'start' })
          }
        }, 150)
      }
    }

    // Handle scroll after a short delay to ensure page is rendered
    const timeoutId = setTimeout(handleScroll, 100)

    // Also handle hash changes
    window.addEventListener('hashchange', handleScroll)

    return () => {
      clearTimeout(timeoutId)
      window.removeEventListener('hashchange', handleScroll)
    }
  }, [pathname])

  return null
}

