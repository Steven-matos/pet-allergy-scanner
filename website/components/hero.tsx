'use client'

import Image from 'next/image'
import { Download, PlayCircle, CheckCircle, ShieldCheck, Cpu } from 'lucide-react'
import { useWaitlist } from '@/contexts/waitlist-context'

/**
 * Hero section component
 * Features: Main value proposition, CTA buttons, social proof, and hero image
 */
export default function Hero() {
  const { openModal } = useWaitlist()
  return (
    <section className="pt-32 pb-20 px-4 sm:px-6 lg:px-8" aria-label="Hero section">
      <div className="max-w-7xl mx-auto">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          <div>
            <div className="inline-flex items-center space-x-2 px-3 py-1 bg-primary/10 text-primary rounded-full text-sm font-medium mb-6" role="note" aria-label="Feature highlight">
              <Cpu className="w-4 h-4" aria-hidden="true" />
              <span>On-Device Processing</span>
            </div>
            <h1 className="text-5xl sm:text-6xl font-semibold tracking-tight text-text-primary mb-6 leading-tight" itemProp="name">
              Know what's in your pet's food
            </h1>
            <p className="text-xl text-text-primary/70 mb-8 leading-relaxed" itemProp="description">
              Scan pet food ingredients, identify allergens, and track health events to keep your dogs and/or cats healthy.
            </p>
            <div className="flex flex-col sm:flex-row gap-4">
              <button 
                onClick={openModal}
                className="inline-flex items-center justify-center px-6 py-3 bg-primary hover:bg-primary/90 text-white font-medium rounded-lg transition-colors"
                aria-label="Join the waitlist for early access"
              >
                <span className="mr-2" aria-hidden="true">📧</span>
                Join Waitlist
              </button>
            </div>
            <div className="mt-8 flex items-center space-x-6 text-sm text-text-primary/70" role="list" aria-label="Key benefits">
              <div className="flex items-center space-x-2" role="listitem">
                <CheckCircle className="w-5 h-5 text-safe" aria-hidden="true" />
                <span>Early access</span>
              </div>
              <div className="flex items-center space-x-2" role="listitem">
                <ShieldCheck className="w-5 h-5 text-safe" aria-hidden="true" />
                <span>Vet approved</span>
              </div>
            </div>
          </div>
          <div className="relative">
            <div className="relative w-full aspect-square max-w-lg mx-auto">
              <Image
                src="/irl-dog-cat.png"
                alt="Happy dog and cat together representing pet health and wellness"
                width={800}
                height={800}
                className="rounded-3xl shadow-2xl object-cover w-full h-full"
                priority
                itemProp="image"
              />
              <div className="absolute -bottom-6 -left-6 bg-soft-cream p-6 rounded-2xl shadow-xl border border-border-primary max-w-xs">
                <div className="flex items-center space-x-3 mb-3">
                  <div className="w-10 h-10 bg-warm-coral/10 rounded-full flex items-center justify-center">
                    <span className="text-warm-coral text-xl">⚠️</span>
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-text-primary">Allergen Detected</p>
                    <p className="text-xs text-text-primary/70">Contains wheat gluten</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

