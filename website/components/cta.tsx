'use client'

import { useWaitlist } from '@/contexts/waitlist-context'

/**
 * Call-to-Action section component
 * Final conversion section before footer
 */
export default function CTA() {
  const { openModal } = useWaitlist()
  return (
    <section id="waitlist" className="py-24 px-4 sm:px-6 lg:px-8 scroll-mt-20">
      <div className="max-w-4xl mx-auto text-center">
        <h2 className="text-4xl font-semibold tracking-tight text-text-primary mb-4">
          Be the first to protect your pets
        </h2>
        <p className="text-xl text-text-primary/70 mb-8">
          Join our waitlist and get early access to SniffTest
        </p>
        <div className="flex flex-col sm:flex-row gap-4 justify-center">
          <button 
            onClick={openModal}
            className="inline-flex items-center justify-center px-8 py-4 bg-primary hover:bg-primary/90 text-white font-medium rounded-lg transition-colors"
          >
            <span className="mr-2">📧</span>
            Join Waitlist
          </button>
        </div>
      </div>
    </section>
  )
}

