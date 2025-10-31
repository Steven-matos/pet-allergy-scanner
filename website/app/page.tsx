import Navigation from '@/components/navigation'
import Hero from '@/components/hero'
import Stats from '@/components/stats'
import Features from '@/components/features'
import HowItWorks from '@/components/how-it-works'
import CTA from '@/components/cta'
import Footer from '@/components/footer'
import ScrollHandler from '@/components/scroll-handler'

/**
 * Main landing page for SniffTest
 * Combines all section components to create the complete landing page
 * Follows DRY principle by importing modular components
 */
export default function Home() {
  return (
    <main>
      <ScrollHandler />
      <Navigation />
      <Hero />
      {/* <Stats /> */}
      <Features />
      <HowItWorks />
      <CTA />
      <Footer />
    </main>
  )
}

