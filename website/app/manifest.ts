import { MetadataRoute } from 'next'

/**
 * Web App Manifest for PWA capabilities
 * Enables add-to-home-screen functionality and improves SEO
 */
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'SniffTest - Pet Food Ingredient Scanner & Health Tracker',
    short_name: 'SniffTest',
    description: 'Scan pet food labels to track ingredients, allergens, and nutrition. The ultimate pet health tracking app for dogs and cats.',
    start_url: '/',
    display: 'standalone',
    background_color: '#F8F6F0',
    theme_color: '#2D5016',
    orientation: 'portrait-primary',
    categories: ['health', 'lifestyle', 'pets'],
    icons: [
      {
        src: '/favicon-16x16.png',
        sizes: '16x16',
        type: 'image/png',
      },
      {
        src: '/favicon-32x32.png',
        sizes: '32x32',
        type: 'image/png',
      },
      {
        src: '/apple-touch-icon.png',
        sizes: '180x180',
        type: 'image/png',
        purpose: 'maskable',
      },
      {
        src: '/main-logo-transparent.png',
        sizes: '512x512',
        type: 'image/png',
        purpose: 'any',
      },
    ],
  }
}
