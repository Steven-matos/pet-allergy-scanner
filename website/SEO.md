# SEO Optimization Guide for SniffTest

This document outlines the SEO optimizations implemented for the SniffTest pet health tracking application website.

## Overview

The website has been optimized for search engines with a focus on **Pet Health Tracking** applications, pet food scanners, and allergen detection tools.

## Implemented SEO Features

### 1. Metadata & Meta Tags

#### Root Layout (`app/layout.tsx`)
- Enhanced title with template support
- Comprehensive description optimized for pet health tracking keywords
- Extensive keyword list targeting:
  - Pet health tracking
  - Pet food scanner
  - Pet allergy tracker
  - Pet nutrition tracker
  - Dog/cat health monitoring
- Full Open Graph tags for social sharing
- Twitter Card optimization
- Canonical URLs
- Robots meta tags with GoogleBot-specific directives

#### Page-Specific Metadata
- Homepage: Optimized for "Pet Food Scanner & Health Tracker App"
- Privacy Policy: Legal document SEO
- Terms of Service: Legal document SEO

### 2. Structured Data (JSON-LD)

#### Implemented Schemas:
- **SoftwareApplication**: Mobile app details, features, ratings
- **Organization**: Company information, contact points
- **MobileApplication**: Platform-specific app schema
- **WebSite**: Site search functionality schema
- **WebPage**: Page-level structured data for legal pages
- **Article**: Article schema for legal documents

#### Location:
- `components/structured-data.tsx` - Reusable component for JSON-LD injection

### 3. Sitemap (`app/sitemap.ts`)

Automatically generated sitemap including:
- Homepage (priority: 1.0, weekly updates)
- Privacy Policy (priority: 0.5, monthly updates)
- Terms of Service (priority: 0.5, monthly updates)

### 4. Robots.txt (`app/robots.ts`)

Configured to:
- Allow all search engines to crawl the site
- Disallow API routes and Next.js internal routes
- Reference sitemap location
- Include GoogleBot-specific rules

### 5. Semantic HTML

- Main content wrapped in `<main>` tags
- Schema.org microdata attributes where appropriate
- Proper heading hierarchy (h1, h2, etc.)
- Semantic section elements

### 6. Performance & Technical SEO

- **Next.js 16**: Latest framework with optimized performance
- **React 19**: Latest React with improved rendering
- **Image Optimization**: Next.js Image component usage
- **Font Optimization**: Inter font with Google Fonts optimization

## Environment Variables Required

Add these to your `.env.local` file:

```bash
# Site Configuration (required for structured data and sitemap)
NEXT_PUBLIC_SITE_URL=https://snifftest.app

# API Configuration
NEXT_PUBLIC_API_URL=https://snifftest-api-production.up.railway.app/api/v1
```

## Key SEO Keywords Targeted

### Primary Keywords:
- Pet health tracking app
- Pet food scanner app
- Pet allergy tracker
- Dog food ingredient analyzer
- Cat nutrition tracker

### Long-Tail Keywords:
- Pet health monitoring application
- Pet food label scanner
- Pet ingredient analysis tool
- Pet wellness tracker
- Mobile pet health app

## SEO Best Practices Implemented

✅ **On-Page SEO**
- Optimized title tags (50-60 characters)
- Meta descriptions (150-160 characters)
- Keyword-rich content structure
- Proper heading hierarchy
- Internal linking structure

✅ **Technical SEO**
- Canonical URLs
- Robots.txt
- XML Sitemap
- Structured data (JSON-LD)
- Mobile-responsive design
- Fast page load times

✅ **Social Media SEO**
- Open Graph tags
- Twitter Card tags
- Optimized images for sharing

✅ **Content SEO**
- Semantic HTML markup
- Schema.org structured data
- Keyword-optimized descriptions
- Content hierarchy

## Monitoring & Testing

### Tools to Use:
1. **Google Search Console**: Monitor indexing and search performance
2. **Google Rich Results Test**: Test structured data implementation
3. **PageSpeed Insights**: Monitor page performance
4. **Schema.org Validator**: Validate JSON-LD structured data

### Testing URLs:
- Sitemap: `https://snifftest.app/sitemap.xml`
- Robots: `https://snifftest.app/robots.txt`
- Structured Data Test: Use Google's Rich Results Test tool

## Future SEO Enhancements

Consider adding:
1. **FAQ Schema**: If adding FAQ section
2. **Breadcrumb Schema**: For deeper site navigation
3. **LocalBusiness Schema**: If applicable
4. **Review Schema**: When reviews are available
5. **Blog/Article Schema**: If adding blog content
6. **Video Schema**: If adding video content

## Maintenance

### Regular Updates:
- Update sitemap lastModified dates when content changes
- Refresh meta descriptions quarterly
- Monitor keyword rankings
- Update structured data as app features evolve
- Keep Next.js and dependencies updated

### Content Updates:
- Add fresh content regularly
- Update keywords based on search trends
- Expand structured data as new features launch
- Monitor and respond to search console notifications

## References

- [Next.js Metadata API](https://nextjs.org/docs/app/building-your-application/optimizing/metadata)
- [Schema.org Documentation](https://schema.org/)
- [Google Search Central](https://developers.google.com/search)
- [Open Graph Protocol](https://ogp.me/)

