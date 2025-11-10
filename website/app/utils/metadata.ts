/**
 * Utility functions for metadata generation
 * Provides reusable functions for SEO and social media metadata
 * Follows DRY principle by centralizing URL generation logic
 */

/**
 * Get absolute URL for social sharing images and links
 * Ensures Twitter/X and other platforms can properly fetch resources
 * @param path - Relative path to the resource
 * @returns Absolute URL with domain
 */
export function getAbsoluteUrl(path: string): string {
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://snifftest.app'
  // Ensure path starts with /
  const normalizedPath = path.startsWith('/') ? path : `/${path}`
  return `${baseUrl}${normalizedPath}`
}

/**
 * Get base URL for the site
 * Used for canonical URLs and other absolute references
 * @returns Base URL string
 */
export function getBaseUrl(): string {
  return process.env.NEXT_PUBLIC_SITE_URL || 'https://snifftest.app'
}
