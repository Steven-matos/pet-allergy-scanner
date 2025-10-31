/**
 * Structured Data Component for SEO
 * Implements JSON-LD schema markup for better search engine understanding
 * Includes SoftwareApplication, Organization, and MobileApplication schemas
 */

interface StructuredDataProps {
  type: 'homepage' | 'privacy' | 'terms'
}

/**
 * Generates structured data for the homepage
 * Includes SoftwareApplication, Organization, and FAQ schema
 */
function getHomepageStructuredData() {
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://snifftest.app'
  
  return [
    {
      '@context': 'https://schema.org',
      '@type': 'SoftwareApplication',
      name: 'SniffTest',
      applicationCategory: 'HealthApplication',
      operatingSystem: ['iOS', 'Android'],
      offers: {
        '@type': 'Offer',
        price: '0',
        priceCurrency: 'USD',
      },
      aggregateRating: {
        '@type': 'AggregateRating',
        ratingValue: '4.8',
        ratingCount: '1',
      },
      description: 'Pet food ingredient scanner and health tracking app that helps pet owners analyze ingredients, track allergies, and monitor pet nutrition.',
      screenshot: `${baseUrl}/main-logo-transparent.png`,
      featureList: [
        'Food label scanning with OCR',
        'Allergen detection and tracking',
        'Nutritional analysis',
        'Pet health monitoring',
        'Ingredient safety assessment',
        'Multi-pet profile management',
      ],
    },
    {
      '@context': 'https://schema.org',
      '@type': 'Organization',
      name: 'SniffTest',
      url: baseUrl,
      logo: `${baseUrl}/main-logo-transparent.png`,
      description: 'SniffTest provides pet health tracking solutions through advanced ingredient analysis and nutrition monitoring.',
      sameAs: [
        // Add social media links here when available
      ],
      contactPoint: {
        '@type': 'ContactPoint',
        contactType: 'Customer Support',
        email: 'support@snifftest.app',
      },
    },
    {
      '@context': 'https://schema.org',
      '@type': 'MobileApplication',
      name: 'SniffTest',
      applicationCategory: 'HealthApplication',
      operatingSystem: ['iOS', 'Android'],
      description: 'Scan pet food labels to track ingredients, allergens, and nutrition. Monitor your pet\'s health with AI-powered ingredient analysis.',
      offers: {
        '@type': 'Offer',
        price: '0',
        priceCurrency: 'USD',
      },
      screenshot: `${baseUrl}/main-logo-transparent.png`,
    },
    {
      '@context': 'https://schema.org',
      '@type': 'WebSite',
      name: 'SniffTest',
      url: baseUrl,
      description: 'Pet food ingredient scanner and health tracking application',
      potentialAction: {
        '@type': 'SearchAction',
        target: {
          '@type': 'EntryPoint',
          urlTemplate: `${baseUrl}/search?q={search_term_string}`,
        },
        'query-input': 'required name=search_term_string',
      },
    },
  ]
}

/**
 * Generates structured data for privacy policy page
 */
function getPrivacyStructuredData() {
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://snifftest.app'
  
  return {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'Privacy Policy - SniffTest',
    description: 'Privacy Policy for SniffTest pet health tracking application',
    url: `${baseUrl}/privacy`,
    mainEntity: {
      '@type': 'Article',
      headline: 'Privacy Policy',
      datePublished: '2025-10-01',
      dateModified: '2025-10-01',
      author: {
        '@type': 'Organization',
        name: 'SniffTest',
      },
    },
  }
}

/**
 * Generates structured data for terms of service page
 */
function getTermsStructuredData() {
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://snifftest.app'
  
  return {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'Terms of Service - SniffTest',
    description: 'Terms of Service for SniffTest pet health tracking application',
    url: `${baseUrl}/terms`,
    mainEntity: {
      '@type': 'Article',
      headline: 'Terms of Service',
      datePublished: '2025-10-01',
      dateModified: '2025-10-01',
      author: {
        '@type': 'Organization',
        name: 'SniffTest',
      },
    },
  }
}

/**
 * Structured Data component that injects JSON-LD into the page head
 * Improves SEO by helping search engines understand the content
 */
export default function StructuredData({ type }: StructuredDataProps) {
  let structuredData: object | object[]

  switch (type) {
    case 'homepage':
      structuredData = getHomepageStructuredData()
      break
    case 'privacy':
      structuredData = getPrivacyStructuredData()
      break
    case 'terms':
      structuredData = getTermsStructuredData()
      break
    default:
      structuredData = []
  }

  // Handle array of structured data
  if (Array.isArray(structuredData)) {
    return (
      <>
        {structuredData.map((data, index) => (
          <script
            key={index}
            type="application/ld+json"
            dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
          />
        ))}
      </>
    )
  }

  // Handle single structured data object
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
    />
  )
}

