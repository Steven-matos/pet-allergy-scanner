import type { Config } from 'tailwindcss'

/**
 * Tailwind CSS configuration for SniffTest landing page
 * Maintains exact color scheme from original HTML design
 */
const config: Config = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: '#2D5016',
        'warm-coral': '#E67E22',
        'golden-yellow': '#F39C12',
        'soft-cream': '#F8F6F0',
        'text-primary': '#2C3E50',
        'text-secondary': '#BDC3C7',
        'border-primary': '#95A5A6',
        'safe': '#27AE60',
        'warning': '#F39C12',
        'error': '#E74C3C'
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
    },
  },
  plugins: [],
}

export default config

