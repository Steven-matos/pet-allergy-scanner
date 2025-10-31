'use client'

import { useWaitlist } from '@/contexts/waitlist-context'
import WaitlistModal from './waitlist-modal'

/**
 * Wrapper component to connect WaitlistModal with context
 * This is a client component that can use hooks
 */
export default function WaitlistModalWrapper() {
  const { isOpen, closeModal } = useWaitlist()
  return <WaitlistModal isOpen={isOpen} onClose={closeModal} />
}

