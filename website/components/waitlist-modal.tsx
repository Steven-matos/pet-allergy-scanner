'use client'

import { useState, useEffect } from 'react'
import { X, CheckCircle, Loader2, Mail } from 'lucide-react'

/**
 * Waitlist modal component
 * Handles email signup for waitlist with API integration
 */
interface WaitlistModalProps {
  isOpen: boolean
  onClose: () => void
}

/**
 * API configuration
 * Uses production API endpoint for waitlist signups
 */
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://snifftest-api-production.up.railway.app/api/v1'

/**
 * Validates email format using RFC 5322 compliant regex
 * More strict than HTML5 email validation
 */
function isValidEmail(email: string): boolean {
  if (!email || email.trim().length === 0) {
    return false
  }

  // RFC 5322 compliant email regex (simplified but comprehensive)
  const emailRegex = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
  
  return emailRegex.test(email.trim())
}

export default function WaitlistModal({ isOpen, onClose }: WaitlistModalProps) {
  const [email, setEmail] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [isSuccess, setIsSuccess] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [emailError, setEmailError] = useState<string | null>(null)

  /**
   * Reset form state when modal closes
   */
  useEffect(() => {
    if (!isOpen) {
      setEmail('')
      setIsSubmitting(false)
      setIsSuccess(false)
      setError(null)
      setEmailError(null)
    }
  }, [isOpen])

  /**
   * Validate email on change with debouncing
   */
  useEffect(() => {
    if (!email) {
      setEmailError(null)
      return
    }

    // Debounce validation
    const timeoutId = setTimeout(() => {
      if (!isValidEmail(email)) {
        setEmailError('Please enter a valid email address')
      } else {
        setEmailError(null)
      }
    }, 300)

    return () => clearTimeout(timeoutId)
  }, [email])

  /**
   * Handle form submission
   */
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError(null)
    
    // Validate email before submission
    if (!email || email.trim().length === 0) {
      setEmailError('Email is required')
      return
    }

    if (!isValidEmail(email)) {
      setEmailError('Please enter a valid email address')
      return
    }

    setIsSubmitting(true)

    try {
      const response = await fetch(`${API_BASE_URL}/waitlist/`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email }),
      })

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({ detail: 'Failed to join waitlist' }))
        throw new Error(errorData.detail || 'Failed to join waitlist')
      }

      setIsSuccess(true)
      setTimeout(() => {
        onClose()
      }, 2000)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred. Please try again.')
      setIsSubmitting(false)
    }
  }

  /**
   * Handle escape key to close modal
   */
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onClose()
      }
    }

    if (isOpen) {
      document.addEventListener('keydown', handleEscape)
      document.body.style.overflow = 'hidden'
    }

    return () => {
      document.removeEventListener('keydown', handleEscape)
      document.body.style.overflow = 'unset'
    }
  }, [isOpen, onClose])

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
      <div className="bg-white rounded-2xl shadow-2xl max-w-md w-full p-6 sm:p-8 relative animate-in fade-in zoom-in duration-200">
        <button
          onClick={onClose}
          className="absolute top-4 right-4 text-text-primary/70 hover:text-text-primary transition-colors"
          aria-label="Close modal"
        >
          <X className="w-5 h-5" />
        </button>

        {isSuccess ? (
          <div className="text-center py-8">
            <div className="w-16 h-16 bg-safe/10 rounded-full flex items-center justify-center mx-auto mb-4">
              <CheckCircle className="w-8 h-8 text-safe" />
            </div>
            <h2 className="text-2xl font-semibold text-text-primary mb-2">
              You're on the list!
            </h2>
            <p className="text-text-primary/70">
              We'll notify you when SniffTest is ready.
            </p>
          </div>
        ) : (
          <>
            <div className="text-center mb-6">
              <div className="w-16 h-16 bg-primary/10 rounded-full flex items-center justify-center mx-auto mb-4">
                <Mail className="w-8 h-8 text-primary" />
              </div>
              <h2 className="text-2xl font-semibold text-text-primary mb-2">
                Join the Waitlist
              </h2>
              <p className="text-text-primary/70">
                Be the first to know when SniffTest launches
              </p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4" noValidate>
              <div>
                <label htmlFor="email" className="block text-sm font-medium text-text-primary mb-2">
                  Email address
                </label>
                <input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  required
                  disabled={isSubmitting}
                  className={`w-full px-4 py-3 border rounded-lg focus:outline-none focus:ring-2 focus:border-transparent disabled:opacity-50 disabled:cursor-not-allowed ${
                    emailError
                      ? 'border-error focus:ring-error'
                      : 'border-border-primary focus:ring-primary'
                  }`}
                  aria-invalid={emailError ? 'true' : 'false'}
                  aria-describedby={emailError ? 'email-error' : undefined}
                />
                {emailError && (
                  <p
                    id="email-error"
                    className="mt-1 text-sm text-error"
                    role="alert"
                  >
                    {emailError}
                  </p>
                )}
              </div>

              {error && (
                <div className="p-3 bg-error/10 border border-error/30 rounded-lg text-sm text-error">
                  {error}
                </div>
              )}

              <button
                type="submit"
                disabled={isSubmitting || !email || !!emailError}
                className="w-full py-3 bg-primary hover:bg-primary/90 text-white font-medium rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="w-5 h-5 mr-2 animate-spin" />
                    Joining...
                  </>
                ) : (
                  'Join Waitlist'
                )}
              </button>
            </form>
          </>
        )}
      </div>
    </div>
  )
}

