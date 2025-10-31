'use client'

import { createContext, useContext, useState, ReactNode } from 'react'

/**
 * Waitlist context for managing modal state globally
 * Allows any component to open/close the waitlist modal
 */
interface WaitlistContextType {
  isOpen: boolean
  openModal: () => void
  closeModal: () => void
}

const WaitlistContext = createContext<WaitlistContextType | undefined>(undefined)

/**
 * Waitlist provider component
 * Wraps the app to provide waitlist modal state management
 */
export function WaitlistProvider({ children }: { children: ReactNode }) {
  const [isOpen, setIsOpen] = useState(false)

  const openModal = () => setIsOpen(true)
  const closeModal = () => setIsOpen(false)

  return (
    <WaitlistContext.Provider value={{ isOpen, openModal, closeModal }}>
      {children}
    </WaitlistContext.Provider>
  )
}

/**
 * Hook to use waitlist context
 */
export function useWaitlist() {
  const context = useContext(WaitlistContext)
  if (context === undefined) {
    throw new Error('useWaitlist must be used within a WaitlistProvider')
  }
  return context
}

