'use client'

/**
 * Back to top button component
 * Scrolls smoothly to the top of the page when clicked
 */
export default function BackToTop() {
  return (
    <div className="mt-12 text-center print:hidden">
      <button
        onClick={() => {
          window.scrollTo({ top: 0, behavior: 'smooth' })
        }}
        className="text-sm text-text-secondary hover:text-primary transition-colors underline-offset-2 hover:underline cursor-pointer"
      >
        Back to top ↑
      </button>
    </div>
  )
}

